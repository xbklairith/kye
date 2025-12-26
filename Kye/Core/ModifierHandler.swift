import Foundation
import CoreGraphics

/// Type of modifier key
enum ModifierType: Equatable {
    case command
    case option
    case control
    case shift
}

/// Side of a modifier key
enum ModifierSide: Equatable {
    case left
    case right
    case any
}

/// Protocol for handling modifier key detection and flag manipulation
protocol ModifierHandling {
    /// Check if a key code corresponds to a right-side modifier
    func isRightModifier(_ keyCode: CGKeyCode) -> Bool

    /// Check if a key code corresponds to a left-side modifier
    func isLeftModifier(_ keyCode: CGKeyCode) -> Bool

    /// Get the modifier type for a key code, or nil if not a modifier
    func getModifierType(_ keyCode: CGKeyCode) -> ModifierType?

    /// Check if specific modifier flag is present
    func hasModifier(_ flags: CGEventFlags, modifier: ModifierType) -> Bool

    /// Remove a specific modifier from flags while preserving others
    func stripModifier(_ flags: CGEventFlags, modifier: ModifierType) -> CGEventFlags

    /// Remove a specific modifier by key code (preserves other side's modifier)
    func stripModifierByKeyCode(_ flags: CGEventFlags, keyCode: CGKeyCode) -> CGEventFlags
}

/// Handles modifier key detection and flag manipulation
final class ModifierHandler: ModifierHandling {

    // Key codes for right modifiers
    private let rightCommand: CGKeyCode = 0x36
    private let rightOption: CGKeyCode = 0x3D
    private let rightControl: CGKeyCode = 0x3E
    private let rightShift: CGKeyCode = 0x3C

    // Key codes for left modifiers
    private let leftCommand: CGKeyCode = 0x37
    private let leftOption: CGKeyCode = 0x3A
    private let leftControl: CGKeyCode = 0x3B
    private let leftShift: CGKeyCode = 0x38

    // Device-specific modifier flags (NX_DEVICE*KEYMASK from IOKit)
    // These allow distinguishing left vs right modifiers
    private let deviceLeftCommand: UInt64 = 0x00000008
    private let deviceRightCommand: UInt64 = 0x00000010
    private let deviceLeftOption: UInt64 = 0x00000020
    private let deviceRightOption: UInt64 = 0x00000040
    private let deviceLeftControl: UInt64 = 0x00000001
    private let deviceRightControl: UInt64 = 0x00002000
    private let deviceLeftShift: UInt64 = 0x00000002
    private let deviceRightShift: UInt64 = 0x00000004

    private lazy var rightModifiers: Set<CGKeyCode> = [
        rightCommand, rightOption, rightControl, rightShift
    ]

    private lazy var leftModifiers: Set<CGKeyCode> = [
        leftCommand, leftOption, leftControl, leftShift
    ]

    func isRightModifier(_ keyCode: CGKeyCode) -> Bool {
        rightModifiers.contains(keyCode)
    }

    func isLeftModifier(_ keyCode: CGKeyCode) -> Bool {
        leftModifiers.contains(keyCode)
    }

    func getModifierType(_ keyCode: CGKeyCode) -> ModifierType? {
        switch keyCode {
        case rightCommand, leftCommand:
            return .command
        case rightOption, leftOption:
            return .option
        case rightControl, leftControl:
            return .control
        case rightShift, leftShift:
            return .shift
        default:
            return nil
        }
    }

    func hasModifier(_ flags: CGEventFlags, modifier: ModifierType) -> Bool {
        let mask = flagMask(for: modifier)
        return flags.contains(mask)
    }

    func stripModifier(_ flags: CGEventFlags, modifier: ModifierType) -> CGEventFlags {
        let mask = flagMask(for: modifier)
        return CGEventFlags(rawValue: flags.rawValue & ~mask.rawValue)
    }

    func stripModifierByKeyCode(_ flags: CGEventFlags, keyCode: CGKeyCode) -> CGEventFlags {
        var rawFlags = flags.rawValue

        // Get device-specific flag and main mask for this key
        let (deviceFlag, mainMask, otherSideDeviceFlag) = deviceFlagAndMask(for: keyCode)

        guard deviceFlag != 0 else { return flags }

        // Remove the device-specific flag for this key
        rawFlags &= ~deviceFlag

        // Only remove the main mask if the other side is NOT pressed
        let otherSidePressed = (rawFlags & otherSideDeviceFlag) != 0
        if !otherSidePressed {
            rawFlags &= ~mainMask
        }

        return CGEventFlags(rawValue: rawFlags)
    }

    private func deviceFlagAndMask(for keyCode: CGKeyCode) -> (deviceFlag: UInt64, mainMask: UInt64, otherSideFlag: UInt64) {
        switch keyCode {
        case rightCommand:
            return (deviceRightCommand, CGEventFlags.maskCommand.rawValue, deviceLeftCommand)
        case leftCommand:
            return (deviceLeftCommand, CGEventFlags.maskCommand.rawValue, deviceRightCommand)
        case rightOption:
            return (deviceRightOption, CGEventFlags.maskAlternate.rawValue, deviceLeftOption)
        case leftOption:
            return (deviceLeftOption, CGEventFlags.maskAlternate.rawValue, deviceRightOption)
        case rightControl:
            return (deviceRightControl, CGEventFlags.maskControl.rawValue, deviceLeftControl)
        case leftControl:
            return (deviceLeftControl, CGEventFlags.maskControl.rawValue, deviceRightControl)
        case rightShift:
            return (deviceRightShift, CGEventFlags.maskShift.rawValue, deviceLeftShift)
        case leftShift:
            return (deviceLeftShift, CGEventFlags.maskShift.rawValue, deviceRightShift)
        default:
            return (0, 0, 0)
        }
    }

    private func flagMask(for modifier: ModifierType) -> CGEventFlags {
        switch modifier {
        case .command:
            return .maskCommand
        case .option:
            return .maskAlternate
        case .control:
            return .maskControl
        case .shift:
            return .maskShift
        }
    }
}
