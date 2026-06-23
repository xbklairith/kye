import Foundation
import Combine
import CoreGraphics

/// App state published to UI
enum AppState: Equatable {
    case initializing
    case waitingForPermission
    case running
    case disabled
    case error(String)
}

/// Protocol for app control
protocol AppControlling: AnyObject {
    var state: AppState { get }
    var statePublisher: AnyPublisher<AppState, Never> { get }
    var isEnabled: Bool { get }

    func start() async throws
    func stop()
    func toggleEnabled()
    func reloadConfiguration() throws
}

/// Main application controller coordinating all services
final class AppController: AppControlling, ObservableObject {

    @Published private(set) var state: AppState = .initializing

    /// The current rules, published for the rules UI. Mirrors the active configuration.
    @Published private(set) var rules: [Rule] = []

    /// Validation messages keyed by rule id, published for inline display in the rules UI.
    @Published private(set) var validationErrors: [String: [String]] = [:]

    /// Non-nil when the on-disk config failed to parse on auto-reload; the last-good rules
    /// stay active and this drives a banner. Cleared on the next successful reload (REQ-B12).
    @Published private(set) var reloadError: String?

    var statePublisher: AnyPublisher<AppState, Never> {
        $state.eraseToAnyPublisher()
    }

    private(set) var isEnabled: Bool = false

    private let permissionManager: any PermissionManaging
    private let configManager: any ConfigurationManaging
    private let eventTapManager: any EventTapManaging
    private let ruleEngine: RuleEngine
    private let keyMapper: any KeyMapping
    private let logger: (any Logging)?

    init(
        permissionManager: any PermissionManaging,
        configManager: any ConfigurationManaging,
        eventTapManager: any EventTapManaging,
        ruleEngine: RuleEngine,
        keyMapper: any KeyMapping,
        logger: (any Logging)? = nil
    ) {
        self.permissionManager = permissionManager
        self.configManager = configManager
        self.eventTapManager = eventTapManager
        self.ruleEngine = ruleEngine
        self.keyMapper = keyMapper
        self.logger = logger

        setupCallbacks()
    }

    func start() async throws {
        logger?.info("Starting Kye app controller", category: .app)
        debugLog("START: Beginning app controller startup")

        // Step 1: Check permissions
        let permissionStatus = permissionManager.checkPermission()
        debugLog("Permission status: \(permissionStatus)")
        if permissionStatus != .granted {
            logger?.warning("Accessibility permission not granted", category: .permission)
            debugLog("Permission NOT granted, waiting...")
            state = .waitingForPermission
            permissionManager.startMonitoring()
            return
        }

        // Step 2: Load configuration
        do {
            let config = try configManager.load()

            // Validate configuration
            let errors = configManager.validate(config, keyMapper: keyMapper)
            if !errors.isEmpty {
                for error in errors {
                    logger?.warning("Config validation: [\(error.ruleId)] \(error.message)", category: .configuration)
                }
            }

            // Load all rules into the engine (invalid rules stay inert at evaluation time)
            loadRulesIntoEngine(config)
            republish()

        } catch {
            logger?.error("Failed to load configuration: \(error)", category: .configuration)
            state = .error("Failed to load configuration")
            throw error
        }

        // Step 3: Start event tap
        do {
            debugLog("Starting event tap...")
            try eventTapManager.start()
            isEnabled = true
            state = .running
            logger?.info("Kye is now active", category: .app)
            debugLog("Event tap started successfully! isEnabled=\(isEnabled)")
        } catch {
            logger?.error("Failed to start event tap: \(error)", category: .eventTap)
            state = .error("Failed to start keyboard interception")
            throw error
        }
    }

    func stop() {
        logger?.info("Stopping Kye app controller", category: .app)

        eventTapManager.stop()
        permissionManager.stopMonitoring()
        isEnabled = false
        state = .disabled
    }

    func toggleEnabled() {
        isEnabled.toggle()

        if isEnabled {
            eventTapManager.setEnabled(true)
            state = .running
            logger?.info("Key remapping enabled", category: .app)
        } else {
            eventTapManager.setEnabled(false)
            state = .disabled
            logger?.info("Key remapping disabled", category: .app)
        }
    }

