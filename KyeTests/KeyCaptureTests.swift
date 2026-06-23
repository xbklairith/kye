import XCTest
import AppKit
@testable import Kye

final class KeyCaptureTests: XCTestCase {

    private let keyMapper = KeyMapper()

    func testKeyDownResolvesToKeyName() {
        let hCode = keyMapper.keyCode(for: "h")!
        let name = KeyCaptureController.capturedKeyName(
            type: .keyDown, keyCode: UInt16(hCode), modifierFlags: [], keyMapper: keyMapper
        )
        XCTAssertEqual(name, "h")
    }

    func testFlagsChangedPressResolvesModifier() {
        let name = KeyCaptureController.capturedKeyName(
            type: .flagsChanged, keyCode: 0x3D, modifierFlags: [.option], keyMapper: keyMapper
        )
        XCTAssertEqual(name, "right_option")
    }

    func testFlagsChangedDistinguishesLeftRight() {
        let left = KeyCaptureController.capturedKeyName(
            type: .flagsChanged, keyCode: 0x37, modifierFlags: [.command], keyMapper: keyMapper
        )
        let right = KeyCaptureController.capturedKeyName(
            type: .flagsChanged, keyCode: 0x36, modifierFlags: [.command], keyMapper: keyMapper
        )
        XCTAssertEqual(left, "left_command")
        XCTAssertEqual(right, "right_command")
    }

    func testFlagsChangedReleaseReturnsNil() {
        // Modifier keycode present but its mask is NOT set → release edge, ignore.
        let name = KeyCaptureController.capturedKeyName(
            type: .flagsChanged, keyCode: 0x3D, modifierFlags: [], keyMapper: keyMapper
        )
        XCTAssertNil(name)
    }

    func testUnknownModifierKeyCodeReturnsNil() {
        let name = KeyCaptureController.capturedKeyName(
            type: .flagsChanged, keyCode: 0xFF, modifierFlags: [.command], keyMapper: keyMapper
        )
        XCTAssertNil(name)
    }
}
