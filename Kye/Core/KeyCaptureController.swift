import AppKit
import CoreGraphics

/// Something that can suspend/resume key remapping around a capture (implemented by `AppController`).
protocol CaptureSuspending: AnyObject {
    func suspendForCapture()
    func resumeAfterCapture()
}

/// Records a single physical key press for the rule editor — including modifier keys,
/// which only emit `.flagsChanged` (never `.keyDown`). The remap tap is suspended during
/// capture so the captured key is the physical one, and always resumed on teardown.
final class KeyCaptureController {

    private let keyMapper: KeyMapping
    private weak var suspender: CaptureSuspending?
    private var monitor: Any?
    private var onCapture: ((String) -> Void)?

    init(keyMapper: KeyMapping = KeyMapper(), suspender: CaptureSuspending?) {
        self.keyMapper = keyMapper
        self.suspender = suspender
    }

    /// Begins capture: suspends the tap and installs one local monitor for key + modifier events.
    func begin(onCapture: @escaping (String) -> Void) {
        guard monitor == nil else { return }
        self.onCapture = onCapture
        suspender?.suspendForCapture()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if let name = Self.capturedKeyName(
                type: event.type, keyCode: event.keyCode,
                modifierFlags: event.modifierFlags, keyMapper: self.keyMapper
            ) {
                let handler = self.onCapture
                self.teardown()
                handler?(name)
            }
            return nil // swallow the keystroke while capturing
        }
    }

    /// Cancels capture without recording; always resumes the tap.
    func cancel() {
        teardown()
    }

    private func teardown() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onCapture = nil
        suspender?.resumeAfterCapture()
    }

    // MARK: - Pure resolver (unit-tested)

    /// Maps a raw event into a canonical `KeyMapper` key name, or `nil` to keep waiting.
    /// `.keyDown` → the key's name; `.flagsChanged` → the specific modifier on its *press*
    /// edge (mask set); the release edge and unknown keycodes yield `nil`.
    static func capturedKeyName(
        type: NSEvent.EventType,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        keyMapper: KeyMapping
    ) -> String? {
        switch type {
        case .keyDown:
            return keyMapper.keyName(for: CGKeyCode(keyCode))
        case .flagsChanged:
            guard let (name, mask) = modifierKey(for: keyCode) else { return nil }
            return modifierFlags.contains(mask) ? name : nil
        default:
            return nil
        }
    }

    private static func modifierKey(for keyCode: UInt16) -> (String, NSEvent.ModifierFlags)? {
        switch keyCode {
        case 0x37: return ("left_command", .command)
        case 0x36: return ("right_command", .command)
        case 0x3A: return ("left_option", .option)
        case 0x3D: return ("right_option", .option)
        case 0x38: return ("left_shift", .shift)
        case 0x3C: return ("right_shift", .shift)
        case 0x3B: return ("left_control", .control)
        case 0x3E: return ("right_control", .control)
        case 0x39: return ("caps_lock", .capsLock)
        default: return nil
        }
    }
}

extension AppController: CaptureSuspending {}
