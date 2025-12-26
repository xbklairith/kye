import XCTest
import CoreGraphics
@testable import Kye

final class RuleEngineTests: XCTestCase {

    var ruleEngine: RuleEngine!
    var keyMapper: KeyMapper!
    var modifierHandler: ModifierHandler!

    override func setUp() {
        super.setUp()
        keyMapper = KeyMapper()
        modifierHandler = ModifierHandler()
        ruleEngine = RuleEngine(keyMapper: keyMapper, modifierHandler: modifierHandler)
    }

    override func tearDown() {
        ruleEngine = nil
        keyMapper = nil
        modifierHandler = nil
        super.tearDown()
    }

    // MARK: - Basic Rule Tests (Task 6)

    func testBasicRuleMatchesFromKeyReturnsToKey() {
        // Basic rule: right_alt -> right_command
        let rule = Rule.basic(BasicRule(
            id: "rule-001",
            description: "Right Alt to Right Cmd",
            enabled: true,
            from: "right_alt",
            to: "right_command"
        ))
        ruleEngine.rules = [rule]

        // Simulate pressing Right Alt (0x3D)
        let result = ruleEngine.evaluate(keyCode: 0x3D, flags: CGEventFlags([]))

        guard case .transformed(let newKeyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(newKeyCode, 0x36, "Should transform to Right Command")
    }

    func testNoMatchingRuleReturnsPassthrough() {
        // No rules configured
        ruleEngine.rules = []

        // Simulate pressing H key (0x04)
        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags([]))

        guard case .passthrough = result else {
            XCTFail("Expected passthrough result")
            return
        }
    }

    func testDisabledRuleIsSkipped() {
        // Disabled basic rule
        let rule = Rule.basic(BasicRule(
            id: "rule-001",
            description: "Right Alt to Right Cmd",
            enabled: false,  // Disabled
            from: "right_alt",
            to: "right_command"
        ))
        ruleEngine.rules = [rule]

        // Simulate pressing Right Alt (0x3D)
        let result = ruleEngine.evaluate(keyCode: 0x3D, flags: CGEventFlags([]))

        guard case .passthrough = result else {
            XCTFail("Expected passthrough because rule is disabled")
            return
        }
    }

    func testUnmatchedKeyPassesThrough() {
        // Rule for right_alt -> right_command
        let rule = Rule.basic(BasicRule(
            id: "rule-001",
            description: nil,
            enabled: true,
            from: "right_alt",
            to: "right_command"
        ))
        ruleEngine.rules = [rule]

        // Press H key (0x04) - should pass through
        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags([]))

