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
}
