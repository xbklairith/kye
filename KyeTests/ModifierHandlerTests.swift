import XCTest
import CoreGraphics
@testable import Kye

final class ModifierHandlerTests: XCTestCase {

    var modifierHandler: ModifierHandler!

    override func setUp() {
        super.setUp()
        modifierHandler = ModifierHandler()
    }

    override func tearDown() {
        modifierHandler = nil
        super.tearDown()
    }

    // MARK: - Right Modifier Detection Tests

    func testIsRightModifierForRightCommand() {
        // Right Command key code is 0x36
        XCTAssertTrue(modifierHandler.isRightModifier(0x36))
    }

    func testIsRightModifierForLeftCommandReturnsFalse() {
        // Left Command key code is 0x37
        XCTAssertFalse(modifierHandler.isRightModifier(0x37))
    }

    func testIsRightModifierForRightOption() {
        // Right Option key code is 0x3D
        XCTAssertTrue(modifierHandler.isRightModifier(0x3D))
    }

    func testIsRightModifierForRightControl() {
        // Right Control key code is 0x3E
        XCTAssertTrue(modifierHandler.isRightModifier(0x3E))
    }

    func testIsRightModifierForRightShift() {
        // Right Shift key code is 0x3C
        XCTAssertTrue(modifierHandler.isRightModifier(0x3C))
    }

    func testIsRightModifierForNonModifierKey() {
        // H key code is 0x04
        XCTAssertFalse(modifierHandler.isRightModifier(0x04))
    }

    // MARK: - Left Modifier Detection Tests

    func testIsLeftModifierForLeftCommand() {
        // Left Command key code is 0x37
        XCTAssertTrue(modifierHandler.isLeftModifier(0x37))
    }

    func testIsLeftModifierForRightCommandReturnsFalse() {
        // Right Command key code is 0x36
        XCTAssertFalse(modifierHandler.isLeftModifier(0x36))
    }

    func testIsLeftModifierForLeftOption() {
        // Left Option key code is 0x3A
        XCTAssertTrue(modifierHandler.isLeftModifier(0x3A))
    }

    func testIsLeftModifierForLeftControl() {
        // Left Control key code is 0x3B
        XCTAssertTrue(modifierHandler.isLeftModifier(0x3B))
    }

    func testIsLeftModifierForLeftShift() {
        // Left Shift key code is 0x38
        XCTAssertTrue(modifierHandler.isLeftModifier(0x38))
    }

    // MARK: - Modifier Type Detection Tests

    func testGetModifierTypeForRightCommand() {
        XCTAssertEqual(modifierHandler.getModifierType(0x36), .command)
    }

    func testGetModifierTypeForLeftCommand() {
        XCTAssertEqual(modifierHandler.getModifierType(0x37), .command)
    }

    func testGetModifierTypeForRightOption() {
        XCTAssertEqual(modifierHandler.getModifierType(0x3D), .option)
    }

    func testGetModifierTypeForLeftOption() {
        XCTAssertEqual(modifierHandler.getModifierType(0x3A), .option)
    }

    func testGetModifierTypeForRightControl() {
        XCTAssertEqual(modifierHandler.getModifierType(0x3E), .control)
    }

    func testGetModifierTypeForLeftControl() {
        XCTAssertEqual(modifierHandler.getModifierType(0x3B), .control)
    }

    func testGetModifierTypeForRightShift() {
        XCTAssertEqual(modifierHandler.getModifierType(0x3C), .shift)
    }

    func testGetModifierTypeForLeftShift() {
        XCTAssertEqual(modifierHandler.getModifierType(0x38), .shift)
    }

    func testGetModifierTypeForHKeyReturnsNil() {
        // H key is not a modifier
        XCTAssertNil(modifierHandler.getModifierType(0x04))
    }

    func testGetModifierTypeForArrowKeyReturnsNil() {
        // Left arrow key is not a modifier
        XCTAssertNil(modifierHandler.getModifierType(0x7B))
    }

    // MARK: - Has Modifier Tests

    func testHasModifierWithCommandFlag() {
        let flags = CGEventFlags.maskCommand
        XCTAssertTrue(modifierHandler.hasModifier(flags, modifier: .command))
    }

    func testHasModifierWithShiftFlag() {
        let flags = CGEventFlags.maskShift
        XCTAssertTrue(modifierHandler.hasModifier(flags, modifier: .shift))
    }

