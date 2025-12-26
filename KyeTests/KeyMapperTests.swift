import XCTest
import CoreGraphics
@testable import Kye

final class KeyMapperTests: XCTestCase {

    var keyMapper: KeyMapper!

    override func setUp() {
        super.setUp()
        keyMapper = KeyMapper()
    }

    override func tearDown() {
        keyMapper = nil
        super.tearDown()
    }

    // MARK: - Key Name to Code Translation Tests

    func testKeyCodeForH() {
        // H key should return key code 0x04
        XCTAssertEqual(keyMapper.keyCode(for: "h"), 0x04)
    }

    func testKeyCodeForJ() {
        // J key should return key code 0x26
        XCTAssertEqual(keyMapper.keyCode(for: "j"), 0x26)
    }

    func testKeyCodeForK() {
        // K key should return key code 0x28
        XCTAssertEqual(keyMapper.keyCode(for: "k"), 0x28)
    }

    func testKeyCodeForL() {
        // L key should return key code 0x25
        XCTAssertEqual(keyMapper.keyCode(for: "l"), 0x25)
    }

    func testKeyCodeForLeftArrow() {
        XCTAssertEqual(keyMapper.keyCode(for: "left_arrow"), 0x7B)
    }

    func testKeyCodeForRightArrow() {
        XCTAssertEqual(keyMapper.keyCode(for: "right_arrow"), 0x7C)
    }

    func testKeyCodeForDownArrow() {
        XCTAssertEqual(keyMapper.keyCode(for: "down_arrow"), 0x7D)
    }

    func testKeyCodeForUpArrow() {
        XCTAssertEqual(keyMapper.keyCode(for: "up_arrow"), 0x7E)
    }

    func testKeyCodeForRightCommand() {
        XCTAssertEqual(keyMapper.keyCode(for: "right_command"), 0x36)
    }

    func testKeyCodeForLeftCommand() {
        XCTAssertEqual(keyMapper.keyCode(for: "left_command"), 0x37)
    }

    func testKeyCodeForRightOption() {
        XCTAssertEqual(keyMapper.keyCode(for: "right_option"), 0x3D)
    }

    func testKeyCodeForRightAlt() {
        // right_alt is an alias for right_option
        XCTAssertEqual(keyMapper.keyCode(for: "right_alt"), 0x3D)
    }

    func testKeyCodeForLeftOption() {
        XCTAssertEqual(keyMapper.keyCode(for: "left_option"), 0x3A)
    }

    func testKeyCodeForRightControl() {
        XCTAssertEqual(keyMapper.keyCode(for: "right_control"), 0x3E)
    }

    func testKeyCodeForLeftControl() {
        XCTAssertEqual(keyMapper.keyCode(for: "left_control"), 0x3B)
    }

    func testKeyCodeForRightShift() {
        XCTAssertEqual(keyMapper.keyCode(for: "right_shift"), 0x3C)
    }

    func testKeyCodeForLeftShift() {
        XCTAssertEqual(keyMapper.keyCode(for: "left_shift"), 0x38)
    }

    func testKeyCodeForInvalidKeyReturnsNil() {
        XCTAssertNil(keyMapper.keyCode(for: "invalid_key"))
        XCTAssertNil(keyMapper.keyCode(for: "nonexistent"))
        XCTAssertNil(keyMapper.keyCode(for: ""))
    }

    // MARK: - Key Code to Name Translation Tests (Reverse Lookup)

    func testKeyNameForHCode() {
        XCTAssertEqual(keyMapper.keyName(for: 0x04), "h")
    }

    func testKeyNameForJCode() {
        XCTAssertEqual(keyMapper.keyName(for: 0x26), "j")
    }

    func testKeyNameForLeftArrowCode() {
        XCTAssertEqual(keyMapper.keyName(for: 0x7B), "left_arrow")
    }

    func testKeyNameForRightCommandCode() {
        XCTAssertEqual(keyMapper.keyName(for: 0x36), "right_command")
    }

    func testKeyNameForInvalidCodeReturnsNil() {
        XCTAssertNil(keyMapper.keyName(for: 0xFF))
    }

    // MARK: - Case Insensitivity Tests

    func testKeyCodeIsCaseInsensitive() {
        XCTAssertEqual(keyMapper.keyCode(for: "H"), 0x04)
        XCTAssertEqual(keyMapper.keyCode(for: "RIGHT_COMMAND"), 0x36)
        XCTAssertEqual(keyMapper.keyCode(for: "Left_Arrow"), 0x7B)
    }

    // MARK: - All Letter Keys Tests

    func testAllLetterKeys() {
        let expectedCodes: [String: CGKeyCode] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06
        ]

        for (letter, expectedCode) in expectedCodes {
            XCTAssertEqual(
                keyMapper.keyCode(for: letter),
                expectedCode,
                "Key '\(letter)' should map to code \(String(format: "0x%02X", expectedCode))"
            )
        }
    }

    // MARK: - Special Keys Tests

    func testSpecialKeys() {
        XCTAssertEqual(keyMapper.keyCode(for: "escape"), 0x35)
        XCTAssertEqual(keyMapper.keyCode(for: "return"), 0x24)
        XCTAssertEqual(keyMapper.keyCode(for: "tab"), 0x30)
        XCTAssertEqual(keyMapper.keyCode(for: "space"), 0x31)
        XCTAssertEqual(keyMapper.keyCode(for: "delete"), 0x33)
        XCTAssertEqual(keyMapper.keyCode(for: "backspace"), 0x33)
    }

    // MARK: - Protocol Conformance Test

    func testConformsToKeyMappingProtocol() {
        let mapper: any KeyMapping = keyMapper
        XCTAssertNotNil(mapper.keyCode(for: "h"))
        XCTAssertNotNil(mapper.keyName(for: 0x04))
    }
}
