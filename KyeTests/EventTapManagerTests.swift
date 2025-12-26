import XCTest
import CoreGraphics
@testable import Kye

final class EventTapManagerTests: XCTestCase {

    var eventTapManager: EventTapManager!

    override func setUp() {
        super.setUp()
        eventTapManager = EventTapManager()
    }

    override func tearDown() {
        eventTapManager?.stop()
        eventTapManager = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsNotRunning() {
        XCTAssertFalse(eventTapManager.isRunning)
    }

    func testInitialStateIsNotEnabled() {
        XCTAssertFalse(eventTapManager.isEnabled)
    }

    func testCallbacksAreNilByDefault() {
        XCTAssertNil(eventTapManager.onEventReceived)
        XCTAssertNil(eventTapManager.onTapDisabled)
    }

    // MARK: - Callback Assignment Tests

    func testCanSetEventCallback() {
        eventTapManager.onEventReceived = { event, type in
            return event
        }

        XCTAssertNotNil(eventTapManager.onEventReceived)
    }

    func testCanSetDisabledCallback() {
        eventTapManager.onTapDisabled = {
            // Handle disabled
        }

        XCTAssertNotNil(eventTapManager.onTapDisabled)
    }

    // MARK: - Protocol Conformance

    func testConformsToEventTapManagingProtocol() {
        let manager: any EventTapManaging = eventTapManager
        XCTAssertNotNil(manager)
    }

    // MARK: - Stop Without Start

    func testStopWithoutStartDoesNotCrash() {
        // Should not throw or crash
        eventTapManager.stop()

        XCTAssertFalse(eventTapManager.isRunning)
    }

    // MARK: - SetEnabled Without Running

    func testSetEnabledWithoutRunningDoesNotCrash() {
        // Should not throw or crash
        eventTapManager.setEnabled(true)
        eventTapManager.setEnabled(false)

        XCTAssertFalse(eventTapManager.isEnabled)
    }

    // MARK: - Integration Tests (Require Accessibility Permissions)
    // Note: These tests will fail without Accessibility permissions granted

    func testStartCreatesEventTap() throws {
        // This test requires Accessibility permissions
        // Skip if not available
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility permissions required")
        }

        try eventTapManager.start()

        XCTAssertTrue(eventTapManager.isRunning)
        XCTAssertTrue(eventTapManager.isEnabled)
    }

    func testStopCleansUpResources() throws {
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility permissions required")
        }

        try eventTapManager.start()
        eventTapManager.stop()

        XCTAssertFalse(eventTapManager.isRunning)
        XCTAssertFalse(eventTapManager.isEnabled)
    }

    func testSetEnabledTogglesState() throws {
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility permissions required")
        }

        try eventTapManager.start()

        eventTapManager.setEnabled(false)
        XCTAssertFalse(eventTapManager.isEnabled)

        eventTapManager.setEnabled(true)
        XCTAssertTrue(eventTapManager.isEnabled)
    }

    func testStartWithoutPermissionsThrowsError() {
        // If permissions are NOT granted, start should throw
        guard !AXIsProcessTrusted() else {
            // Permissions are granted, can't test this scenario
            return
        }

        XCTAssertThrowsError(try eventTapManager.start()) { error in
            XCTAssertEqual(error as? AppError, .eventTapCreationFailed)
        }
    }

    func testMultipleStartCallsAreIdempotent() throws {
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility permissions required")
        }

        try eventTapManager.start()
        try eventTapManager.start()  // Second call should be no-op

        XCTAssertTrue(eventTapManager.isRunning)
    }

    func testMultipleStopCallsAreIdempotent() throws {
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility permissions required")
        }

        try eventTapManager.start()
        eventTapManager.stop()
        eventTapManager.stop()  // Second call should be no-op

        XCTAssertFalse(eventTapManager.isRunning)
    }
}

// MARK: - Mock Event Tap Manager for Testing Other Components

final class MockEventTapManager: EventTapManaging {
    var isEnabled: Bool = false
    var isRunning: Bool = false
    var onEventReceived: ((CGEvent, CGEventType) -> CGEvent?)?
    var onTapDisabled: (() -> Void)?

    var startCallCount = 0
    var stopCallCount = 0
    var setEnabledCallCount = 0
    var shouldThrowOnStart = false

    func start() throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw AppError.eventTapCreationFailed
        }
        isRunning = true
        isEnabled = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
        isEnabled = false
    }

    func setEnabled(_ enabled: Bool) {
        setEnabledCallCount += 1
        guard isRunning else { return }
        isEnabled = enabled
    }

    /// Simulate receiving an event (for testing)
    func simulateEvent(_ event: CGEvent, type: CGEventType) -> CGEvent? {
        return onEventReceived?(event, type)
    }

    /// Simulate tap being disabled
    func simulateTapDisabled() {
        isEnabled = false
        onTapDisabled?()
    }
}

// MARK: - Mock Event Tap Manager Tests

final class MockEventTapManagerTests: XCTestCase {

    func testMockStartSetsRunningState() throws {
        let mock = MockEventTapManager()

        try mock.start()

        XCTAssertTrue(mock.isRunning)
        XCTAssertTrue(mock.isEnabled)
        XCTAssertEqual(mock.startCallCount, 1)
    }

    func testMockStartCanThrow() {
        let mock = MockEventTapManager()
        mock.shouldThrowOnStart = true

        XCTAssertThrowsError(try mock.start())
    }

    func testMockStopClearsState() throws {
        let mock = MockEventTapManager()
        try mock.start()

        mock.stop()

        XCTAssertFalse(mock.isRunning)
        XCTAssertFalse(mock.isEnabled)
        XCTAssertEqual(mock.stopCallCount, 1)
    }

    func testMockSetEnabledTracksState() throws {
        let mock = MockEventTapManager()
        try mock.start()

        mock.setEnabled(false)

        XCTAssertFalse(mock.isEnabled)
        XCTAssertEqual(mock.setEnabledCallCount, 1)
    }

    func testMockSimulateTapDisabled() throws {
        let mock = MockEventTapManager()
        try mock.start()

        var callbackCalled = false
        mock.onTapDisabled = {
            callbackCalled = true
        }

        mock.simulateTapDisabled()

        XCTAssertFalse(mock.isEnabled)
        XCTAssertTrue(callbackCalled)
    }
}