    func testHasModifierWithControlFlag() {
        let flags = CGEventFlags.maskControl
        XCTAssertTrue(modifierHandler.hasModifier(flags, modifier: .control))
    }

    func testHasModifierWithOptionFlag() {
        let flags = CGEventFlags.maskAlternate
        XCTAssertTrue(modifierHandler.hasModifier(flags, modifier: .option))
    }

    func testHasModifierReturnsFalseWhenNotPresent() {
        let flags = CGEventFlags.maskShift
        XCTAssertFalse(modifierHandler.hasModifier(flags, modifier: .command))
    }

    func testHasModifierWithMultipleFlags() {
        let flags = CGEventFlags([.maskCommand, .maskShift])
        XCTAssertTrue(modifierHandler.hasModifier(flags, modifier: .command))
        XCTAssertTrue(modifierHandler.hasModifier(flags, modifier: .shift))
        XCTAssertFalse(modifierHandler.hasModifier(flags, modifier: .option))
    }

    // MARK: - Strip Modifier Tests

    func testStripModifierRemovesCommandFlag() {
        let flags = CGEventFlags.maskCommand
        let result = modifierHandler.stripModifier(flags, modifier: .command)

        // After stripping command, the command flag should not be present
        XCTAssertFalse(result.contains(.maskCommand))
    }

    func testStripModifierPreservesOtherFlags() {
        let flags = CGEventFlags([.maskCommand, .maskShift])
        let result = modifierHandler.stripModifier(flags, modifier: .command)

        // After stripping command, shift should still be present
        XCTAssertFalse(result.contains(.maskCommand))
        XCTAssertTrue(result.contains(.maskShift))
    }

    func testStripShiftFromCommandShift() {
        let flags = CGEventFlags([.maskCommand, .maskShift])
        let result = modifierHandler.stripModifier(flags, modifier: .shift)

        XCTAssertTrue(result.contains(.maskCommand))
        XCTAssertFalse(result.contains(.maskShift))
    }

    func testStripCommandPreservesOptionAndShift() {
        let flags = CGEventFlags([.maskCommand, .maskShift, .maskAlternate])
        let result = modifierHandler.stripModifier(flags, modifier: .command)

        XCTAssertFalse(result.contains(.maskCommand))
        XCTAssertTrue(result.contains(.maskShift))
        XCTAssertTrue(result.contains(.maskAlternate))
    }

    func testStripModifierFromEmptyFlags() {
        let flags = CGEventFlags([])
        let result = modifierHandler.stripModifier(flags, modifier: .command)

        // Should return empty flags without crashing
        XCTAssertFalse(result.contains(.maskCommand))
    }

    func testStripAllModifiers() {
        var flags = CGEventFlags([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        flags = modifierHandler.stripModifier(flags, modifier: .command)
        flags = modifierHandler.stripModifier(flags, modifier: .shift)
        flags = modifierHandler.stripModifier(flags, modifier: .option)
        flags = modifierHandler.stripModifier(flags, modifier: .control)

        XCTAssertFalse(flags.contains(.maskCommand))
        XCTAssertFalse(flags.contains(.maskShift))
        XCTAssertFalse(flags.contains(.maskAlternate))
        XCTAssertFalse(flags.contains(.maskControl))
    }

    // MARK: - Complex Passthrough Scenarios

    func testPassthroughScenario_RightCmdShiftH() {
        // When Right Cmd + Shift + H is pressed, we want to strip Command but keep Shift
        let originalFlags = CGEventFlags([.maskCommand, .maskShift])
        let result = modifierHandler.stripModifier(originalFlags, modifier: .command)

        XCTAssertFalse(result.contains(.maskCommand), "Command should be stripped")
        XCTAssertTrue(result.contains(.maskShift), "Shift should be preserved")
    }

    func testPassthroughScenario_RightCmdCtrlOptionH() {
        // When Right Cmd + Ctrl + Option + H is pressed
        let originalFlags = CGEventFlags([.maskCommand, .maskControl, .maskAlternate])
        let result = modifierHandler.stripModifier(originalFlags, modifier: .command)

        XCTAssertFalse(result.contains(.maskCommand), "Command should be stripped")
        XCTAssertTrue(result.contains(.maskControl), "Control should be preserved")
        XCTAssertTrue(result.contains(.maskAlternate), "Option should be preserved")
    }

    // MARK: - Protocol Conformance Test

    func testConformsToModifierHandlingProtocol() {
        let handler: any ModifierHandling = modifierHandler
        XCTAssertTrue(handler.isRightModifier(0x36))
        XCTAssertNotNil(handler.getModifierType(0x36))
    }

    // MARK: - Strip Modifier By Key Code Tests (Left/Right preservation)

    func testStripRightOptionPreservesLeftOption() {
        // Both Left Option (device flag 0x20) and Right Option (device flag 0x40) pressed
        // Plus the main maskAlternate flag
        let deviceLeftOption: UInt64 = 0x00000020
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | deviceLeftOption | deviceRightOption)

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x3D)  // Right Option

        // Left Option device flag should remain, main mask should remain (left is still pressed)
        XCTAssertTrue(result.rawValue & deviceLeftOption != 0, "Left Option device flag should be preserved")
        XCTAssertTrue(result.contains(.maskAlternate), "maskAlternate should remain because Left Option is pressed")
        XCTAssertFalse(result.rawValue & deviceRightOption != 0, "Right Option device flag should be stripped")
    }

