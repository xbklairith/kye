import XCTest
@testable import Kye

final class ConfigurationTests: XCTestCase {

    // MARK: - Configuration Encoding/Decoding Tests

    func testConfigurationEncodesCorrectly() throws {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"version\":\"1.0\""))
        XCTAssertTrue(json.contains("\"enabled\":true"))
        XCTAssertTrue(json.contains("\"rules\":[]"))
    }

    func testConfigurationDecodesCorrectly() throws {
        let json = """
        {
            "version": "1.0",
            "enabled": true,
            "rules": []
        }
        """

        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.enabled, true)
        XCTAssertTrue(config.rules.isEmpty)
    }

    func testConfigurationDecodesWithRules() throws {
        let json = """
        {
            "version": "1.0",
            "enabled": true,
            "rules": [
                {
                    "type": "basic",
                    "id": "rule-001",
                    "description": "Right Alt to Right Cmd",
                    "enabled": true,
                    "from": "right_alt",
                    "to": "right_command"
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.rules.count, 1)
    }

    func testDefaultConfigurationValues() {
        let config = Configuration.default

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.enabled, true)
        XCTAssertTrue(config.rules.isEmpty)
    }

    func testInvalidJSONThrowsDecodingError() {
        let invalidJson = """
        {
            "version": "1.0",
            "enabled": "not_a_boolean"
        }
        """

        let data = invalidJson.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(Configuration.self, from: data))
    }
}

final class BasicRuleTests: XCTestCase {

    // MARK: - BasicRule Parsing Tests

    func testBasicRuleParsingFromJSON() throws {
        let json = """
        {
            "type": "basic",
            "id": "rule-001",
            "description": "Right Alt to Right Cmd",
            "enabled": true,
            "from": "right_alt",
            "to": "right_command"
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        guard case .basic(let basicRule) = rule else {
            XCTFail("Expected basic rule")
            return
        }

        XCTAssertEqual(basicRule.id, "rule-001")
        XCTAssertEqual(basicRule.description, "Right Alt to Right Cmd")
        XCTAssertEqual(basicRule.enabled, true)
        XCTAssertEqual(basicRule.from, "right_alt")
        XCTAssertEqual(basicRule.to, "right_command")
    }

    func testBasicRuleParsingWithOptionalDescription() throws {
        let json = """
        {
            "type": "basic",
            "id": "rule-002",
            "enabled": true,
            "from": "a",
            "to": "b"
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        guard case .basic(let basicRule) = rule else {
            XCTFail("Expected basic rule")
            return
        }

        XCTAssertEqual(basicRule.id, "rule-002")
        XCTAssertNil(basicRule.description)
        XCTAssertEqual(basicRule.from, "a")
        XCTAssertEqual(basicRule.to, "b")
    }

    func testBasicRuleEncoding() throws {
        let basicRule = BasicRule(
            id: "test-001",
            description: "Test rule",
            enabled: true,
            from: "h",
            to: "left_arrow"
        )
        let rule = Rule.basic(basicRule)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(rule)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"type\":\"basic\""))
        XCTAssertTrue(json.contains("\"id\":\"test-001\""))
        XCTAssertTrue(json.contains("\"from\":\"h\""))
        XCTAssertTrue(json.contains("\"to\":\"left_arrow\""))
    }

    func testBasicRuleDefaultEnabled() throws {
        let json = """
        {
            "type": "basic",
            "id": "rule-003",
            "from": "x",
            "to": "y"
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        guard case .basic(let basicRule) = rule else {
            XCTFail("Expected basic rule")
            return
        }

        // Default enabled should be true when not specified
        XCTAssertEqual(basicRule.enabled, true)
    }
}

final class LayerRuleTests: XCTestCase {

    // MARK: - LayerRule Parsing Tests

    func testLayerRuleParsingFromJSON() throws {
        let json = """
        {
            "type": "layer",
            "id": "rule-002",
            "description": "Vim Navigation Layer",
            "enabled": true,
            "trigger": "right_command",
            "mappings": {
                "h": "left_arrow",
                "j": "down_arrow",
                "k": "up_arrow",
                "l": "right_arrow"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        guard case .layer(let layerRule) = rule else {
            XCTFail("Expected layer rule")
            return
        }

        XCTAssertEqual(layerRule.id, "rule-002")
        XCTAssertEqual(layerRule.description, "Vim Navigation Layer")
        XCTAssertEqual(layerRule.enabled, true)
        XCTAssertEqual(layerRule.trigger, "right_command")
        XCTAssertEqual(layerRule.mappings["h"], "left_arrow")
        XCTAssertEqual(layerRule.mappings["j"], "down_arrow")
        XCTAssertEqual(layerRule.mappings["k"], "up_arrow")
        XCTAssertEqual(layerRule.mappings["l"], "right_arrow")
    }

    func testLayerRuleParsingWithOptionalDescription() throws {
        let json = """
        {
            "type": "layer",
            "id": "rule-003",
            "enabled": true,
            "trigger": "right_option",
            "mappings": {
                "a": "b"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        guard case .layer(let layerRule) = rule else {
            XCTFail("Expected layer rule")
            return
        }

        XCTAssertEqual(layerRule.id, "rule-003")
        XCTAssertNil(layerRule.description)
        XCTAssertEqual(layerRule.trigger, "right_option")
    }

    func testLayerRuleEncoding() throws {
        let layerRule = LayerRule(
            id: "test-layer",
            description: "Test layer",
            enabled: true,
            trigger: "right_command",
            mappings: ["h": "left_arrow"]
        )
        let rule = Rule.layer(layerRule)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(rule)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"type\":\"layer\""))
        XCTAssertTrue(json.contains("\"id\":\"test-layer\""))
        XCTAssertTrue(json.contains("\"trigger\":\"right_command\""))
    }

    func testLayerRuleDefaultEnabled() throws {
        let json = """
        {
            "type": "layer",
            "id": "rule-004",
            "trigger": "right_command",
            "mappings": {}
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        guard case .layer(let layerRule) = rule else {
            XCTFail("Expected layer rule")
            return
        }

        // Default enabled should be true when not specified
        XCTAssertEqual(layerRule.enabled, true)
    }
}

final class RuleTypeDiscriminationTests: XCTestCase {

    // MARK: - Type Discrimination Tests

    func testRuleTypeDiscriminationBasic() throws {
        let json = """
        {
            "type": "basic",
            "id": "rule-001",
            "enabled": true,
            "from": "a",
            "to": "b"
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        if case .basic(_) = rule {
            // Success
        } else {
            XCTFail("Expected basic rule type")
        }
    }

    func testRuleTypeDiscriminationLayer() throws {
        let json = """
        {
            "type": "layer",
            "id": "rule-002",
            "enabled": true,
            "trigger": "right_command",
            "mappings": {}
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(Rule.self, from: data)

        if case .layer(_) = rule {
            // Success
        } else {
            XCTFail("Expected layer rule type")
        }
    }

    func testInvalidRuleTypeThrowsError() {
        let json = """
        {
            "type": "unknown",
            "id": "rule-001"
        }
        """

        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(Rule.self, from: data))
    }

    func testMissingTypeThrowsError() {
        let json = """
        {
            "id": "rule-001",
            "from": "a",
            "to": "b"
        }
        """

        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(Rule.self, from: data))
    }

    func testMixedRulesInConfiguration() throws {
        let json = """
        {
            "version": "1.0",
            "enabled": true,
            "rules": [
                {
                    "type": "basic",
                    "id": "rule-001",
                    "enabled": true,
                    "from": "right_alt",
                    "to": "right_command"
                },
                {
                    "type": "layer",
                    "id": "rule-002",
                    "enabled": true,
                    "trigger": "right_command",
                    "mappings": {
                        "h": "left_arrow"
                    }
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(config.rules.count, 2)

        if case .basic(_) = config.rules[0] {
            // First rule is basic
        } else {
            XCTFail("First rule should be basic")
        }

        if case .layer(_) = config.rules[1] {
            // Second rule is layer
        } else {
            XCTFail("Second rule should be layer")
        }
    }

    func testRuleRoundTrip() throws {
        // Create original configuration
        let originalConfig = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(id: "r1", description: "Test", enabled: true, from: "a", to: "b")),
                .layer(LayerRule(id: "r2", description: "Layer", enabled: true, trigger: "right_command", mappings: ["h": "left_arrow"]))
            ]
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)

        // Decode back
        let decodedConfig = try JSONDecoder().decode(Configuration.self, from: data)

        // Verify
        XCTAssertEqual(decodedConfig.version, originalConfig.version)
        XCTAssertEqual(decodedConfig.enabled, originalConfig.enabled)
        XCTAssertEqual(decodedConfig.rules.count, originalConfig.rules.count)
    }
}
