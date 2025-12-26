import XCTest
@testable import Kye

final class AppErrorTests: XCTestCase {

    // MARK: - LocalizedError Conformance Tests

    func testAppErrorConformsToLocalizedError() {
        let error: any LocalizedError = AppError.eventTapCreationFailed
        XCTAssertNotNil(error.errorDescription)
    }

    func testAppErrorConformsToError() {
        let error: any Error = AppError.eventTapCreationFailed
        XCTAssertNotNil(error)
    }

    // MARK: - Error Description Tests

    func testEventTapCreationFailedDescription() {
        let error = AppError.eventTapCreationFailed
        XCTAssertEqual(
            error.errorDescription,
            "Failed to create event tap. Please check Accessibility permissions."
        )
    }

    func testPermissionDeniedDescription() {
        let error = AppError.permissionDenied
        XCTAssertEqual(
            error.errorDescription,
            "Accessibility permission is required for key remapping."
        )
    }

    func testConfigurationParseErrorDescription() {
        let error = AppError.configurationParseError(line: 10, message: "Unexpected token")
        XCTAssertTrue(error.errorDescription!.contains("line 10"))
        XCTAssertTrue(error.errorDescription!.contains("Unexpected token"))
    }

    func testInvalidKeyNameDescription() {
        let error = AppError.invalidKeyName("invalid_key")
        XCTAssertTrue(error.errorDescription!.contains("invalid_key"))
    }

    func testEventTapDisabledDescription() {
        let error = AppError.eventTapDisabled
        XCTAssertEqual(
            error.errorDescription,
            "Event tap was disabled by the system. Key remapping is currently inactive."
        )
    }

    func testConfigurationInaccessibleDescription() {
        let error = AppError.configurationInaccessible
        XCTAssertEqual(
            error.errorDescription,
            "Could not access configuration file. Using default settings."
        )
    }

    func testEventTapTimeoutDescription() {
        let error = AppError.eventTapTimeout
        XCTAssertEqual(
            error.errorDescription,
            "Event processing took too long and was skipped."
        )
    }

    func testConfigurationValidationErrorDescription() {
        let error = AppError.configurationValidationError(ruleId: "rule-001", message: "Invalid from key")
        XCTAssertTrue(error.errorDescription!.contains("rule-001"))
        XCTAssertTrue(error.errorDescription!.contains("Invalid from key"))
    }

    // MARK: - All Error Cases Have Descriptions

    func testAllErrorCasesHaveDescriptions() {
        let allErrors: [AppError] = [
            .eventTapCreationFailed,
            .permissionDenied,
            .configurationParseError(line: 1, message: "test"),
            .invalidKeyName("test"),
            .eventTapDisabled,
            .configurationInaccessible,
            .eventTapTimeout,
            .configurationValidationError(ruleId: "test", message: "test")
        ]

        for error in allErrors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    // MARK: - User-Friendly Messages

    func testErrorMessagesAreUserFriendly() {
        // Error messages should not contain technical jargon or stack traces
        let allErrors: [AppError] = [
            .eventTapCreationFailed,
            .permissionDenied,
            .configurationParseError(line: 1, message: "test"),
            .invalidKeyName("test_key"),
            .eventTapDisabled,
            .configurationInaccessible,
            .eventTapTimeout,
            .configurationValidationError(ruleId: "rule-001", message: "test")
        ]

        for error in allErrors {
            let description = error.errorDescription!

            // Should not contain Swift internals
            XCTAssertFalse(description.contains("Optional"), "Error message should not mention 'Optional'")
            XCTAssertFalse(description.contains("nil"), "Error message should not mention 'nil'")

            // Should be reasonably short (max 150 chars for user display)
            XCTAssertLessThan(description.count, 150, "Error message for \(error) is too long")
        }
    }
}