    func testStripRightOptionRemovesMaskWhenLeftNotPressed() {
        // Only Right Option pressed
        let deviceRightOption: UInt64 = 0x00000040
        let flags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | deviceRightOption)

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x3D)  // Right Option

        XCTAssertFalse(result.contains(.maskAlternate), "maskAlternate should be removed when only Right Option was pressed")
        XCTAssertFalse(result.rawValue & deviceRightOption != 0, "Right Option device flag should be stripped")
    }

    func testStripRightCommandPreservesLeftCommand() {
        let deviceLeftCommand: UInt64 = 0x00000008
        let deviceRightCommand: UInt64 = 0x00000010
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | deviceLeftCommand | deviceRightCommand)

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x36)  // Right Command

        XCTAssertTrue(result.rawValue & deviceLeftCommand != 0, "Left Command device flag should be preserved")
        XCTAssertTrue(result.contains(.maskCommand), "maskCommand should remain because Left Command is pressed")
        XCTAssertFalse(result.rawValue & deviceRightCommand != 0, "Right Command device flag should be stripped")
    }

    func testStripRightControlPreservesLeftControl() {
        let deviceLeftControl: UInt64 = 0x00000001
        let deviceRightControl: UInt64 = 0x00002000
        let flags = CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | deviceLeftControl | deviceRightControl)

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x3E)  // Right Control

        XCTAssertTrue(result.rawValue & deviceLeftControl != 0, "Left Control device flag should be preserved")
        XCTAssertTrue(result.contains(.maskControl), "maskControl should remain because Left Control is pressed")
        XCTAssertFalse(result.rawValue & deviceRightControl != 0, "Right Control device flag should be stripped")
    }

    func testStripRightShiftPreservesLeftShift() {
        let deviceLeftShift: UInt64 = 0x00000002
        let deviceRightShift: UInt64 = 0x00000004
        let flags = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | deviceLeftShift | deviceRightShift)

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x3C)  // Right Shift

        XCTAssertTrue(result.rawValue & deviceLeftShift != 0, "Left Shift device flag should be preserved")
        XCTAssertTrue(result.contains(.maskShift), "maskShift should remain because Left Shift is pressed")
        XCTAssertFalse(result.rawValue & deviceRightShift != 0, "Right Shift device flag should be stripped")
    }

    func testStripModifierByKeyCodePreservesUnrelatedModifiers() {
        // Right Option + Left Control pressed
        let deviceRightOption: UInt64 = 0x00000040
        let deviceLeftControl: UInt64 = 0x00000001
        let flags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue | deviceRightOption | deviceLeftControl)

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x3D)  // Strip Right Option

        // Control should be completely untouched
        XCTAssertTrue(result.contains(.maskControl), "Control mask should be preserved")
        XCTAssertTrue(result.rawValue & deviceLeftControl != 0, "Left Control device flag should be preserved")
        // Option should be stripped
        XCTAssertFalse(result.contains(.maskAlternate), "Option mask should be stripped")
    }

    func testStripNonModifierKeyCodeReturnsUnchangedFlags() {
        let flags = CGEventFlags([.maskCommand, .maskShift])

        let result = modifierHandler.stripModifierByKeyCode(flags, keyCode: 0x04)  // H key (not a modifier)

        XCTAssertEqual(result, flags, "Flags should be unchanged for non-modifier key code")
    }
}
