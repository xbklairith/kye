import XCTest
import Combine
@testable import Kye

final class AppControllerTests: XCTestCase {

    var appController: AppController!
    var mockPermissionManager: MockPermissionManager!
    var mockEventTapManager: MockEventTapManager!
    var mockLogger: MockLogger!
    var configManager: ConfigurationManager!
    var ruleEngine: RuleEngine!
    var keyMapper: KeyMapper!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        cancellables = []

        // Create temp directory for config
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let configURL = tempDirectory.appendingPathComponent("config.json")

        mockPermissionManager = MockPermissionManager()
        mockEventTapManager = MockEventTapManager()
        mockLogger = MockLogger()
        keyMapper = KeyMapper()
        let modifierHandler = ModifierHandler()
        ruleEngine = RuleEngine(keyMapper: keyMapper, modifierHandler: modifierHandler)
        configManager = ConfigurationManager(
            configurationURL: configURL,
            keyMapper: keyMapper,
            logger: mockLogger
        )

        appController = AppController(
            permissionManager: mockPermissionManager,
            configManager: configManager,
            eventTapManager: mockEventTapManager,
            ruleEngine: ruleEngine,
            keyMapper: keyMapper,
            logger: mockLogger
        )
    }

    override func tearDown() {
        cancellables = nil
        appController = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Protocol Conformance

    func testConformsToAppControllingProtocol() {
        let controller: any AppControlling = appController
        XCTAssertNotNil(controller)
    }

    // MARK: - Initial State

    func testInitialStateIsInitializing() {
        XCTAssertEqual(appController.state, .initializing)
    }

    func testInitialIsEnabledIsFalse() {
        XCTAssertFalse(appController.isEnabled)
    }

    // MARK: - Start Tests

    func testStartChecksPermissionFirst() async throws {
        mockPermissionManager.mockStatus = .denied

        try? await appController.start()

        XCTAssertEqual(mockPermissionManager.checkPermissionCallCount, 1)
    }

    func testStartWithDeniedPermissionSetsWaitingState() async throws {
        mockPermissionManager.mockStatus = .denied

        try? await appController.start()

        XCTAssertEqual(appController.state, .waitingForPermission)
    }

    func testStartWithDeniedPermissionStartsMonitoring() async throws {
        mockPermissionManager.mockStatus = .denied

        try? await appController.start()

        XCTAssertEqual(mockPermissionManager.startMonitoringCallCount, 1)
    }

    func testStartWithGrantedPermissionLoadsConfig() async throws {
        mockPermissionManager.mockStatus = .granted

        try await appController.start()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "Loading configuration"))
    }

    func testStartWithGrantedPermissionStartsEventTap() async throws {
        mockPermissionManager.mockStatus = .granted

        try await appController.start()

        XCTAssertEqual(mockEventTapManager.startCallCount, 1)
    }

    func testStartWithGrantedPermissionSetsRunningState() async throws {
        mockPermissionManager.mockStatus = .granted

        try await appController.start()

        XCTAssertEqual(appController.state, .running)
    }

    func testStartWithGrantedPermissionSetsIsEnabledTrue() async throws {
        mockPermissionManager.mockStatus = .granted

        try await appController.start()

        XCTAssertTrue(appController.isEnabled)
    }

    func testStartWithEventTapFailureThrows() async {
        mockPermissionManager.mockStatus = .granted
        mockEventTapManager.shouldThrowOnStart = true

        do {
            try await appController.start()
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }

    func testStartWithEventTapFailureSetsErrorState() async {
        mockPermissionManager.mockStatus = .granted
        mockEventTapManager.shouldThrowOnStart = true

        try? await appController.start()

        if case .error = appController.state {
            // Expected
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Stop Tests

    func testStopStopsEventTap() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.stop()

        XCTAssertEqual(mockEventTapManager.stopCallCount, 1)
    }

    func testStopStopsPermissionMonitoring() {
        mockPermissionManager.mockStatus = .denied

        appController.stop()

        XCTAssertEqual(mockPermissionManager.stopMonitoringCallCount, 1)
    }

    func testStopSetsDisabledState() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.stop()

        XCTAssertEqual(appController.state, .disabled)
    }

    func testStopSetsIsEnabledFalse() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.stop()

        XCTAssertFalse(appController.isEnabled)
    }

    // MARK: - Toggle Tests

    func testToggleEnabledChangesState() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        XCTAssertTrue(appController.isEnabled)

        appController.toggleEnabled()

        XCTAssertFalse(appController.isEnabled)

        appController.toggleEnabled()

        XCTAssertTrue(appController.isEnabled)
    }

    func testToggleDisabledSetsEventTapEnabled() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.toggleEnabled() // Disable

        XCTAssertEqual(mockEventTapManager.setEnabledCallCount, 1)
        XCTAssertFalse(mockEventTapManager.isEnabled)
    }

    func testToggleToEnabledSetsStateToRunning() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.toggleEnabled() // Disable
        appController.toggleEnabled() // Enable

        XCTAssertEqual(appController.state, .running)
    }

    func testToggleToDisabledSetsStateToDisabled() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.toggleEnabled()

        XCTAssertEqual(appController.state, .disabled)
    }

    // MARK: - Reload Configuration Tests

    func testReloadConfigurationReloadsFromFile() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        // Modify config file
        let newConfig = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "new-rule",
                    description: nil,
                    enabled: true,
                    from: "a",
                    to: "b"
                ))
            ]
        )
        try configManager.save(newConfig)

        try appController.reloadConfiguration()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "Reloading"))
    }

    func testReloadConfigurationLogsValidationErrors() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        // Save config with invalid key
        let invalidConfig = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "bad-rule",
                    description: nil,
                    enabled: true,
                    from: "invalid_key",
                    to: "a"
                ))
            ]
        )
        // External writer changes the file so the in-memory config stays stale and
        // reloadConfiguration's content-diff sees a real change (not a self-write no-op).
        let external = ConfigurationManager(configurationURL: configManager.configurationURL, keyMapper: keyMapper)
        try external.save(invalidConfig)

        try appController.reloadConfiguration()

        XCTAssertTrue(mockLogger.hasEntry(level: .warning, containing: "validation"))
    }

    // MARK: - State Publisher Tests

    func testStatePublisherEmitsStateChanges() async throws {
        let expectation = expectation(description: "State changed")
        var states: [AppState] = []

        appController.statePublisher
            .sink { state in
                states.append(state)
                if state == .running {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertTrue(states.contains(.running))
    }

    // MARK: - AppState Equatable

    func testAppStateEquatable() {
        XCTAssertEqual(AppState.initializing, AppState.initializing)
        XCTAssertEqual(AppState.running, AppState.running)
        XCTAssertEqual(AppState.disabled, AppState.disabled)
        XCTAssertEqual(AppState.waitingForPermission, AppState.waitingForPermission)
        XCTAssertEqual(AppState.error("test"), AppState.error("test"))
        XCTAssertNotEqual(AppState.running, AppState.disabled)
    }

    // MARK: - setRuleEnabled / Published Rules

    func testSetRuleEnabledPersistsFlipsEngineAndRepublishes() throws {
        let rule = BasicRule(id: "r1", description: "test", enabled: true, from: "a", to: "b")
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: [.basic(rule)]))

        try appController.setRuleEnabled(id: "r1", enabled: false)

        // Persisted to the manager
        guard case .basic(let saved) = configManager.configuration.rules.first else {
            return XCTFail("expected a basic rule")
        }
        XCTAssertFalse(saved.enabled, "saved rule should be disabled")

        // Engine reflects the change
        guard case .basic(let engineRule) = ruleEngine.rules.first else {
            return XCTFail("expected a basic rule in engine")
        }
        XCTAssertFalse(engineRule.enabled, "engine rule should be disabled")

        // Published rules mirror persisted config
        XCTAssertEqual(appController.rules, configManager.configuration.rules)
        XCTAssertEqual(appController.rules.first?.id, "r1")
    }

    func testSetRuleEnabledPublishesValidationErrors() throws {
        let bad = BasicRule(id: "bad", description: nil, enabled: true, from: "a", to: "nonexistent")
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: [.basic(bad)]))

        try appController.setRuleEnabled(id: "bad", enabled: false)

        XCTAssertEqual(appController.validationErrors["bad"]?.isEmpty, false,
                       "invalid rule should surface a validation error keyed by id")
    }

    func testSetRuleEnabledRethrowsAndLeavesStateUnchangedWhenSaveFails() throws {
        let engine = RuleEngine(keyMapper: keyMapper, modifierHandler: ModifierHandler())
        let seed = Configuration(
            version: "1.0",
            enabled: true,
            rules: [.basic(BasicRule(id: "r1", description: nil, enabled: true, from: "a", to: "b"))]
        )
        let throwing = ThrowingOnSaveConfigManager(configuration: seed)
        let controller = AppController(
            permissionManager: MockPermissionManager(),
            configManager: throwing,
            eventTapManager: MockEventTapManager(),
            ruleEngine: engine,
            keyMapper: keyMapper,
            logger: mockLogger
        )

        XCTAssertThrowsError(try controller.setRuleEnabled(id: "r1", enabled: false))

        XCTAssertTrue(controller.rules.isEmpty, "rules must not republish when save fails")
        XCTAssertTrue(engine.rules.isEmpty, "engine must be untouched when save fails")
    }

    func testSetRuleEnabledRoundTripsThroughConfigFileLeavingOtherRulesUntouched() throws {
        let configURL = configManager.configurationURL
        let r1 = BasicRule(id: "r1", description: "one", enabled: true, from: "a", to: "b")
        let r2 = BasicRule(id: "r2", description: "two", enabled: true, from: "c", to: "d")
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: [.basic(r1), .basic(r2)]))

        try appController.setRuleEnabled(id: "r1", enabled: false)

        // Re-read from disk with a fresh manager — a true file round-trip.
        let fresh = ConfigurationManager(configurationURL: configURL, keyMapper: keyMapper)
        let reloaded = try fresh.load()

        let byId = Dictionary(uniqueKeysWithValues: reloaded.rules.map { ($0.id, $0) })
        guard case .basic(let reloadedR1)? = byId["r1"],
              case .basic(let reloadedR2)? = byId["r2"] else {
            return XCTFail("expected both rules present on disk")
        }
        XCTAssertFalse(reloadedR1.enabled, "toggled rule should be disabled on disk")
        XCTAssertTrue(reloadedR2.enabled, "other rule should be untouched on disk")
    }

    // MARK: - reloadConfiguration content-diff

    func testReloadConfigurationIsNoOpWhenContentUnchanged() throws {
        let rule = BasicRule(id: "r1", description: nil, enabled: true, from: "a", to: "b")
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: [.basic(rule)]))

        // Drift sentinel: if reload runs, it repopulates the engine from disk.
        ruleEngine.rules = []

        try appController.reloadConfiguration() // disk is identical to current config

        XCTAssertTrue(ruleEngine.rules.isEmpty, "identical-content reload must be a no-op")
    }

    func testReloadConfigurationReloadsWhenContentChanged() throws {
        try configManager.save(Configuration(
            version: "1.0", enabled: true,
            rules: [.basic(BasicRule(id: "r1", description: nil, enabled: true, from: "a", to: "b"))]
        ))
        ruleEngine.rules = []

        // External writer changes the file on disk.
        let external = ConfigurationManager(configurationURL: configManager.configurationURL, keyMapper: keyMapper)
        try external.save(Configuration(
            version: "1.0", enabled: true,
            rules: [.basic(BasicRule(id: "r2", description: nil, enabled: true, from: "c", to: "d"))]
        ))

        try appController.reloadConfiguration()

        XCTAssertEqual(ruleEngine.rules.count, 1)
        XCTAssertEqual(ruleEngine.rules.first?.id, "r2", "changed content must reload the engine")
    }

    // MARK: - CRUD (add / update / delete)

    func testAddRulePersistsReloadsAndRepublishes() throws {
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: []))

        try appController.addRule(.basic(BasicRule(id: "r1", description: "new", enabled: true, from: "a", to: "b")))

        XCTAssertEqual(configManager.configuration.rules.map(\.id), ["r1"])
        XCTAssertEqual(ruleEngine.rules.map(\.id), ["r1"])
        XCTAssertEqual(appController.rules.map(\.id), ["r1"])
    }

    func testUpdateRuleReplacesMatchingIdLeavingOthersUntouched() throws {
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: [
            .basic(BasicRule(id: "r1", description: "one", enabled: true, from: "a", to: "b")),
            .basic(BasicRule(id: "r2", description: "two", enabled: true, from: "c", to: "d"))
        ]))

        try appController.updateRule(.basic(BasicRule(id: "r1", description: "one-edited", enabled: false, from: "a", to: "e")))

        let byId = Dictionary(uniqueKeysWithValues: configManager.configuration.rules.map { ($0.id, $0) })
        guard case .basic(let r1)? = byId["r1"], case .basic(let r2)? = byId["r2"] else {
            return XCTFail("expected both rules present")
        }
        XCTAssertEqual(r1.to, "e")
        XCTAssertFalse(r1.enabled)
        XCTAssertEqual(r2.description, "two", "other rule must be untouched")
    }

    func testDeleteRuleRemovesAndPersists() throws {
        try configManager.save(Configuration(version: "1.0", enabled: true, rules: [
            .basic(BasicRule(id: "r1", description: nil, enabled: true, from: "a", to: "b")),
            .basic(BasicRule(id: "r2", description: nil, enabled: true, from: "c", to: "d"))
        ]))

        try appController.deleteRule(id: "r1")

        XCTAssertEqual(configManager.configuration.rules.map(\.id), ["r2"])
        XCTAssertEqual(appController.rules.map(\.id), ["r2"])
    }

    func testCRUDSaveFailureLeavesStateUnchanged() throws {
        let engine = RuleEngine(keyMapper: keyMapper, modifierHandler: ModifierHandler())
        let seed = Configuration(
            version: "1.0", enabled: true,
            rules: [.basic(BasicRule(id: "r1", description: nil, enabled: true, from: "a", to: "b"))]
        )
        let controller = AppController(
            permissionManager: MockPermissionManager(),
            configManager: ThrowingOnSaveConfigManager(configuration: seed),
            eventTapManager: MockEventTapManager(),
            ruleEngine: engine,
            keyMapper: keyMapper,
            logger: mockLogger
        )

        XCTAssertThrowsError(try controller.addRule(.basic(BasicRule(id: "r2", description: nil, enabled: true, from: "c", to: "d"))))
        XCTAssertTrue(engine.rules.isEmpty, "engine untouched on save failure")
        XCTAssertTrue(controller.rules.isEmpty, "published rules untouched on save failure")
    }

    // MARK: - Capture suspend / resume

    func testSuspendResumeAroundCapturePreservesEnabledState() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()
        XCTAssertTrue(appController.isEnabled)
        XCTAssertTrue(mockEventTapManager.isEnabled)

        appController.suspendForCapture()
        XCTAssertFalse(mockEventTapManager.isEnabled, "tap suspended during capture")
        XCTAssertTrue(appController.isEnabled, "logical enabled must not change")
        XCTAssertEqual(appController.state, .running, "menu-bar state must not change")

        appController.resumeAfterCapture()
        XCTAssertTrue(mockEventTapManager.isEnabled, "tap restored after capture")
        XCTAssertTrue(appController.isEnabled)
        XCTAssertEqual(appController.state, .running)
    }

    func testResumeAfterCaptureKeepsTapDisabledWhenRemappingGloballyOff() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()
        appController.toggleEnabled() // user turns remapping OFF
        XCTAssertFalse(appController.isEnabled)
        XCTAssertFalse(mockEventTapManager.isEnabled)

        appController.suspendForCapture()
        appController.resumeAfterCapture()

        XCTAssertFalse(mockEventTapManager.isEnabled, "must NOT re-enable a globally-disabled tap")
        XCTAssertFalse(appController.isEnabled)
        XCTAssertEqual(appController.state, .disabled)
    }

    func testResumeAfterCaptureIsIdempotent() async throws {
        mockPermissionManager.mockStatus = .granted
        try await appController.start()

        appController.suspendForCapture()
        appController.resumeAfterCapture()
        let countAfterFirstResume = mockEventTapManager.setEnabledCallCount

        appController.resumeAfterCapture() // second resume: no-op

        XCTAssertEqual(mockEventTapManager.setEnabledCallCount, countAfterFirstResume,
                       "a second resume must not touch the tap")
    }

    // MARK: - Parse-error resilience on auto-reload

    func testReloadFromDiskKeepsLastGoodRulesOnParseError() throws {
        try appController.addRule(.basic(BasicRule(
            id: "r1", description: "a→b", enabled: true, from: "a", to: "b"
        )))
        let baselineCount = appController.rules.count
        XCTAssertGreaterThan(baselineCount, 0)

        // External edit corrupts the file.
        try "{ this is not valid json".write(
            to: configManager.configurationURL, atomically: true, encoding: .utf8
        )

        appController.reloadFromDisk() // watcher-driven, must not throw

        XCTAssertEqual(appController.rules.count, baselineCount, "last-good rules must stay active")
        XCTAssertNotNil(appController.reloadError, "parse failure should surface a banner message")
    }

    func testReloadFromDiskClearsErrorOnRecovery() throws {
        try appController.addRule(.basic(BasicRule(
            id: "r1", description: "a→b", enabled: true, from: "a", to: "b"
        )))

        try "{ broken".write(to: configManager.configurationURL, atomically: true, encoding: .utf8)
        appController.reloadFromDisk()
        XCTAssertNotNil(appController.reloadError)

        // External edit fixes the file with a different valid config.
        let recovered = Configuration(version: "1.0", enabled: true, rules: [
            .basic(BasicRule(id: "r2", description: "c→d", enabled: true, from: "c", to: "d"))
        ])
        let writer = ConfigurationManager(configurationURL: configManager.configurationURL, keyMapper: keyMapper)
        try writer.save(recovered)

        appController.reloadFromDisk()

        XCTAssertNil(appController.reloadError, "valid reload should clear the banner")
        XCTAssertEqual(appController.rules.map(\.id), ["r2"], "recovered rules become active")
    }
}

/// Test double that always fails on `save`, leaving its configuration unchanged.
private final class ThrowingOnSaveConfigManager: ConfigurationManaging {
    private(set) var configuration: Configuration
    let configurationURL = URL(fileURLWithPath: "/tmp/kye-throwing-test.json")

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func load() throws -> Configuration { configuration }
    func save(_ configuration: Configuration) throws { throw AppError.configurationInaccessible }
    func validate(_ configuration: Configuration, keyMapper: KeyMapping) -> [ConfigurationError] { [] }
    func reload() throws {}
}
