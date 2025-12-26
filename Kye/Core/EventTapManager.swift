import Foundation
import CoreGraphics
import AppKit

/// Protocol for managing CGEvent tap lifecycle
protocol EventTapManaging: AnyObject {
    var isEnabled: Bool { get }
    var isRunning: Bool { get }

    /// Callback for processing events. Return modified event or nil to suppress.
    var onEventReceived: ((CGEvent, CGEventType) -> CGEvent?)? { get set }

    /// Callback when tap is disabled by system
    var onTapDisabled: (() -> Void)? { get set }

    func start() throws
    func stop()
    func setEnabled(_ enabled: Bool)
}

/// Manages CGEvent tap for keyboard interception
final class EventTapManager: EventTapManaging {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var isEnabled: Bool = false
    private(set) var isRunning: Bool = false

    var onEventReceived: ((CGEvent, CGEventType) -> CGEvent?)?
    var onTapDisabled: (() -> Void)?

    private var wakeObserver: NSObjectProtocol?

    deinit {
        stop()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func start() throws {
        guard !isRunning else { return }

        // Create event tap at HID level to intercept keyboard events
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)

        // Create callback - must be a C function pointer
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passRetained(event)
            }

            let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        // Create the event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw AppError.eventTapCreationFailed
        }

        eventTap = tap

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = runLoopSource else {
            eventTap = nil
            throw AppError.eventTapCreationFailed
        }

        // Add to main run loop (must be main for UI apps)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        isEnabled = true
        isRunning = true

        // Subscribe to wake notifications
        setupWakeNotification()
    }

    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isEnabled = false
        isRunning = false
    }

    func setEnabled(_ enabled: Bool) {
        guard isRunning, let tap = eventTap else { return }

        CGEvent.tapEnable(tap: tap, enable: enabled)
        isEnabled = enabled
    }

    // MARK: - Private Methods

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        // Check if tap was disabled by system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            handleTapDisabled()
            return Unmanaged.passRetained(event)
        }

        // Process the event through the callback
        if let callback = onEventReceived {
            if let modifiedEvent = callback(event, type) {
                return Unmanaged.passRetained(modifiedEvent)
            } else {
                // Return nil to suppress the event
                return nil
            }
        }

        // No callback, pass through unchanged
        return Unmanaged.passRetained(event)
    }

    private func handleTapDisabled() {
        // Attempt to re-enable
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)

            // Check if successful
            if CGEvent.tapIsEnabled(tap: tap) {
                isEnabled = true
            } else {
                isEnabled = false
                onTapDisabled?()
            }
        }
    }

    private func setupWakeNotification() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }
    }

    private func handleSystemWake() {
        guard isRunning else { return }

        // Small delay to let system stabilize after wake
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.reestablishTapAfterWake()
        }
    }

    private func reestablishTapAfterWake() {
        guard let tap = eventTap else { return }

        // Try up to 3 times to re-enable tap
        for attempt in 1...3 {
            CGEvent.tapEnable(tap: tap, enable: true)

            if CGEvent.tapIsEnabled(tap: tap) {
                isEnabled = true
                return
            }

            // Wait before retry
            Thread.sleep(forTimeInterval: 0.2 * Double(attempt))
        }

        // Failed to re-enable after all attempts
        isEnabled = false
        onTapDisabled?()
    }
}
