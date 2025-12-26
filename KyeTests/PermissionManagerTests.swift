import XCTest
@testable import Kye

final class PermissionManagerTests: XCTestCase {

    var permissionManager: PermissionManager!
    var mockLogger: MockLogger!

    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        permissionManager = PermissionManager(logger: mockLogger, pollingInterval: 0.1)
    }

    override func tearDown() {
        permissionManager?.stopMonitoring()
        permissionManager = nil
        mockLogger = nil
        super.tearDown()
    }

    // MARK: - Protocol Conformance

    func testConformsToPermissionManagingProtocol() {
        let manager: any PermissionManaging = permissionManager
        XCTAssertNotNil(manager)
    }

    // MARK: - Initial State

    func testInitialStatusIsUnknown() {
        let manager = PermissionManager()
        XCTAssertEqual(manager.status, .unknown)
    }

    // MARK: - Check Permission

    func testCheckPermissionReturnsStatus() {
        let status = permissionManager.checkPermission()

        // Status should be either granted or denied (not unknown)
        XCTAssertNotEqual(status, .unknown)
    }

    func testCheckPermissionUpdatesStatus() {
        _ = permissionManager.checkPermission()

        XCTAssertNotEqual(permissionManager.status, .unknown)
    }

    // MARK: - Status Callback

    func testStatusChangedCallbackCalledOnChange() {
        let expectation = expectation(description: "Status changed callback")
        var receivedStatus: PermissionStatus?

        permissionManager.onStatusChanged = { status in
            receivedStatus = status
            expectation.fulfill()
        }

        // Check permission should update status
        _ = permissionManager.checkPermission()

        waitForExpectations(timeout: 1.0)

        XCTAssertNotNil(receivedStatus)
    }

    // MARK: - Request Permission

    func testRequestPermissionDoesNotCrash() {
        // Just verify it doesn't crash (actual permission prompt requires interaction)
        permissionManager.requestPermission()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "Requesting"))
    }

    // MARK: - Open System Preferences

    func testOpenSystemPreferencesLogsAction() {
        permissionManager.openSystemPreferences()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "System Settings"))
    }

    // MARK: - Monitoring

    func testStartMonitoringChecksPermissionImmediately() {
        permissionManager.startMonitoring()

        // Status should be checked immediately
        XCTAssertNotEqual(permissionManager.status, .unknown)
    }

    func testStartMonitoringLogs() {
        permissionManager.startMonitoring()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "Starting permission monitoring"))
    }

    func testStopMonitoringLogs() {
        permissionManager.startMonitoring()
        permissionManager.stopMonitoring()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "Stopped"))
    }

    func testStartMonitoringIsIdempotent() {
        permissionManager.startMonitoring()
        permissionManager.startMonitoring() // Second call should be no-op

        // Should only log once
        let startLogs = mockLogger.entries.filter { $0.message.contains("Starting") }
        XCTAssertEqual(startLogs.count, 1)
    }

    func testStopMonitoringIsIdempotent() {
        permissionManager.stopMonitoring() // Not started yet
        permissionManager.startMonitoring()
        permissionManager.stopMonitoring()
        permissionManager.stopMonitoring() // Already stopped

        // Should work without issues
    }

    // MARK: - Permission Status Enum

    func testPermissionStatusEquatable() {
        XCTAssertEqual(PermissionStatus.granted, PermissionStatus.granted)
        XCTAssertEqual(PermissionStatus.denied, PermissionStatus.denied)
        XCTAssertEqual(PermissionStatus.unknown, PermissionStatus.unknown)
        XCTAssertNotEqual(PermissionStatus.granted, PermissionStatus.denied)
    }
}

// MARK: - Mock Permission Manager Tests

final class MockPermissionManagerTests: XCTestCase {

    func testMockConformsToProtocol() {
        let mock: any PermissionManaging = MockPermissionManager()
        XCTAssertNotNil(mock)
    }

    func testMockCheckPermissionTracksCallCount() {
        let mock = MockPermissionManager()

        _ = mock.checkPermission()
        _ = mock.checkPermission()

        XCTAssertEqual(mock.checkPermissionCallCount, 2)
    }

    func testMockRequestPermissionTracksCallCount() {
        let mock = MockPermissionManager()

        mock.requestPermission()

        XCTAssertEqual(mock.requestPermissionCallCount, 1)
    }

    func testMockOpenSystemPreferencesTracksCallCount() {
        let mock = MockPermissionManager()

        mock.openSystemPreferences()

        XCTAssertEqual(mock.openSystemPreferencesCallCount, 1)
    }

    func testMockSimulatePermissionGranted() {
        let mock = MockPermissionManager()
        var callbackInvoked = false

        mock.onStatusChanged = { status in
            callbackInvoked = true
            XCTAssertEqual(status, .granted)
        }

        mock.simulatePermissionGranted()

        XCTAssertEqual(mock.status, .granted)
        XCTAssertTrue(callbackInvoked)
    }

    func testMockSimulatePermissionDenied() {
        let mock = MockPermissionManager()
        mock.mockStatus = .granted
        mock.status = .granted

        var callbackInvoked = false
        mock.onStatusChanged = { status in
            callbackInvoked = true
            XCTAssertEqual(status, .denied)
        }

        mock.simulatePermissionDenied()

        XCTAssertEqual(mock.status, .denied)
        XCTAssertTrue(callbackInvoked)
    }

    func testMockCheckPermissionReturnsMockStatus() {
        let mock = MockPermissionManager()
        mock.mockStatus = .granted

        let status = mock.checkPermission()

        XCTAssertEqual(status, .granted)
    }
}
