import Foundation

/// Maps `KeyMapper` key names to display glyphs and human-readable labels
/// for presentation in the rules UI.
enum KeySymbol {

    /// Keys that have a dedicated macOS glyph. Everything else falls back to
    /// an uppercased form of the name.
    private static let glyphs: [String: String] = [
        // Modifiers
        "left_command": "⌘", "right_command": "⌘", "command": "⌘",
        "left_option": "⌥", "right_option": "⌥",
        "left_alt": "⌥", "right_alt": "⌥", "option": "⌥",
        "left_control": "⌃", "right_control": "⌃", "control": "⌃",
        "left_shift": "⇧", "right_shift": "⇧", "shift": "⇧",
        "caps_lock": "⇪",
        // Arrows
        "left_arrow": "←", "right_arrow": "→", "up_arrow": "↑", "down_arrow": "↓",
        // Specials
        "return": "⏎", "enter": "⏎",
        "delete": "⌫", "backspace": "⌫", "forward_delete": "⌦",
        "escape": "⎋", "esc": "⎋",
        "tab": "⇥",
        "space": "␣",
        "home": "↖", "end": "↘", "page_up": "⇞", "page_down": "⇟",
    ]

    /// A short glyph or cap label for a key name (e.g. "right_command" → "⌘", "h" → "H").
    static func glyph(for name: String) -> String {
        let key = name.lowercased()
        return glyphs[key] ?? key.uppercased()
    }

    /// A human-readable label for a key name (e.g. "right_command" → "Right Command").
    static func label(for name: String) -> String {
        let key = name.lowercased()
        return key
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Whether the name is a key `KeyMapper` understands.
    static func isKnown(_ name: String, keyMapper: KeyMapping = KeyMapper()) -> Bool {
        keyMapper.keyCode(for: name) != nil
    }
}
