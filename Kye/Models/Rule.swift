import Foundation

/// Represents a remapping rule with type discrimination
enum Rule: Codable, Equatable {
    case basic(BasicRule)
    case layer(LayerRule)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum RuleType: String, Codable {
        case basic
        case layer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RuleType.self, forKey: .type)

        switch type {
        case .basic:
            let basicRule = try BasicRule(from: decoder)
            self = .basic(basicRule)
        case .layer:
            let layerRule = try LayerRule(from: decoder)
            self = .layer(layerRule)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .basic(let basicRule):
            try container.encode(RuleType.basic, forKey: .type)
            try basicRule.encode(to: encoder)
        case .layer(let layerRule):
            try container.encode(RuleType.layer, forKey: .type)
            try layerRule.encode(to: encoder)
        }
    }
}

/// Basic key remapping rule (one key to another)
/// Example: Right Alt → Right Command
struct BasicRule: Codable, Equatable {
    /// Unique identifier for this rule
    let id: String

    /// Human-readable description
    let description: String?

    /// Whether this rule is active
    let enabled: Bool

    /// Source key name (e.g., "right_alt")
    let from: String

    /// Target key name (e.g., "right_command")
    let to: String

    private enum CodingKeys: String, CodingKey {
        case id, description, enabled, from, to
    }

    init(id: String, description: String?, enabled: Bool, from: String, to: String) {
        self.id = id
        self.description = description
        self.enabled = enabled
        self.from = from
        self.to = to
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
    }
}

/// Layer-based key remapping rule (modifier + key → different key)
/// Example: Right Command + H → Left Arrow
struct LayerRule: Codable, Equatable {
    /// Unique identifier for this rule
    let id: String

    /// Human-readable description
    let description: String?

    /// Whether this rule is active
    let enabled: Bool

    /// Trigger modifier key (e.g., "right_command")
    let trigger: String

    /// Key mappings when trigger is held (e.g., {"h": "left_arrow"})
    let mappings: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id, description, enabled, trigger, mappings
    }

    init(id: String, description: String?, enabled: Bool, trigger: String, mappings: [String: String]) {
        self.id = id
        self.description = description
        self.enabled = enabled
        self.trigger = trigger
        self.mappings = mappings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        trigger = try container.decode(String.self, forKey: .trigger)
        mappings = try container.decode([String: String].self, forKey: .mappings)
    }
}

/// Discriminates the two rule variants for grouping/display in the UI.
enum RuleKind {
    case basic
    case layer
}

extension Rule: Identifiable {
    /// Stable identity sourced from the underlying rule's `id` (used by SwiftUI `ForEach`).
    var id: String {
        switch self {
        case .basic(let rule): return rule.id
        case .layer(let rule): return rule.id
        }
    }

    /// Which variant this rule is.
    var kind: RuleKind {
        switch self {
        case .basic: return .basic
        case .layer: return .layer
        }
    }

    /// Returns a copy of the rule with its `enabled` flag set, preserving all other fields.
    func withEnabled(_ enabled: Bool) -> Rule {
        switch self {
        case .basic(let rule):
            return .basic(BasicRule(id: rule.id, description: rule.description, enabled: enabled, from: rule.from, to: rule.to))
        case .layer(let rule):
            return .layer(LayerRule(id: rule.id, description: rule.description, enabled: enabled, trigger: rule.trigger, mappings: rule.mappings))
        }
    }
}
