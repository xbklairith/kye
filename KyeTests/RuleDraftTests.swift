import XCTest
@testable import Kye

final class RuleDraftTests: XCTestCase {

    func testBasicRuleRoundTrips() {
        let rule = Rule.basic(BasicRule(
            id: "b1", description: "Caps → Esc", enabled: true, from: "caps_lock", to: "escape"
        ))
        let draft = RuleDraft.make(from: rule)
        XCTAssertEqual(draft.toRule(), rule, "make→toRule must be lossless for a basic rule")
    }

    func testSingleMappingLayerRuleRoundTrips() {
        let rule = Rule.layer(LayerRule(
            id: "l1", description: "Nav layer", enabled: false,
            trigger: "right_command", mappings: ["h": "left_arrow"]
        ))
        let draft = RuleDraft.make(from: rule)
        XCTAssertEqual(draft.toRule(), rule, "make→toRule must be lossless for a single-mapping layer rule")
    }

    func testNilDescriptionRoundTripsToNil() {
        let rule = Rule.basic(BasicRule(
            id: "b2", description: nil, enabled: true, from: "a", to: "b"
        ))
        XCTAssertEqual(RuleDraft.make(from: rule).toRule(), rule)
    }

    func testEmptyIdGatesToNil() {
        var draft = RuleDraft(kind: .basic, id: "  ", description: "", enabled: true,
                              from: "a", to: "b", trigger: "", mappingFrom: "", mappingTo: "")
        XCTAssertNil(draft.toRule(), "blank id must block rule creation")
        draft.id = "ok"
        XCTAssertNotNil(draft.toRule())
    }

    func testBasicMissingFieldGatesToNil() {
        let draft = RuleDraft(kind: .basic, id: "b", description: "", enabled: true,
                              from: "a", to: "", trigger: "", mappingFrom: "", mappingTo: "")
        XCTAssertNil(draft.toRule(), "basic rule needs both from and to")
    }

    func testLayerMissingFieldGatesToNil() {
        let draft = RuleDraft(kind: .layer, id: "l", description: "", enabled: true,
                              from: "", to: "", trigger: "right_command", mappingFrom: "h", mappingTo: "")
        XCTAssertNil(draft.toRule(), "layer rule needs trigger and a full mapping pair")
    }

    func testWhitespaceIsTrimmedInBuiltRule() {
        let draft = RuleDraft(kind: .basic, id: "  b3 ", description: "  ", enabled: true,
                              from: " a ", to: " b ", trigger: "", mappingFrom: "", mappingTo: "")
        XCTAssertEqual(draft.toRule(), .basic(BasicRule(
            id: "b3", description: nil, enabled: true, from: "a", to: "b"
        )))
    }
}
