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
        try configManager.save(invalidConfig)

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