    func reloadConfiguration() throws {
        logger?.info("Reloading configuration", category: .configuration)

        // Snapshot before reload overwrites configuration in place, so identical
        // content (e.g. our own atomic write) is a no-op — preventing reload loops.
        let before = configManager.configuration
        try configManager.reload()
        let config = configManager.configuration

        guard before != config else {
            logger?.info("Configuration unchanged on reload; skipping", category: .configuration)
            return
        }

        let errors = configManager.validate(config, keyMapper: keyMapper)
        if !errors.isEmpty {
            for error in errors {
                logger?.warning("Config validation: [\(error.ruleId)] \(error.message)", category: .configuration)
            }
        }

        loadRulesIntoEngine(config)
        republish()
        logger?.info("Configuration reloaded, \(config.rules.count) rules active", category: .configuration)
    }

    /// Watcher-facing reload: never throws. On a parse failure the last-good engine rules are
    /// kept untouched and `reloadError` is set for the banner; a successful reload clears it.
    func reloadFromDisk() {
        do {
            try reloadConfiguration()
            reloadError = nil
        } catch {
            let message = "Couldn't load \(configManager.configurationURL.lastPathComponent): \(error.localizedDescription)"
            logger?.error("Auto-reload failed; keeping last-good config: \(message)", category: .configuration)
            reloadError = message
        }
    }

    /// Toggles a rule's enabled flag, persists it, reloads the engine, and republishes derived state.
    /// If saving fails the error is rethrown and no in-memory state is mutated.
    func setRuleEnabled(id: String, enabled: Bool) throws {
        let current = configManager.configuration
        var updatedRules = current.rules
        guard let index = updatedRules.firstIndex(where: { $0.id == id }) else { return }

        updatedRules[index] = updatedRules[index].withEnabled(enabled)
        try applyRules(updatedRules)
    }

    /// Appends a rule, persists, reloads the engine, and republishes. Non-mutating on save failure.
    func addRule(_ rule: Rule) throws {
        try applyRules(configManager.configuration.rules + [rule])
    }

    /// Replaces the rule whose `id` matches, preserving order. No-op if the id is absent.
    func updateRule(_ rule: Rule) throws {
        var rules = configManager.configuration.rules
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        try applyRules(rules)
    }

    /// Removes the rule with the given `id`, persists, reloads the engine, and republishes.
    func deleteRule(id: String) throws {
        try applyRules(configManager.configuration.rules.filter { $0.id != id })
    }

