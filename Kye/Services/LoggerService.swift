import Foundation
import os.log

/// Log levels for categorizing messages
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Log categories for filtering
enum LogCategory: String {
    case app = "app"
    case eventTap = "event_tap"
    case configuration = "configuration"
    case permission = "permission"
    case ui = "ui"
}

/// Protocol for logging service
protocol Logging {
    func debug(_ message: String, category: LogCategory)
    func info(_ message: String, category: LogCategory)
    func warning(_ message: String, category: LogCategory)
    func error(_ message: String, category: LogCategory)
}

/// OSLog-based logging service
final class LoggerService: Logging {

    private let subsystem: String
    private var loggers: [LogCategory: Logger] = [:]

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.kye.app") {
        self.subsystem = subsystem

        // Pre-create loggers for all categories
        for category in [LogCategory.app, .eventTap, .configuration, .permission, .ui] {
            loggers[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
    }

    func debug(_ message: String, category: LogCategory) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    func info(_ message: String, category: LogCategory) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    func warning(_ message: String, category: LogCategory) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    func error(_ message: String, category: LogCategory) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    // MARK: - Private

    private func logger(for category: LogCategory) -> Logger {
        if let logger = loggers[category] {
            return logger
        }
        // Fallback (shouldn't happen)
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
}

/// Mock logger for testing
final class MockLogger: Logging {
    struct LogEntry: Equatable {
        let level: LogLevel
        let message: String
        let category: LogCategory
    }

    private(set) var entries: [LogEntry] = []

    func debug(_ message: String, category: LogCategory) {
        entries.append(LogEntry(level: .debug, message: message, category: category))
    }

    func info(_ message: String, category: LogCategory) {
        entries.append(LogEntry(level: .info, message: message, category: category))
    }

    func warning(_ message: String, category: LogCategory) {
        entries.append(LogEntry(level: .warning, message: message, category: category))
    }

    func error(_ message: String, category: LogCategory) {
        entries.append(LogEntry(level: .error, message: message, category: category))
    }

    func clear() {
        entries.removeAll()
    }

    func hasEntry(level: LogLevel, containing: String, category: LogCategory? = nil) -> Bool {
        entries.contains { entry in
            entry.level == level &&
            entry.message.contains(containing) &&
            (category == nil || entry.category == category)
        }
    }
}
