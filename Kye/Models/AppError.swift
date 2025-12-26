import Foundation

/// Application-level errors with user-friendly descriptions
enum AppError: Error, LocalizedError, Equatable {
    /// Failed to create CGEvent tap
    case eventTapCreationFailed

    /// Accessibility permission not granted
    case permissionDenied

    /// JSON configuration file parse error
    case configurationParseError(line: Int, message: String)

    /// Invalid key name in configuration
    case invalidKeyName(String)

    /// Event tap was disabled by the system
    case eventTapDisabled

    /// Configuration file cannot be accessed
    case configurationInaccessible

    /// Event processing exceeded timeout
    case eventTapTimeout

    /// Configuration validation error for a specific rule
    case configurationValidationError(ruleId: String, message: String)

    /// Failed to register/unregister for launch at login
    case launchAtLoginFailed

    var errorDescription: String? {
        switch self {
        case .eventTapCreationFailed:
            return "Failed to create event tap. Please check Accessibility permissions."

        case .permissionDenied:
            return "Accessibility permission is required for key remapping."

        case .configurationParseError(let line, let message):
            return "Configuration error at line \(line): \(message)"

        case .invalidKeyName(let name):
            return "Invalid key name: '\(name)'. Please check your configuration."

        case .eventTapDisabled:
            return "Event tap was disabled by the system. Key remapping is currently inactive."

        case .configurationInaccessible:
            return "Could not access configuration file. Using default settings."

        case .eventTapTimeout:
            return "Event processing took too long and was skipped."

        case .configurationValidationError(let ruleId, let message):
            return "Rule '\(ruleId)' is invalid: \(message)"

        case .launchAtLoginFailed:
            return "Failed to configure launch at login. Please check system settings."
        }
    }
}
