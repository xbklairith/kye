import Foundation

/// Main configuration structure for Kye
/// Stored at ~/.config/kye/config.json
struct Configuration: Codable, Equatable {
    /// Configuration version for migration support
    let version: String

    /// Whether key remapping is enabled
    var enabled: Bool

    /// List of remapping rules
    var rules: [Rule]

    static let `default` = Configuration(
        version: "1.0",
        enabled: true,
        rules: [
            // Right Alt → Right Command
            .basic(BasicRule(
                id: "right-alt-to-right-cmd",
                description: "Remap Right Alt to Right Command",
                enabled: true,
                from: "right_option",
                to: "right_command"
            )),
            // Right Command + HJKL → Arrow Keys (Vim navigation layer)
            .layer(LayerRule(
                id: "vim-navigation",
                description: "Vim-style navigation with Right Command",
                enabled: true,
                trigger: "right_command",
                mappings: [
                    "h": "left_arrow",
                    "j": "down_arrow",
                    "k": "up_arrow",
                    "l": "right_arrow"
                ]
            ))
        ]
    )
}
