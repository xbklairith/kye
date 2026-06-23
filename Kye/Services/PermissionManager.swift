import Foundation
import AppKit
import ApplicationServices

/// Permission status for accessibility
enum PermissionStatus: Equatable {
    case granted
    case denied
    case unknown
}

/// Protocol for permission management
protocol PermissionManaging: AnyObject {
    var status: PermissionStatus { get }
    var onStatusChanged: ((PermissionStatus) -> Void)? { get set }

    func checkPermission() -> PermissionStatus
    func requestPermission()
    func openSystemPreferences()
    func startMonitoring()
    func stopMonitoring()
}

/// Manages Accessibility permission checking and monitoring
final class PermissionManager: PermissionManaging {

    private let logger: Logging?
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval
    private var isMonitoring = false

    private(set) var status: PermissionStatus = .unknown {
        didSet {
            if status != oldValue {
                logger?.info("Permission status changed: \(status)", category: .permission)
                onStatusChanged?(status)
            }
        }
    }

    var onStatusChanged: ((PermissionStatus) -> Void)?

    init(logger: Logging? = nil, pollingInterval: TimeInterval = 1.0) {
        self.logger = logger
        self.pollingInterval = pollingInterval
    }

    deinit {
        stopMonitoring()
    }

    func checkPermission() -> PermissionStatus {
        let trusted = AXIsProcessTrusted()
        status = trusted ? .granted : .denied
        return status
    }

    func requestPermission() {
        logger?.info("Requesting accessibility permission", category: .permission)

        // This triggers the system prompt for accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openSystemPreferences() {
        logger?.info("Opening System Settings Privacy pane", category: .permission)

        // Open Privacy & Security > Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func startMonitoring() {
        // Use a synchronous flag rather than `pollingTimer`, which is only
        // assigned inside the async block below — two rapid calls would both
        // see a nil timer and start (and log) twice.
        guard !isMonitoring else { return }
        isMonitoring = true

        logger?.info("Starting permission monitoring", category: .permission)

        // Check immediately
        _ = checkPermission()

        // Start polling for changes on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pollingTimer = Timer.scheduledTimer(withTimeInterval: self.pollingInterval, repeats: true) { [weak self] _ in
                self?.pollPermissionStatus()
            }
            // Ensure timer runs in common modes (including when menus are open)
            if let timer = self.pollingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        DispatchQueue.main.async { [weak self] in
            self?.pollingTimer?.invalidate()
            self?.pollingTimer = nil
        }
        logger?.info("Stopped permission monitoring", category: .permission)
    }

    // MARK: - Private

    private func pollPermissionStatus() {
        _ = checkPermission()
    }
}

/// Mock implementation for testing
final class MockPermissionManager: PermissionManaging {

    var status: PermissionStatus = .unknown
    var onStatusChanged: ((PermissionStatus) -> Void)?

    var checkPermissionCallCount = 0
    var requestPermissionCallCount = 0
    var openSystemPreferencesCallCount = 0
    var startMonitoringCallCount = 0
    var stopMonitoringCallCount = 0

    var mockStatus: PermissionStatus = .denied

    func checkPermission() -> PermissionStatus {
        checkPermissionCallCount += 1
        status = mockStatus
        return status
    }

    func requestPermission() {
        requestPermissionCallCount += 1
    }

    func openSystemPreferences() {
        openSystemPreferencesCallCount += 1
    }

    func startMonitoring() {
        startMonitoringCallCount += 1
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    /// Simulate permission being granted
    func simulatePermissionGranted() {
        mockStatus = .granted
        status = .granted
        onStatusChanged?(.granted)
    }

    /// Simulate permission being denied
    func simulatePermissionDenied() {
        mockStatus = .denied
        status = .denied
        onStatusChanged?(.denied)
    }
}
