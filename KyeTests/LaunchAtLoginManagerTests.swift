import XCTest
@testable import Kye

final class LaunchAtLoginManagerTests: XCTestCase {

    var mockLogger: MockLogger!

    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
    }

    override func tearDown() {
        mockLogger = nil
        super.tearDown()
    }

    // MARK: - Protocol Conformance

    @available(macOS 13.0, *)
    func testConformsToLaunchAtLoginManagingProtocol() {
        let manager: any LaunchAtLoginManaging = LaunchAtLoginManager(logger: mockLogger)
        XCTAssertNotNil(manager)
    }

    // MARK: - Initial State

    @available(macOS 13.0, *)
    func testInitialStatusIsUnknown() {
        let manager = LaunchAtLoginManager()
        XCTAssertEqual(manager.status, .unknown)
    }

    // MARK: - Check Status

    @available(macOS 13.0, *)
    func testCheckStatusReturnsValidStatus() {
        let manager = LaunchAtLoginManager(logger: mockLogger)

        let status = manager.checkStatus()

        // Status should be one of the valid values (not unknown after check)
        XCTAssertNotEqual(status, .unknown)
    }

    @available(macOS 13.0, *)
    func testCheckStatusUpdatesInternalStatus() {
        let manager = LaunchAtLoginManager(logger: mockLogger)

        _ = manager.checkStatus()

        XCTAssertNotEqual(manager.status, .unknown)
    }

    // MARK: - isEnabled

    @available(macOS 13.0, *)
    func testIsEnabledReturnsTrueWhenStatusEnabled() {
        let mock = MockLaunchAtLoginManager()
        mock.status = .enabled

        XCTAssertTrue(mock.isEnabled)
    }

    @available(macOS 13.0, *)
    func testIsEnabledReturnsFalseWhenStatusDisabled() {
        let mock = MockLaunchAtLoginManager()
        mock.status = .disabled

        XCTAssertFalse(mock.isEnabled)
    }

    // MARK: - LaunchAtLoginStatus Enum

    func testLaunchAtLoginStatusEquatable() {
        XCTAssertEqual(LaunchAtLoginStatus.enabled, LaunchAtLoginStatus.enabled)
        XCTAssertEqual(LaunchAtLoginStatus.disabled, LaunchAtLoginStatus.disabled)
        XCTAssertEqual(LaunchAtLoginStatus.requiresApproval, LaunchAtLoginStatus.requiresApproval)
        XCTAssertEqual(LaunchAtLoginStatus.notFound, LaunchAtLoginStatus.notFound)
        XCTAssertEqual(LaunchAtLoginStatus.unknown, LaunchAtLoginStatus.unknown)
        XCTAssertNotEqual(LaunchAtLoginStatus.enabled, LaunchAtLoginStatus.disabled)
    }
}

// MARK: - Mock Launch At Login Manager Tests

final class MockLaunchAtLoginManagerTests: XCTestCase {

    func testMockConformsToProtocol() {
        let mock: any LaunchAtLoginManaging = MockLaunchAtLoginManager()
        XCTAssertNotNil(mock)
    }

    func testMockRegisterSetsStatusEnabled() throws {
        let mock = MockLaunchAtLoginManager()

        try mock.register()

        XCTAssertEqual(mock.status, .enabled)
        XCTAssertEqual(mock.registerCallCount, 1)
    }

    func testMockUnregisterSetsStatusDisabled() throws {
        let mock = MockLaunchAtLoginManager()
        mock.status = .enabled

        try mock.unregister()

        XCTAssertEqual(mock.status, .disabled)
        XCTAssertEqual(mock.unregisterCallCount, 1)
    }

    func testMockRegisterCanThrow() {
        let mock = MockLaunchAtLoginManager()
        mock.shouldThrowOnRegister = true

        XCTAssertThrowsError(try mock.register()) { error in
            XCTAssertEqual(error as? AppError, .launchAtLoginFailed)
        }
    }

    func testMockUnregisterCanThrow() {
        let mock = MockLaunchAtLoginManager()
        mock.shouldThrowOnUnregister = true

        XCTAssertThrowsError(try mock.unregister()) { error in
            XCTAssertEqual(error as? AppError, .launchAtLoginFailed)
        }
    }

    func testMockCheckStatusTracksCallCount() {
        let mock = MockLaunchAtLoginManager()
        mock.status = .enabled

        _ = mock.checkStatus()
        _ = mock.checkStatus()

        XCTAssertEqual(mock.checkStatusCallCount, 2)
    }

    func testMockCheckStatusReturnsCurrentStatus() {
        let mock = MockLaunchAtLoginManager()
        mock.status = .requiresApproval

        let result = mock.checkStatus()

        XCTAssertEqual(result, .requiresApproval)
    }

    func testMockIsEnabledReflectsStatus() {
        let mock = MockLaunchAtLoginManager()

        mock.status = .enabled
        XCTAssertTrue(mock.isEnabled)

        mock.status = .disabled
        XCTAssertFalse(mock.isEnabled)

        mock.status = .unknown
        XCTAssertFalse(mock.isEnabled)
    }
}
