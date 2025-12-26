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

    var statePublisher: AnyPublisher<AppState, Never> {
        $state.eraseToAnyPublisher()
    }

    private(set) var isEnabled: Bool = false

    private let permissionManager: PermissionManaging
    private let configManager: ConfigurationManaging
    private let eventTapManager: EventTapManaging
    private var ruleEngine: RuleEngineProtocol
    private let keyMapper: KeyMapping
    private let logger: Logging?

    init(
        permissionManager: PermissionManaging,
        configManager: ConfigurationManaging,
        eventTapManager: EventTapManaging,
        ruleEngine: RuleEngineProtocol,
        keyMapper: KeyMapping,
        logger: Logging? = nil
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

        // Step 1: Check permissions
        let permissionStatus = permissionManager.checkPermission()
        if permissionStatus != .granted {
            logger?.warning("Accessibility permission not granted", category: .permission)
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

            // Load valid rules into engine
            loadRulesIntoEngine(config)

        } catch {
            logger?.error("Failed to load configuration: \(error)", category: .configuration)
            state = .error("Failed to load configuration")
            throw error
        }

        // Step 3: Start event tap
        do {
            try eventTapManager.start()
            isEnabled = true
            state = .running
            logger?.info("Kye is now active", category: .app)
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

        try configManager.reload()

        let config = configManager.configuration
        let errors = configManager.validate(config, keyMapper: keyMapper)
        if !errors.isEmpty {
            for error in errors {
                logger?.warning("Config validation: [\(error.ruleId)] \(error.message)", category: .configuration)
            }
        }

        loadRulesIntoEngine(config)
        logger?.info("Configuration reloaded, \(config.rules.count) rules active", category: .configuration)
    }

    // MARK: - Private

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

        // Handle modifier key state tracking
        if type == .flagsChanged {
            handleModifierChange(keyCode: keyCode, flags: flags)
            return event
        }

        // Evaluate rules
        let result = ruleEngine.evaluate(keyCode: keyCode, flags: flags)

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
        // For simplicity, detect if the key was pressed or released based on flags
        let isKeyDown = isModifierKeyPressed(keyCode: keyCode, flags: flags)
        ruleEngine.setTriggerKeyHeld(isKeyDown, keyCode: keyCode)
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
