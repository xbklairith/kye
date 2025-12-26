import XCTest
@testable import Kye

final class LoggerServiceTests: XCTestCase {

    // MARK: - Protocol Conformance

    func testLoggerServiceConformsToLoggingProtocol() {
        let logger: any Logging = LoggerService()
        XCTAssertNotNil(logger)
    }

    // MARK: - Logger Creation

    func testLoggerCreatesWithDefaultSubsystem() {
        let logger = LoggerService()
        XCTAssertNotNil(logger)
    }

    func testLoggerCreatesWithCustomSubsystem() {
        let logger = LoggerService(subsystem: "com.test.app")
        XCTAssertNotNil(logger)
    }

    // MARK: - Log Level Comparison

    func testLogLevelComparison() {
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
        XCTAssertFalse(LogLevel.error < LogLevel.debug)
    }

    // MARK: - Log Category Raw Values

    func testLogCategoryRawValues() {
        XCTAssertEqual(LogCategory.app.rawValue, "app")
        XCTAssertEqual(LogCategory.eventTap.rawValue, "event_tap")
        XCTAssertEqual(LogCategory.configuration.rawValue, "configuration")
        XCTAssertEqual(LogCategory.permission.rawValue, "permission")
        XCTAssertEqual(LogCategory.ui.rawValue, "ui")
    }

    // MARK: - Logger Methods Don't Crash

    func testDebugLogDoesNotCrash() {
        let logger = LoggerService()
        logger.debug("Test debug message", category: .app)
    }

    func testInfoLogDoesNotCrash() {
        let logger = LoggerService()
        logger.info("Test info message", category: .app)
    }

    func testWarningLogDoesNotCrash() {
        let logger = LoggerService()
        logger.warning("Test warning message", category: .app)
    }

    func testErrorLogDoesNotCrash() {
        let logger = LoggerService()
        logger.error("Test error message", category: .app)
    }

    func testLoggingToAllCategories() {
        let logger = LoggerService()

        // Should not crash for any category
        logger.info("Test message", category: .app)
        logger.info("Test message", category: .eventTap)
        logger.info("Test message", category: .configuration)
        logger.info("Test message", category: .permission)
        logger.info("Test message", category: .ui)
    }
}

// MARK: - MockLogger Tests

final class MockLoggerTests: XCTestCase {

    var mockLogger: MockLogger!

    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
    }

    override func tearDown() {
        mockLogger = nil
        super.tearDown()
    }

    func testMockLoggerConformsToLoggingProtocol() {
        let logger: any Logging = mockLogger
        XCTAssertNotNil(logger)
    }

    func testMockLoggerRecordsDebugEntries() {
        mockLogger.debug("Test debug", category: .app)

        XCTAssertEqual(mockLogger.entries.count, 1)
        XCTAssertEqual(mockLogger.entries[0].level, .debug)
        XCTAssertEqual(mockLogger.entries[0].message, "Test debug")
        XCTAssertEqual(mockLogger.entries[0].category, .app)
    }

    func testMockLoggerRecordsInfoEntries() {
        mockLogger.info("Test info", category: .eventTap)

        XCTAssertEqual(mockLogger.entries.count, 1)
        XCTAssertEqual(mockLogger.entries[0].level, .info)
        XCTAssertEqual(mockLogger.entries[0].message, "Test info")
        XCTAssertEqual(mockLogger.entries[0].category, .eventTap)
    }

    func testMockLoggerRecordsWarningEntries() {
        mockLogger.warning("Test warning", category: .configuration)

        XCTAssertEqual(mockLogger.entries.count, 1)
        XCTAssertEqual(mockLogger.entries[0].level, .warning)
        XCTAssertEqual(mockLogger.entries[0].message, "Test warning")
        XCTAssertEqual(mockLogger.entries[0].category, .configuration)
    }

    func testMockLoggerRecordsErrorEntries() {
        mockLogger.error("Test error", category: .permission)

        XCTAssertEqual(mockLogger.entries.count, 1)
        XCTAssertEqual(mockLogger.entries[0].level, .error)
        XCTAssertEqual(mockLogger.entries[0].message, "Test error")
        XCTAssertEqual(mockLogger.entries[0].category, .permission)
    }

    func testMockLoggerRecordsMultipleEntries() {
        mockLogger.debug("Debug 1", category: .app)
        mockLogger.info("Info 1", category: .eventTap)
        mockLogger.warning("Warning 1", category: .configuration)
        mockLogger.error("Error 1", category: .permission)

        XCTAssertEqual(mockLogger.entries.count, 4)
    }

    func testMockLoggerClear() {
        mockLogger.info("Test", category: .app)
        mockLogger.info("Test 2", category: .ui)

        XCTAssertEqual(mockLogger.entries.count, 2)

        mockLogger.clear()

        XCTAssertEqual(mockLogger.entries.count, 0)
    }

    func testMockLoggerHasEntryWithLevel() {
        mockLogger.error("Something went wrong", category: .app)

        XCTAssertTrue(mockLogger.hasEntry(level: .error, containing: "wrong"))
        XCTAssertFalse(mockLogger.hasEntry(level: .info, containing: "wrong"))
    }

    func testMockLoggerHasEntryWithCategory() {
        mockLogger.info("Event tap started", category: .eventTap)

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "tap", category: .eventTap))
        XCTAssertFalse(mockLogger.hasEntry(level: .info, containing: "tap", category: .app))
    }

    func testMockLoggerHasEntryWithPartialMatch() {
        mockLogger.warning("Configuration file not found at path /config.json", category: .configuration)

        XCTAssertTrue(mockLogger.hasEntry(level: .warning, containing: "not found"))
        XCTAssertTrue(mockLogger.hasEntry(level: .warning, containing: "Configuration"))
        XCTAssertFalse(mockLogger.hasEntry(level: .warning, containing: "error"))
    }
}
