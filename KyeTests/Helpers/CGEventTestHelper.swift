import Foundation
import CoreGraphics

/// Helper for creating synthetic CGEvents in tests
enum CGEventTestHelper {

    // MARK: - Key Codes

    struct KeyCodes {
        // Letters
        static let a: CGKeyCode = 0x00
        static let s: CGKeyCode = 0x01
        static let d: CGKeyCode = 0x02
        static let h: CGKeyCode = 0x04
        static let j: CGKeyCode = 0x26
        static let k: CGKeyCode = 0x28
        static let l: CGKeyCode = 0x25
        static let w: CGKeyCode = 0x0D

        // Arrow keys
        static let leftArrow: CGKeyCode = 0x7B
        static let rightArrow: CGKeyCode = 0x7C
        static let downArrow: CGKeyCode = 0x7D
        static let upArrow: CGKeyCode = 0x7E

        // Modifiers
        static let rightCommand: CGKeyCode = 0x36
        static let leftCommand: CGKeyCode = 0x37
        static let rightOption: CGKeyCode = 0x3D
        static let leftOption: CGKeyCode = 0x3A
        static let rightControl: CGKeyCode = 0x3E
        static let leftControl: CGKeyCode = 0x3B
        static let rightShift: CGKeyCode = 0x3C
        static let leftShift: CGKeyCode = 0x38
    }

    // MARK: - Device Flags (NX_DEVICE*KEYMASK)

    struct DeviceFlags {
        static let leftControl: UInt64 = 0x00000001
        static let leftShift: UInt64 = 0x00000002
        static let rightShift: UInt64 = 0x00000004
        static let leftCommand: UInt64 = 0x00000008
        static let rightCommand: UInt64 = 0x00000010
        static let leftOption: UInt64 = 0x00000020
        static let rightOption: UInt64 = 0x00000040
        static let rightControl: UInt64 = 0x00002000
    }

    // MARK: - Event Creation

    /// Create a synthetic keyboard event
    /// - Parameters:
    ///   - keyCode: The virtual key code
    ///   - keyDown: Whether this is a key down event
    ///   - flags: The modifier flags
    /// - Returns: A CGEvent or nil if creation fails
    static func createKeyEvent(
        keyCode: CGKeyCode,
        keyDown: Bool,
        flags: CGEventFlags = []
    ) -> CGEvent? {
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: keyDown
        ) else {
            return nil
        }
        event.flags = flags
        return event
    }

    /// Create flags with device-specific modifier bits
    /// - Parameters:
    ///   - mainFlags: The main modifier flags (maskCommand, maskShift, etc.)
    ///   - deviceFlags: Device-specific flags for left/right distinction
    /// - Returns: Combined CGEventFlags
    static func createFlags(
        main: CGEventFlags,
        device: UInt64
    ) -> CGEventFlags {
        return CGEventFlags(rawValue: main.rawValue | device)
    }

    /// Create flags for Right Option pressed
    static func rightOptionFlags() -> CGEventFlags {
        return createFlags(main: .maskAlternate, device: DeviceFlags.rightOption)
    }

    /// Create flags for Left Option pressed
    static func leftOptionFlags() -> CGEventFlags {
        return createFlags(main: .maskAlternate, device: DeviceFlags.leftOption)
    }

    /// Create flags for both Left and Right Option pressed
    static func bothOptionFlags() -> CGEventFlags {
        return createFlags(
            main: .maskAlternate,
            device: DeviceFlags.leftOption | DeviceFlags.rightOption
        )
    }

    /// Create flags for Left Control + Right Option
    static func controlPlusRightOptionFlags() -> CGEventFlags {
        return createFlags(
            main: CGEventFlags([.maskControl, .maskAlternate]),
            device: DeviceFlags.leftControl | DeviceFlags.rightOption
        )
    }

    /// Create flags for Left Shift + Right Option
    static func shiftPlusRightOptionFlags() -> CGEventFlags {
        return createFlags(
            main: CGEventFlags([.maskShift, .maskAlternate]),
            device: DeviceFlags.leftShift | DeviceFlags.rightOption
        )
    }

    /// Create flags for Left Control + Left Shift + Right Option
    static func controlShiftPlusRightOptionFlags() -> CGEventFlags {
        return createFlags(
            main: CGEventFlags([.maskControl, .maskShift, .maskAlternate]),
            device: DeviceFlags.leftControl | DeviceFlags.leftShift | DeviceFlags.rightOption
        )
    }

    // MARK: - Result Verification

    /// Extract key code from event
    static func getKeyCode(from event: CGEvent) -> CGKeyCode {
        return CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    }

    /// Check if flags contain a specific main modifier
    static func hasModifier(_ flags: CGEventFlags, modifier: CGEventFlags) -> Bool {
        return flags.contains(modifier)
    }

    /// Check if flags contain a specific device flag
    static func hasDeviceFlag(_ flags: CGEventFlags, deviceFlag: UInt64) -> Bool {
        return (flags.rawValue & deviceFlag) != 0
    }
}
