import Foundation
import CoreGraphics

/// Protocol for translating between key names and CGKeyCode values
protocol KeyMapping {
    /// Get the key code for a key name
    /// - Parameter name: Key name (e.g., "h", "left_arrow", "right_command")
    /// - Returns: CGKeyCode if valid, nil otherwise
    func keyCode(for name: String) -> CGKeyCode?

    /// Get the key name for a key code
    /// - Parameter code: CGKeyCode value
    /// - Returns: Key name if valid, nil otherwise
    func keyName(for code: CGKeyCode) -> String?
}

/// Translates between key names and CGKeyCode values
final class KeyMapper: KeyMapping {

    private let nameToCode: [String: CGKeyCode] = [
        // Letters (QWERTY layout)
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
        "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
        "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
        "y": 0x10, "t": 0x11, "o": 0x1F, "u": 0x20, "i": 0x22,
        "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D,
        "m": 0x2E,

        // Numbers
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,

        // Modifiers - Left
        "left_shift": 0x38,
        "left_control": 0x3B,
        "left_option": 0x3A,
        "left_alt": 0x3A,  // Alias
        "left_command": 0x37,

        // Modifiers - Right
        "right_shift": 0x3C,
        "right_control": 0x3E,
        "right_option": 0x3D,
        "right_alt": 0x3D,  // Alias
        "right_command": 0x36,

        // Arrow keys
        "left_arrow": 0x7B,
        "right_arrow": 0x7C,
        "down_arrow": 0x7D,
        "up_arrow": 0x7E,

        // Special keys
        "return": 0x24,
        "enter": 0x24,
        "tab": 0x30,
        "space": 0x31,
        "delete": 0x33,
        "backspace": 0x33,
        "escape": 0x35,
        "esc": 0x35,

        // Function keys
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,

        // Other
        "caps_lock": 0x39,
        "home": 0x73,
        "page_up": 0x74,
        "forward_delete": 0x75,
        "end": 0x77,
        "page_down": 0x79,

        // Punctuation
        "minus": 0x1B,
        "equal": 0x18,
        "left_bracket": 0x21,
        "right_bracket": 0x1E,
        "backslash": 0x2A,
        "semicolon": 0x29,
        "quote": 0x27,
        "grave": 0x32,
        "comma": 0x2B,
        "period": 0x2F,
        "slash": 0x2C,
    ]

    private lazy var codeToName: [CGKeyCode: String] = {
        // Build reverse mapping, preferring primary names over aliases
        var result: [CGKeyCode: String] = [:]

        // First pass: add all mappings
        for (name, code) in nameToCode {
            // Skip aliases in reverse mapping
            let isAlias = ["left_alt", "right_alt", "enter", "esc", "backspace"].contains(name)
            if !isAlias || result[code] == nil {
                result[code] = name
            }
        }

        return result
    }()

    func keyCode(for name: String) -> CGKeyCode? {
        nameToCode[name.lowercased()]
    }

    func keyName(for code: CGKeyCode) -> String? {
        codeToName[code]
    }
}
