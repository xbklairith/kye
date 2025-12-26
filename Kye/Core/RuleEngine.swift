import Foundation
import CoreGraphics

/// Result of rule evaluation
enum RuleResult: Equatable {
    /// No rule matched, event passes through unchanged
    case passthrough

    /// Rule matched, event should be transformed
    case transformed(keyCode: CGKeyCode, flags: CGEventFlags)

    /// Event should be suppressed (dropped)
    case suppressed
}

/// Protocol for rule evaluation
protocol RuleEngineProtocol {
    var rules: [Rule] { get set }

    func evaluate(keyCode: CGKeyCode, flags: CGEventFlags) -> RuleResult
    func setTriggerKeyHeld(_ held: Bool, keyCode: CGKeyCode)
}

/// Evaluates rules against incoming keyboard events
final class RuleEngine: RuleEngineProtocol {
    var rules: [Rule] = []

    private let keyMapper: KeyMapping
    private let modifierHandler: ModifierHandling

    /// Tracks which trigger keys are currently held
    private var heldTriggerKeys: Set<CGKeyCode> = []

    /// Tracks which physical keys are remapped to which target keys (for modifier stripping)
    private var remappedTriggerKeys: [CGKeyCode: CGKeyCode] = [:]  // target -> physical

    init(keyMapper: KeyMapping, modifierHandler: ModifierHandling) {
        self.keyMapper = keyMapper
        self.modifierHandler = modifierHandler
    }

    private func debugLog(_ message: String) {
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("kye_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    func evaluate(keyCode: CGKeyCode, flags: CGEventFlags) -> RuleResult {
        for rule in rules {
            switch rule {
            case .basic(let basicRule):
                if let result = evaluateBasicRule(basicRule, keyCode: keyCode, flags: flags) {
                    return result
                }
            case .layer(let layerRule):
                if let result = evaluateLayerRule(layerRule, keyCode: keyCode, flags: flags) {
                    return result
                }
            }
        }

        return .passthrough
    }

    func setTriggerKeyHeld(_ held: Bool, keyCode: CGKeyCode) {
        if held {
            heldTriggerKeys.insert(keyCode)
        } else {
            heldTriggerKeys.remove(keyCode)
            remappedTriggerKeys.removeValue(forKey: keyCode)
        }
    }

    /// Track that a physical key is being remapped to a target key
    func setRemappedTrigger(physicalKeyCode: CGKeyCode, targetKeyCode: CGKeyCode) {
        remappedTriggerKeys[targetKeyCode] = physicalKeyCode
    }

    // MARK: - Private Methods

    private func evaluateBasicRule(
        _ rule: BasicRule,
        keyCode: CGKeyCode,
        flags: CGEventFlags
    ) -> RuleResult? {
        guard rule.enabled else { return nil }

        // Get the key code for the "from" key
        guard let fromKeyCode = keyMapper.keyCode(for: rule.from) else {
            return nil
        }

        // Check if this key matches
        guard keyCode == fromKeyCode else {
            return nil
        }

        // Get the key code for the "to" key
        guard let toKeyCode = keyMapper.keyCode(for: rule.to) else {
            return nil
        }

        // Basic rule: just swap the key code, keep flags
        return .transformed(keyCode: toKeyCode, flags: flags)
    }

    private func evaluateLayerRule(
        _ rule: LayerRule,
        keyCode: CGKeyCode,
        flags: CGEventFlags
    ) -> RuleResult? {
        guard rule.enabled else { return nil }

        // Get the trigger key code
        guard let triggerKeyCode = keyMapper.keyCode(for: rule.trigger) else {
            return nil
        }

        // Check if trigger key is held
        guard heldTriggerKeys.contains(triggerKeyCode) else {
            return nil
        }

        // Find the current key name
        guard let currentKeyName = keyMapper.keyName(for: keyCode) else {
            return nil
        }

        // Check if this key has a mapping in the layer
        guard let targetKeyName = rule.mappings[currentKeyName] else {
            return nil
        }

        // Get the target key code
        guard let targetKeyCode = keyMapper.keyCode(for: targetKeyName) else {
            return nil
        }

        // Strip the trigger modifier from the flags (only the specific key, not both sides)
        var newFlags = flags

        debugLog("Layer: before strip flags=\(String(format: "0x%016llX", flags.rawValue))")

        // Strip the trigger key's modifier by specific key code
        newFlags = modifierHandler.stripModifierByKeyCode(newFlags, keyCode: triggerKeyCode)
        debugLog("Layer: after strip trigger(\(triggerKeyCode)) flags=\(String(format: "0x%016llX", newFlags.rawValue))")

        // Also strip the physical key's modifier if it was remapped
        if let physicalKeyCode = remappedTriggerKeys[triggerKeyCode] {
            newFlags = modifierHandler.stripModifierByKeyCode(newFlags, keyCode: physicalKeyCode)
            debugLog("Layer: after strip physical(\(physicalKeyCode)) flags=\(String(format: "0x%016llX", newFlags.rawValue))")
        }

        return .transformed(keyCode: targetKeyCode, flags: newFlags)
    }
}