        guard case .passthrough = result else {
            XCTFail("Expected passthrough for unmatched key")
            return
        }
    }

    // MARK: - Layer Rule Tests (Task 7)

    func testLayerRuleTriggersWhenTriggerModifierHeld() {
        // Layer rule: right_command + h -> left_arrow
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: "Vim Navigation",
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)  // Right Cmd held

        // Press H with Right Cmd held
        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags.maskCommand)

        guard case .transformed(let newKeyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(newKeyCode, 0x7B, "Should transform H to Left Arrow")
    }

    func testLayerRuleMapsHToLeftArrow() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow", "j": "down_arrow", "k": "up_arrow", "l": "right_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags.maskCommand)

        guard case .transformed(let newKeyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(newKeyCode, 0x7B) // Left Arrow
    }

    func testLayerRuleMapsJToDownArrow() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow", "j": "down_arrow", "k": "up_arrow", "l": "right_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        let result = ruleEngine.evaluate(keyCode: 0x26, flags: CGEventFlags.maskCommand)  // J key

        guard case .transformed(let newKeyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(newKeyCode, 0x7D) // Down Arrow
    }

    func testLayerRuleMapsKToUpArrow() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow", "j": "down_arrow", "k": "up_arrow", "l": "right_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        let result = ruleEngine.evaluate(keyCode: 0x28, flags: CGEventFlags.maskCommand)  // K key

        guard case .transformed(let newKeyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(newKeyCode, 0x7E) // Up Arrow
    }

    func testLayerRuleMapsLToRightArrow() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow", "j": "down_arrow", "k": "up_arrow", "l": "right_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        let result = ruleEngine.evaluate(keyCode: 0x25, flags: CGEventFlags.maskCommand)  // L key

        guard case .transformed(let newKeyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(newKeyCode, 0x7C) // Right Arrow
    }

    func testLayerRuleStripsTriggerModifierFromOutput() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        // Press H with only Command held
        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags.maskCommand)

        guard case .transformed(_, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertFalse(newFlags.contains(.maskCommand), "Command should be stripped")
    }

    func testLayerRulePreservesOtherModifiers() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        // Press H with Command + Shift held
        let result = ruleEngine.evaluate(
            keyCode: 0x04,
            flags: CGEventFlags([.maskCommand, .maskShift])
        )

        guard case .transformed(_, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertFalse(newFlags.contains(.maskCommand), "Command should be stripped")
        XCTAssertTrue(newFlags.contains(.maskShift), "Shift should be preserved")
    }

    // MARK: - Full Modifier Passthrough Tests (Task 8)

    func testRightCmdCtrlJBecomesCtrlDownArrow() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["j": "down_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        // Press J with Command + Control held
        let result = ruleEngine.evaluate(
            keyCode: 0x26,
            flags: CGEventFlags([.maskCommand, .maskControl])
        )

        guard case .transformed(let keyCode, let flags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7D, "Should be Down Arrow")
        XCTAssertFalse(flags.contains(.maskCommand), "Command should be stripped")
        XCTAssertTrue(flags.contains(.maskControl), "Control should be preserved")
    }

    func testRightCmdOptionShiftHBecomesOptionShiftLeftArrow() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)

        // Press H with Command + Option + Shift held
        let result = ruleEngine.evaluate(
            keyCode: 0x04,
            flags: CGEventFlags([.maskCommand, .maskAlternate, .maskShift])
        )

        guard case .transformed(let keyCode, let flags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7B, "Should be Left Arrow")
        XCTAssertFalse(flags.contains(.maskCommand), "Command should be stripped")
        XCTAssertTrue(flags.contains(.maskAlternate), "Option should be preserved")
        XCTAssertTrue(flags.contains(.maskShift), "Shift should be preserved")
    }

    func testLeftCmdHPassesThroughUnchanged() {
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",  // Only Right Cmd triggers
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        // Left Command is held (not Right Command)
        ruleEngine.setTriggerKeyHeld(false, keyCode: 0x36)  // Right Cmd not held

        // Press H with Left Command
        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags.maskCommand)

        guard case .passthrough = result else {
            XCTFail("Expected passthrough when Left Cmd used instead of Right Cmd")
            return
        }
    }

    // MARK: - Trigger Key Tracking Tests

    func testTriggerKeyDownSetsHeldState() {
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)  // Right Cmd

        // Layer rule should activate
        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags.maskCommand)

        guard case .transformed(_, _) = result else {
            XCTFail("Layer should be active when trigger key is held")
            return
        }
    }

    func testTriggerKeyUpClearsHeldState() {
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)
        ruleEngine.setTriggerKeyHeld(false, keyCode: 0x36)  // Released

        let rule = Rule.layer(LayerRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        // H without trigger held should passthrough
        let result = ruleEngine.evaluate(keyCode: 0x04, flags: CGEventFlags([]))

        guard case .passthrough = result else {
            XCTFail("Layer should be inactive after trigger released")
            return
        }
    }

    // MARK: - Rule Priority Tests

    func testRulesEvaluatedInOrder() {
        // First rule matches
        let rule1 = Rule.basic(BasicRule(
            id: "rule-001",
            description: nil,
            enabled: true,
            from: "a",
            to: "b"
        ))
        // Second rule also would match but shouldn't be reached
        let rule2 = Rule.basic(BasicRule(
            id: "rule-002",
            description: nil,
            enabled: true,
            from: "a",
            to: "c"
        ))
        ruleEngine.rules = [rule1, rule2]

        let result = ruleEngine.evaluate(keyCode: 0x00, flags: CGEventFlags([]))  // A key

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x0B, "Should match first rule (a -> b)")
    }

    // MARK: - Protocol Conformance Test

    func testConformsToRuleEngineProtocol() {
        let engine: any RuleEngineProtocol = ruleEngine
        XCTAssertNotNil(engine)
    }

    // MARK: - Remapped Trigger Tests (Right Option -> Right Command layer)

    func testRemappedTriggerStripsPhysicalModifier() {
        // Scenario: Right Option remapped to Right Command, layer triggered by Right Command
        // User presses: Right Option + H
        // Expected: Left Arrow (no Option modifier)
        let rule = Rule.layer(LayerRule(
            id: "vim-nav",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        // Simulate Right Option held (remapped to Right Command)
        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)  // Right Command (virtual)
        ruleEngine.setRemappedTrigger(physicalKeyCode: 0x3D, targetKeyCode: 0x36)  // Right Option -> Right Command

        // Flags contain Option (physical key) but layer triggers on Command
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | deviceRightOption)

        let result = ruleEngine.evaluate(keyCode: 0x04, flags: flags)  // H key

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7B, "Should be Left Arrow")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped (physical trigger key)")
    }

    func testRemappedTriggerPreservesLeftOption() {
        // Scenario: Right Option + Left Option + H
        // Expected: Option + Left Arrow (Left Option preserved)
        let rule = Rule.layer(LayerRule(
            id: "vim-nav",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)
        ruleEngine.setRemappedTrigger(physicalKeyCode: 0x3D, targetKeyCode: 0x36)

        // Both Left and Right Option pressed
        let deviceLeftOption: UInt64 = 0x00000020
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | deviceLeftOption | deviceRightOption)

        let result = ruleEngine.evaluate(keyCode: 0x04, flags: flags)

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7B, "Should be Left Arrow")
        XCTAssertTrue(newFlags.contains(.maskAlternate), "Option mask should remain (Left Option still pressed)")
        XCTAssertTrue(newFlags.rawValue & deviceLeftOption != 0, "Left Option device flag should be preserved")
    }

    func testRemappedTriggerPreservesControl() {
        // Scenario: Control + Right Option + H
        // Expected: Control + Left Arrow
        let rule = Rule.layer(LayerRule(
            id: "vim-nav",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)
        ruleEngine.setRemappedTrigger(physicalKeyCode: 0x3D, targetKeyCode: 0x36)

        // Control + Right Option
        let deviceLeftControl: UInt64 = 0x00000001
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue | deviceLeftControl | deviceRightOption)

        let result = ruleEngine.evaluate(keyCode: 0x04, flags: flags)

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7B, "Should be Left Arrow")
        XCTAssertTrue(newFlags.contains(.maskControl), "Control should be preserved")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }

    func testRemappedTriggerPreservesShift() {
        // Scenario: Shift + Right Option + J
        // Expected: Shift + Down Arrow (for text selection)
        let rule = Rule.layer(LayerRule(
            id: "vim-nav",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["j": "down_arrow"]
        ))
        ruleEngine.rules = [rule]

        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)
        ruleEngine.setRemappedTrigger(physicalKeyCode: 0x3D, targetKeyCode: 0x36)

        // Shift + Right Option
        let deviceLeftShift: UInt64 = 0x00000002
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | CGEventFlags.maskAlternate.rawValue | deviceLeftShift | deviceRightOption)

        let result = ruleEngine.evaluate(keyCode: 0x26, flags: flags)  // J key

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7D, "Should be Down Arrow")
        XCTAssertTrue(newFlags.contains(.maskShift), "Shift should be preserved")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }

    func testRemappedTriggerPreservesMultipleModifiers() {
        // Scenario: Control + Shift + Right Option + H
        // Expected: Control + Shift + Left Arrow
        let rule = Rule.layer(LayerRule(
            id: "vim-nav",
            description: nil,
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        ))
        ruleEngine.rules = [rule]

        ruleEngine.setTriggerKeyHeld(true, keyCode: 0x36)
        ruleEngine.setRemappedTrigger(physicalKeyCode: 0x3D, targetKeyCode: 0x36)

        // Control + Shift + Right Option
        let deviceLeftControl: UInt64 = 0x00000001
        let deviceLeftShift: UInt64 = 0x00000002
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue:
            CGEventFlags.maskControl.rawValue |
            CGEventFlags.maskShift.rawValue |
            CGEventFlags.maskAlternate.rawValue |
            deviceLeftControl | deviceLeftShift | deviceRightOption
        )

        let result = ruleEngine.evaluate(keyCode: 0x04, flags: flags)

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, 0x7B, "Should be Left Arrow")
        XCTAssertTrue(newFlags.contains(.maskControl), "Control should be preserved")
        XCTAssertTrue(newFlags.contains(.maskShift), "Shift should be preserved")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }
}