    /// Suspends the event tap during key capture so the captured key reflects the physical
    /// key, not a remapped one. Tap-level only — never touches `state`/`isEnabled`, so the
    /// menu-bar status stays steady (REQ-B07).
    func suspendForCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        eventTapManager.setEnabled(false)
    }

    /// Restores the tap to its pre-capture state. Restores `isEnabled` (NOT unconditionally
    /// `true`), so a globally-disabled tap stays disabled. Idempotent (REQ-B08).
    func resumeAfterCapture() {
        guard isCapturing else { return }
        isCapturing = false
        eventTapManager.setEnabled(isEnabled)
    }

    // MARK: - Private

    /// True while a key-capture has suspended the tap; guards resume idempotency.
    private var isCapturing = false

    /// Builds a `Configuration` from a new rules array (preserving `version`/`enabled`) and applies it.
    private func applyRules(_ rules: [Rule]) throws {
        let current = configManager.configuration
        try saveAndApply(Configuration(version: current.version, enabled: current.enabled, rules: rules))
    }

    /// Persists a configuration, then reloads the engine and republishes derived state.
    /// Save runs first so a failure leaves the engine and published state untouched.
    private func saveAndApply(_ configuration: Configuration) throws {
        try configManager.save(configuration)
        loadRulesIntoEngine(configuration)
        republish()
    }

    /// Recomputes published `rules` and `validationErrors` from the active configuration.
    private func republish() {
        let config = configManager.configuration
        rules = config.rules

        var grouped: [String: [String]] = [:]
        for error in configManager.validate(config, keyMapper: keyMapper) {
            grouped[error.ruleId, default: []].append(error.message)
        }
        validationErrors = grouped
    }

    private func setupCallbacks() {
        // Permission status changes
        permissionManager.onStatusChanged = { [weak self] status in
            self?.handlePermissionChange(status)
        }

        // Event processing
        eventTapManager.onEventReceived = { [weak self] event, type in
            return self?.processEvent(event, type: type)
        }

        // Event tap disabled by system
        eventTapManager.onTapDisabled = { [weak self] in
            self?.handleTapDisabled()
        }
    }

    private func handlePermissionChange(_ status: PermissionStatus) {
        if status == .granted && state == .waitingForPermission {
            logger?.info("Permission granted, starting services", category: .permission)
            permissionManager.stopMonitoring()

            Task { @MainActor in
                try? await self.start()
            }
        }
    }

    private func loadRulesIntoEngine(_ config: Configuration) {
        ruleEngine.rules = config.rules
        logger?.info("Loaded \(config.rules.count) rules into engine", category: .configuration)
        debugLog("Loaded \(config.rules.count) rules into engine")
        for rule in config.rules {
            debugLog("Rule: \(rule)")
        }
    }

    private func debugLog(_ message: String) {
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("kye_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    private func processEvent(_ event: CGEvent, type: CGEventType) -> CGEvent? {
        guard isEnabled else {
            return event
        }

        // Only process key events
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else {
            return event
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Debug logging
        debugLog("Event: type=\(type.rawValue) keyCode=\(keyCode) flags=\(flags.rawValue)")

        // Handle modifier key state tracking
        if type == .flagsChanged {
            handleModifierChange(keyCode: keyCode, flags: flags)
            return event
        }

        // Evaluate rules
        let result = ruleEngine.evaluate(keyCode: keyCode, flags: flags)
        debugLog("Rule result: \(result)")

        switch result {
        case .passthrough:
            return event

        case .transformed(let newKeyCode, let newFlags):
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(newKeyCode))
            event.flags = newFlags
            return event

        case .suppressed:
            return nil
        }
    }

    private func handleModifierChange(keyCode: CGKeyCode, flags: CGEventFlags) {
        // Track trigger key held state
        let isKeyDown = isModifierKeyPressed(keyCode: keyCode, flags: flags)
        ruleEngine.setTriggerKeyHeld(isKeyDown, keyCode: keyCode)
        debugLog("Modifier change: keyCode=\(keyCode) isKeyDown=\(isKeyDown)")

        // Also check if this modifier is remapped by a basic rule
        // If Right Option is remapped to Right Command, also track Right Command as held
        for rule in ruleEngine.rules {
            if case .basic(let basicRule) = rule, basicRule.enabled {
                if let fromCode = keyMapper.keyCode(for: basicRule.from),
                   let toCode = keyMapper.keyCode(for: basicRule.to),
                   fromCode == keyCode {
                    // This modifier is remapped - also track the target modifier
                    ruleEngine.setTriggerKeyHeld(isKeyDown, keyCode: toCode)
                    if isKeyDown {
                        // Track which physical key is remapped to this target
                        ruleEngine.setRemappedTrigger(physicalKeyCode: fromCode, targetKeyCode: toCode)
                    }
                    debugLog("Modifier remap: also setting keyCode=\(toCode) isKeyDown=\(isKeyDown)")
                }
            }
        }
    }

    private func isModifierKeyPressed(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        // Determine if modifier is currently pressed based on key code and flags
        switch keyCode {
        case 0x36: // Right Command
            return flags.contains(.maskCommand)
        case 0x37: // Left Command
            return flags.contains(.maskCommand)
        case 0x3D: // Right Option
            return flags.contains(.maskAlternate)
        case 0x3A: // Left Option
            return flags.contains(.maskAlternate)
        case 0x3C: // Right Shift
            return flags.contains(.maskShift)
        case 0x38: // Left Shift
            return flags.contains(.maskShift)
        case 0x3E: // Right Control
            return flags.contains(.maskControl)
        case 0x3B: // Left Control
            return flags.contains(.maskControl)
        default:
            return false
        }
    }

    private func handleTapDisabled() {
        logger?.error("Event tap was disabled by system", category: .eventTap)
        isEnabled = false
        state = .error("Keyboard interception was disabled")
    }
}
