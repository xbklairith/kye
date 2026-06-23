import XCTest
@testable import Kye

final class KeySymbolTests: XCTestCase {

    // MARK: - glyph(for:)

    func testGlyphForModifiers() {
        XCTAssertEqual(KeySymbol.glyph(for: "right_command"), "⌘")
        XCTAssertEqual(KeySymbol.glyph(for: "left_command"), "⌘")
        XCTAssertEqual(KeySymbol.glyph(for: "right_option"), "⌥")
        XCTAssertEqual(KeySymbol.glyph(for: "left_control"), "⌃")
        XCTAssertEqual(KeySymbol.glyph(for: "left_shift"), "⇧")
        XCTAssertEqual(KeySymbol.glyph(for: "caps_lock"), "⇪")
    }

    func testGlyphForArrowsAndSpecials() {
        XCTAssertEqual(KeySymbol.glyph(for: "left_arrow"), "←")
        XCTAssertEqual(KeySymbol.glyph(for: "right_arrow"), "→")
        XCTAssertEqual(KeySymbol.glyph(for: "up_arrow"), "↑")
        XCTAssertEqual(KeySymbol.glyph(for: "down_arrow"), "↓")
        XCTAssertEqual(KeySymbol.glyph(for: "escape"), "⎋")
        XCTAssertEqual(KeySymbol.glyph(for: "return"), "⏎")
        XCTAssertEqual(KeySymbol.glyph(for: "delete"), "⌫")
        XCTAssertEqual(KeySymbol.glyph(for: "tab"), "⇥")
    }

    func testGlyphForLettersAndFunctionKeys() {
        XCTAssertEqual(KeySymbol.glyph(for: "h"), "H")
        XCTAssertEqual(KeySymbol.glyph(for: "j"), "J")
        XCTAssertEqual(KeySymbol.glyph(for: "f1"), "F1")
    }

    func testGlyphIsCaseInsensitive() {
        XCTAssertEqual(KeySymbol.glyph(for: "RIGHT_COMMAND"), "⌘")
        XCTAssertEqual(KeySymbol.glyph(for: "H"), "H")
    }

    func testGlyphForUnknownFallsBackToUppercased() {
        XCTAssertEqual(KeySymbol.glyph(for: "zzz"), "ZZZ")
    }

    // MARK: - label(for:)

    func testLabelForKnownKeys() {
        XCTAssertEqual(KeySymbol.label(for: "right_command"), "Right Command")
        XCTAssertEqual(KeySymbol.label(for: "left_arrow"), "Left Arrow")
        XCTAssertEqual(KeySymbol.label(for: "page_up"), "Page Up")
    }

    func testLabelForSingleCharacter() {
        XCTAssertEqual(KeySymbol.label(for: "h"), "H")
    }

    // MARK: - isKnown(_:)

    func testIsKnownTrueForVocabularyKeys() {
        XCTAssertTrue(KeySymbol.isKnown("h"))
        XCTAssertTrue(KeySymbol.isKnown("right_command"))
        XCTAssertTrue(KeySymbol.isKnown("left_arrow"))
    }

    func testIsKnownFalseForUnknownKey() {
        XCTAssertFalse(KeySymbol.isKnown("zzz"))
        XCTAssertFalse(KeySymbol.isKnown(""))
    }
}
