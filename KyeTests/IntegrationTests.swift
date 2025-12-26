import XCTest
import CoreGraphics
@testable import Kye

/// Integration tests that simulate the full keyboard event pipeline using synthetic CGEvents.
/// These tests verify the complete flow from key input to transformed output.
final class IntegrationTests: XCTestCase {

    // MARK: - Properties

    var keyMapper: KeyMapper!
    var modifierHandler: ModifierHandler!
    var ruleEngine: RuleEngine!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        keyMapper = KeyMapper()
        modifierHandler = ModifierHandler()
        ruleEngine = RuleEngine(keyMapper: keyMapper, modifierHandler: modifierHandler)

        // Configure with default rules:
        // 1. Right Option -> Right Command (basic rule)
        // 2. Right Command + HJKL/WASD -> Arrow keys (layer rule)
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "right-alt-to-right-cmd",
                    description: "Remap Right Alt to Right Command",
                    enabled: true,
                    from: "right_option",
                    to: "right_command"
                )),
                .layer(LayerRule(
                    id: "vim-navigation",
                    description: "Vim-style navigation with Right Command",
                    enabled: true,
                    trigger: "right_command",
                    mappings: [
                        "h": "left_arrow",
                        "j": "down_arrow",
                        "k": "up_arrow",
                        "l": "right_arrow",
                        "w": "up_arrow",
                        "a": "left_arrow",
                        "s": "down_arrow",
                        "d": "right_arrow"
                    ]
                ))
            ]
        )
        ruleEngine.rules = config.rules
    }

    override func tearDown() {
        ruleEngine = nil
        modifierHandler = nil
        keyMapper = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Simulate the modifier change event (Right Option pressed)
    /// This sets up the trigger key held state as AppController would do
    private func simulateRightOptionPressed() {
        // When Right Option is pressed, AppController:
        // 1. Tracks Right Option as held
        // 2. Because of basic rule remap, also tracks Right Command as held
        // 3. Records the remapped trigger mapping
        ruleEngine.setTriggerKeyHeld(true, keyCode: CGEventTestHelper.KeyCodes.rightOption)
        ruleEngine.setTriggerKeyHeld(true, keyCode: CGEventTestHelper.KeyCodes.rightCommand)
        ruleEngine.setRemappedTrigger(
            physicalKeyCode: CGEventTestHelper.KeyCodes.rightOption,
            targetKeyCode: CGEventTestHelper.KeyCodes.rightCommand
        )
    }

    /// Simulate the modifier release event (Right Option released)
    private func simulateRightOptionReleased() {
        ruleEngine.setTriggerKeyHeld(false, keyCode: CGEventTestHelper.KeyCodes.rightOption)
        ruleEngine.setTriggerKeyHeld(false, keyCode: CGEventTestHelper.KeyCodes.rightCommand)
    }

    // MARK: - Scenario 1: Basic Remap

    func testScenario1_BasicRemap_RightOptionToRightCommand() {
        // Input: Right Option keyDown
        // Expected: Basic rule transforms Right Option (0x3D) to Right Command (0x36)

        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.rightOption,
            flags: []
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result for basic remap")
            return
        }

        XCTAssertEqual(
            keyCode,
            CGEventTestHelper.KeyCodes.rightCommand,
            "Right Option should be remapped to Right Command"
        )
    }

    // MARK: - Scenario 2: Vim Navigation Layer

    func testScenario2_VimNavigation_HToLeftArrow() {
        // Input: (Right Option held) + H keyDown
        // Expected: Left Arrow, no Option modifier

        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.h,
            flags: flags
        )

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result for layer rule")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.leftArrow, "H should become Left Arrow")
        XCTAssertFalse(
            CGEventTestHelper.hasModifier(newFlags, modifier: .maskAlternate),
            "Option modifier should be stripped"
        )
    }

    func testScenario2_VimNavigation_JToDownArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.j,
            flags: flags
        )

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.downArrow, "J should become Down Arrow")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }

    func testScenario2_VimNavigation_KToUpArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.k,
            flags: flags
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.upArrow, "K should become Up Arrow")
    }

    func testScenario2_VimNavigation_LToRightArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.l,
            flags: flags
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.rightArrow, "L should become Right Arrow")
    }

    // MARK: - Scenario 2b: WASD Navigation

    func testScenario2b_WASDNavigation_WToUpArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.w,
            flags: flags
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.upArrow, "W should become Up Arrow")
    }

    func testScenario2b_WASDNavigation_AToLeftArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.a,
            flags: flags
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.leftArrow, "A should become Left Arrow")
    }

    func testScenario2b_WASDNavigation_SToDownArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.s,
            flags: flags
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.downArrow, "S should become Down Arrow")
    }

    func testScenario2b_WASDNavigation_DToRightArrow() {
        simulateRightOptionPressed()

        let flags = CGEventTestHelper.rightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.d,
            flags: flags
        )

        guard case .transformed(let keyCode, _) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.rightArrow, "D should become Right Arrow")
    }

    // MARK: - Scenario 3: Modifier Passthrough - Shift

    func testScenario3_ShiftPassthrough_ShiftJToShiftDownArrow() {
        // Input: Shift + (Right Option held) + J keyDown
        // Expected: Shift + Down Arrow (for text selection)

        simulateRightOptionPressed()

        let flags = CGEventTestHelper.shiftPlusRightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.j,
            flags: flags
        )

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.downArrow, "J should become Down Arrow")
        XCTAssertTrue(newFlags.contains(.maskShift), "Shift should be preserved")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }

    // MARK: - Scenario 4: Modifier Passthrough - Control

    func testScenario4_ControlPassthrough_ControlHToControlLeftArrow() {
        // Input: Control + (Right Option held) + H keyDown
        // Expected: Control + Left Arrow

        simulateRightOptionPressed()

        let flags = CGEventTestHelper.controlPlusRightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.h,
            flags: flags
        )

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.leftArrow, "H should become Left Arrow")
        XCTAssertTrue(newFlags.contains(.maskControl), "Control should be preserved")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }

    // MARK: - Scenario 5: Left Option Preserved

    func testScenario5_LeftOptionPreserved_LeftOptionPlusRightOptionL() {
        // Input: Left Option + (Right Option held) + L keyDown
        // Expected: Option + Right Arrow (word navigation)

        simulateRightOptionPressed()

        let flags = CGEventTestHelper.bothOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.l,
            flags: flags
        )

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.rightArrow, "L should become Right Arrow")
        XCTAssertTrue(
            newFlags.contains(.maskAlternate),
            "Option mask should remain (Left Option still pressed)"
        )
        XCTAssertTrue(
            CGEventTestHelper.hasDeviceFlag(newFlags, deviceFlag: CGEventTestHelper.DeviceFlags.leftOption),
            "Left Option device flag should be preserved"
        )
        XCTAssertFalse(
            CGEventTestHelper.hasDeviceFlag(newFlags, deviceFlag: CGEventTestHelper.DeviceFlags.rightOption),
            "Right Option device flag should be stripped"
        )
    }

    // MARK: - Scenario 6: Multiple Modifiers

    func testScenario6_MultipleModifiers_ControlShiftK() {
        // Input: Control + Shift + (Right Option held) + K keyDown
        // Expected: Control + Shift + Up Arrow

        simulateRightOptionPressed()

        let flags = CGEventTestHelper.controlShiftPlusRightOptionFlags()
        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.k,
            flags: flags
        )

        guard case .transformed(let keyCode, let newFlags) = result else {
            XCTFail("Expected transformed result")
            return
        }

        XCTAssertEqual(keyCode, CGEventTestHelper.KeyCodes.upArrow, "K should become Up Arrow")
        XCTAssertTrue(newFlags.contains(.maskControl), "Control should be preserved")
        XCTAssertTrue(newFlags.contains(.maskShift), "Shift should be preserved")
        XCTAssertFalse(newFlags.contains(.maskAlternate), "Option should be stripped")
    }

    // MARK: - Negative Scenarios

    func testLayerNotActiveWithoutTrigger() {
        // Input: H pressed without trigger held
        // Expected: Passthrough (no transformation)

        // Don't call simulateRightOptionPressed()

        let result = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.h,
            flags: []
        )

        guard case .passthrough = result else {
            XCTFail("Expected passthrough when trigger not held")
            return
        }
    }

    func testLayerDeactivatesWhenTriggerReleased() {
        // Activate layer
        simulateRightOptionPressed()

        // Verify layer is active
        let activeResult = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.h,
            flags: CGEventTestHelper.rightOptionFlags()
        )
        guard case .transformed(_, _) = activeResult else {
            XCTFail("Layer should be active")
            return
        }

        // Release trigger
        simulateRightOptionReleased()

        // Verify layer is inactive
        let inactiveResult = ruleEngine.evaluate(
            keyCode: CGEventTestHelper.KeyCodes.h,
            flags: []
        )
        guard case .passthrough = inactiveResult else {
            XCTFail("Layer should be inactive after trigger released")
            return
        }
    }

    func testUnmappedKeyPassesThroughWithLayerActive() {
        // Input: (Right Option held) + Z (not in mappings)
        // Expected: Passthrough

        simulateRightOptionPressed()

        let zKeyCode: CGKeyCode = 0x06  // Z key
        let result = ruleEngine.evaluate(
            keyCode: zKeyCode,
            flags: CGEventTestHelper.rightOptionFlags()
        )

        guard case .passthrough = result else {
            XCTFail("Unmapped key should passthrough even with layer active")
            return
        }
    }
}
