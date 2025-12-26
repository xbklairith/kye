import Foundation
import ServiceManagement

/// Status for launch at login registration
enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case notFound
    case unknown
}

/// Protocol for launch at login management
protocol LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus { get }
    var isEnabled: Bool { get }

    func register() throws
    func unregister() throws
    func checkStatus() -> LaunchAtLoginStatus
}

/// Manages app registration for launch at login using SMAppService
@available(macOS 13.0, *)
final class LaunchAtLoginManager: LaunchAtLoginManaging {

    private let logger: Logging?
    private let appService: SMAppService

    private(set) var status: LaunchAtLoginStatus = .unknown

    var isEnabled: Bool {
        status == .enabled
    }

    init(logger: Logging? = nil) {
        self.logger = logger
        self.appService = SMAppService.mainApp
    }

    func register() throws {
        logger?.info("Registering for launch at login", category: .app)

        do {
            try appService.register()
            status = .enabled
            logger?.info("Successfully registered for launch at login", category: .app)
        } catch {
            logger?.error("Failed to register for launch at login: \(error)", category: .app)
            throw AppError.launchAtLoginFailed
        }
    }

    func unregister() throws {
        logger?.info("Unregistering from launch at login", category: .app)

        do {
            try appService.unregister()
            status = .disabled
            logger?.info("Successfully unregistered from launch at login", category: .app)
        } catch {
            logger?.error("Failed to unregister from launch at login: \(error)", category: .app)
            throw AppError.launchAtLoginFailed
        }
    }

    func checkStatus() -> LaunchAtLoginStatus {
        let serviceStatus = appService.status

        switch serviceStatus {
        case .enabled:
            status = .enabled
        case .notRegistered:
            status = .disabled
        case .requiresApproval:
            status = .requiresApproval
        case .notFound:
            status = .notFound
        @unknown default:
            status = .unknown
        }

        logger?.debug("Launch at login status: \(status)", category: .app)
        return status
    }
}

/// Mock implementation for testing
final class MockLaunchAtLoginManager: LaunchAtLoginManaging {

    var status: LaunchAtLoginStatus = .disabled
    var registerCallCount = 0
    var unregisterCallCount = 0
    var checkStatusCallCount = 0
    var shouldThrowOnRegister = false
    var shouldThrowOnUnregister = false

    var isEnabled: Bool {
        status == .enabled
    }

    func register() throws {
        registerCallCount += 1
        if shouldThrowOnRegister {
            throw AppError.launchAtLoginFailed
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if shouldThrowOnUnregister {
            throw AppError.launchAtLoginFailed
        }
        status = .disabled
    }

    func checkStatus() -> LaunchAtLoginStatus {
        checkStatusCallCount += 1
        return status
    }
}
