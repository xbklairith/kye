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
        rules: []
    )
}
