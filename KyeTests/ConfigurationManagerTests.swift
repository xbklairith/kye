import XCTest
@testable import Kye

final class ConfigurationManagerTests: XCTestCase {

    var tempDirectory: URL!
    var configURL: URL!
    var configManager: ConfigurationManager!
    var mockLogger: MockLogger!
    var keyMapper: KeyMapper!

    override func setUp() {
        super.setUp()

        // Create temp directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        configURL = tempDirectory.appendingPathComponent("config.json")
        mockLogger = MockLogger()
        keyMapper = KeyMapper()
        configManager = ConfigurationManager(
            configurationURL: configURL,
            keyMapper: keyMapper,
            logger: mockLogger
        )
    }

    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        configManager = nil
        mockLogger = nil
        keyMapper = nil
        super.tearDown()
    }

    // MARK: - Protocol Conformance

    func testConformsToConfigurationManagingProtocol() {
        let manager: any ConfigurationManaging = configManager
        XCTAssertNotNil(manager)
    }

    // MARK: - Load Tests

    func testLoadCreatesDefaultWhenFileMissing() throws {
        let config = try configManager.load()

        XCTAssertEqual(config.version, "1.0")
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.rules.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))
    }

    func testLoadReadsExistingConfiguration() throws {
        // Create a config file
        let json = """
        {
            "version": "1.0",
            "enabled": false,
            "rules": []
        }
        """
        try json.data(using: .utf8)!.write(to: configURL)

        let config = try configManager.load()

        XCTAssertEqual(config.version, "1.0")
        XCTAssertFalse(config.enabled)
    }

    func testLoadParsesBasicRule() throws {
        let json = """
        {
            "version": "1.0",
            "enabled": true,
            "rules": [
                {
                    "type": "basic",
                    "id": "rule-001",
                    "description": "Test rule",
                    "enabled": true,
                    "from": "right_alt",
                    "to": "right_command"
                }
            ]
        }
        """
        try json.data(using: .utf8)!.write(to: configURL)

        let config = try configManager.load()

        XCTAssertEqual(config.rules.count, 1)

        if case .basic(let basicRule) = config.rules[0] {
            XCTAssertEqual(basicRule.id, "rule-001")
            XCTAssertEqual(basicRule.from, "right_alt")
            XCTAssertEqual(basicRule.to, "right_command")
        } else {
            XCTFail("Expected basic rule")
        }
    }

    func testLoadParsesLayerRule() throws {
        let json = """
        {
            "version": "1.0",
            "enabled": true,
            "rules": [
                {
                    "type": "layer",
                    "id": "rule-002",
                    "description": "Vim navigation",
                    "enabled": true,
                    "trigger": "right_command",
                    "mappings": {
                        "h": "left_arrow",
                        "j": "down_arrow",
                        "k": "up_arrow",
                        "l": "right_arrow"
                    }
                }
            ]
        }
        """
        try json.data(using: .utf8)!.write(to: configURL)

        let config = try configManager.load()

        XCTAssertEqual(config.rules.count, 1)

        if case .layer(let layerRule) = config.rules[0] {
            XCTAssertEqual(layerRule.id, "rule-002")
            XCTAssertEqual(layerRule.trigger, "right_command")
            XCTAssertEqual(layerRule.mappings.count, 4)
            XCTAssertEqual(layerRule.mappings["h"], "left_arrow")
        } else {
            XCTFail("Expected layer rule")
        }
    }

    func testLoadThrowsOnInvalidJSON() throws {
        let invalidJson = "{ invalid json }"
        try invalidJson.data(using: .utf8)!.write(to: configURL)

        XCTAssertThrowsError(try configManager.load()) { error in
            if case AppError.configurationParseError = error {
                // Expected
            } else {
                XCTFail("Expected configurationParseError, got \(error)")
            }
        }
    }

    func testLoadLogsMessages() throws {
        _ = try configManager.load()

        XCTAssertTrue(mockLogger.hasEntry(level: .info, containing: "Loading configuration"))
    }

    // MARK: - Save Tests

    func testSaveWritesConfiguration() throws {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "test",
                    description: nil,
                    enabled: true,
                    from: "a",
                    to: "b"
                ))
            ]
        )

        try configManager.save(config)

        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))

        let data = try Data(contentsOf: configURL)
        let loaded = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(loaded.rules.count, 1)
    }

    func testSaveCreatesDirectoryIfNeeded() throws {
        let nestedURL = tempDirectory
            .appendingPathComponent("nested")
            .appendingPathComponent("dir")
            .appendingPathComponent("config.json")

        let manager = ConfigurationManager(
            configurationURL: nestedURL,
            keyMapper: keyMapper,
            logger: mockLogger
        )

        try manager.save(Configuration.default)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedURL.path))
    }

    func testSaveUpdatesInternalConfiguration() throws {
        let newConfig = Configuration(version: "1.0", enabled: false, rules: [])

        try configManager.save(newConfig)

        XCTAssertFalse(configManager.configuration.enabled)
    }

    // MARK: - Validation Tests

    func testValidateDetectsInvalidFromKey() {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "bad-rule",
                    description: nil,
                    enabled: true,
                    from: "invalid_key_name",
                    to: "a"
                ))
            ]
        )

        let errors = configManager.validate(config, keyMapper: keyMapper)

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].ruleId, "bad-rule")
        XCTAssertTrue(errors[0].message.contains("invalid_key_name"))
    }

    func testValidateDetectsInvalidToKey() {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "bad-rule",
                    description: nil,
                    enabled: true,
                    from: "a",
                    to: "nonexistent"
                ))
            ]
        )

        let errors = configManager.validate(config, keyMapper: keyMapper)

        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].message.contains("nonexistent"))
    }

    func testValidateDetectsInvalidTriggerKey() {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .layer(LayerRule(
                    id: "bad-layer",
                    description: nil,
                    enabled: true,
                    trigger: "bad_trigger",
                    mappings: ["h": "left_arrow"]
                ))
            ]
        )

        let errors = configManager.validate(config, keyMapper: keyMapper)

        XCTAssertTrue(errors.contains { $0.message.contains("bad_trigger") })
    }

    func testValidateDetectsInvalidMappingKeys() {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .layer(LayerRule(
                    id: "bad-layer",
                    description: nil,
                    enabled: true,
                    trigger: "right_command",
                    mappings: ["bad_source": "left_arrow", "h": "bad_target"]
                ))
            ]
        )

        let errors = configManager.validate(config, keyMapper: keyMapper)

        XCTAssertEqual(errors.count, 2)
    }

    func testValidateReturnsEmptyForValidConfiguration() {
        let config = Configuration(
            version: "1.0",
            enabled: true,
            rules: [
                .basic(BasicRule(
                    id: "valid-basic",
                    description: nil,
                    enabled: true,
                    from: "right_alt",
                    to: "right_command"
                )),
                .layer(LayerRule(
                    id: "valid-layer",
                    description: nil,
                    enabled: true,
                    trigger: "right_command",
                    mappings: ["h": "left_arrow", "j": "down_arrow"]
                ))
            ]
        )

        let errors = configManager.validate(config, keyMapper: keyMapper)

        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Migration Tests

    func testMigrationUpdatesVersion() throws {
        let oldJson = """
        {
            "version": "0.9",
            "enabled": true,
            "rules": []
        }
        """
        try oldJson.data(using: .utf8)!.write(to: configURL)

        let config = try configManager.load()

        XCTAssertEqual(config.version, "1.0")
    }

    func testMigrationPreservesRules() throws {
        let oldJson = """
        {
            "version": "0.9",
            "enabled": true,
            "rules": [
                {
                    "type": "basic",
                    "id": "rule-001",
                    "enabled": true,
                    "from": "a",
                    "to": "b"
                }
            ]
        }
        """
        try oldJson.data(using: .utf8)!.write(to: configURL)

        let config = try configManager.load()

        XCTAssertEqual(config.rules.count, 1)
    }

    func testMigrationCreatesBackup() throws {
        let oldJson = """
        {
            "version": "0.9",
            "enabled": true,
            "rules": []
        }
        """
        try oldJson.data(using: .utf8)!.write(to: configURL)

        _ = try configManager.load()

        let backupURL = configURL.appendingPathExtension("backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    // MARK: - Reload Tests

    func testReloadRefreshesConfiguration() throws {
        // Initial load
        _ = try configManager.load()

        // Modify file externally
        let newJson = """
        {
            "version": "1.0",
            "enabled": false,
            "rules": []
        }
        """
        try newJson.data(using: .utf8)!.write(to: configURL)

        // Reload
        try configManager.reload()

        XCTAssertFalse(configManager.configuration.enabled)
    }

    // MARK: - Configuration URL Tests

    func testConfigurationURLReturnsCorrectPath() {
        let manager = ConfigurationManager(configurationURL: configURL, keyMapper: keyMapper)
        XCTAssertEqual(manager.configurationURL, configURL)
    }

    func testDefaultConfigurationURLIsInHomeDirectory() {
        let manager = ConfigurationManager(keyMapper: keyMapper)
        let path = manager.configurationURL.path

        XCTAssertTrue(path.contains(".config/kye/config.json"))
    }
}
