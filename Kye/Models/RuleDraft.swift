import Foundation

/// Editable, view-facing representation of a `Rule`. Keeps the editor's in-flight state as
/// plain strings so SwiftUI can bind to it, and converts back to a validated `Rule` on save.
///
/// Layer rules are modelled with a single `trigger + (mappingFrom → mappingTo)` pair — the
/// common case. Multi-mapping layer rules remain editable via the JSON config for now.
struct RuleDraft: Equatable {
    var kind: RuleKind
    var id: String
    var description: String
    var enabled: Bool

    // Basic
    var from: String
    var to: String

    // Layer (single mapping)
    var trigger: String
    var mappingFrom: String
    var mappingTo: String

    /// A blank draft for a new rule of `kind`, seeded with a caller-supplied unique `id`.
    static func empty(kind: RuleKind, id: String) -> RuleDraft {
        RuleDraft(kind: kind, id: id, description: "", enabled: true,
                  from: "", to: "", trigger: "", mappingFrom: "", mappingTo: "")
    }

    /// Whether a rule can round-trip losslessly through this single-mapping editor. Layer rules
    /// with more than one mapping would be truncated on save, so they stay JSON-only for now.
    static func isInlineEditable(_ rule: Rule) -> Bool {
        switch rule {
        case .basic:
            return true
        case .layer(let r):
            return r.mappings.count <= 1
        }
    }

    /// Builds a draft from an existing rule for editing.
    static func make(from rule: Rule) -> RuleDraft {
        switch rule {
        case .basic(let r):
            return RuleDraft(kind: .basic, id: r.id, description: r.description ?? "", enabled: r.enabled,
                             from: r.from, to: r.to, trigger: "", mappingFrom: "", mappingTo: "")
        case .layer(let r):
            let first = r.mappings.first
            return RuleDraft(kind: .layer, id: r.id, description: r.description ?? "", enabled: r.enabled,
                             from: "", to: "", trigger: r.trigger,
                             mappingFrom: first?.key ?? "", mappingTo: first?.value ?? "")
        }
    }

    /// Converts to a `Rule`, or `nil` when required fields are blank. All fields are trimmed;
    /// an empty description becomes `nil`.
    func toRule() -> Rule? {
        let trimmedId = id.trimmed
        guard !trimmedId.isEmpty else { return nil }
        let normalizedDescription = description.trimmed.isEmpty ? nil : description.trimmed

        switch kind {
        case .basic:
            let source = from.trimmed
            let target = to.trimmed
            guard !source.isEmpty, !target.isEmpty else { return nil }
            return .basic(BasicRule(id: trimmedId, description: normalizedDescription,
                                    enabled: enabled, from: source, to: target))
        case .layer:
            let trig = trigger.trimmed
            let mapFrom = mappingFrom.trimmed
            let mapTo = mappingTo.trimmed
            guard !trig.isEmpty, !mapFrom.isEmpty, !mapTo.isEmpty else { return nil }
            return .layer(LayerRule(id: trimmedId, description: normalizedDescription,
                                    enabled: enabled, trigger: trig, mappings: [mapFrom: mapTo]))
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
