import Foundation

/// Protocol for configuration management
protocol ConfigurationManaging {
    var configuration: Configuration { get }
    var configurationURL: URL { get }

    func load() throws -> Configuration
    func save(_ configuration: Configuration) throws
    func validate(_ configuration: Configuration, keyMapper: KeyMapping) -> [ConfigurationError]
    func reload() throws
}

/// Validation error for configuration
struct ConfigurationError: Equatable {
    let ruleId: String
    let message: String
}

/// Manages loading, saving, and validating configuration
final class ConfigurationManager: ConfigurationManaging {

    private let fileManager: FileManager
    private let logger: Logging?
    private let keyMapper: KeyMapping

    private(set) var configuration: Configuration
    let configurationURL: URL

    init(
        configurationURL: URL? = nil,
        keyMapper: KeyMapping = KeyMapper(),
        logger: Logging? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.keyMapper = keyMapper

        // Default config path: ~/.config/kye/config.json
        if let url = configurationURL {
            self.configurationURL = url
        } else {
            let homeDirectory = fileManager.homeDirectoryForCurrentUser
            self.configurationURL = homeDirectory
                .appendingPathComponent(".config")
                .appendingPathComponent("kye")
                .appendingPathComponent("config.json")
        }

        // Load or create default
        self.configuration = Configuration.default
    }

    func load() throws -> Configuration {
        logger?.info("Loading configuration from \(configurationURL.path)", category: .configuration)

        // Check if file exists
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            logger?.info("Configuration file not found, creating default", category: .configuration)
            try createDefaultConfiguration()
            return configuration
        }

        // Read and decode
        do {
            let data = try Data(contentsOf: configurationURL)
            var loadedConfig = try JSONDecoder().decode(Configuration.self, from: data)

            // Check if migration needed
            if needsMigration(loadedConfig) {
                loadedConfig = try migrate(loadedConfig)
            }

            configuration = loadedConfig
            logger?.info("Configuration loaded successfully", category: .configuration)
            return configuration

        } catch let error as DecodingError {
            logger?.error("Failed to parse configuration: \(error)", category: .configuration)
            throw AppError.configurationParseError(line: 0, message: describeDecodingError(error))
        } catch {
            logger?.error("Failed to read configuration: \(error)", category: .configuration)
            throw AppError.configurationInaccessible
        }
    }

    func save(_ configuration: Configuration) throws {
        logger?.info("Saving configuration to \(configurationURL.path)", category: .configuration)

        // Ensure directory exists
        let directory = configurationURL.deletingLastPathComponent()
        try createDirectoryIfNeeded(directory)

        // Encode and write
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(configuration)
            try data.write(to: configurationURL, options: .atomic)
            self.configuration = configuration
            logger?.info("Configuration saved successfully", category: .configuration)
        } catch {
            logger?.error("Failed to save configuration: \(error)", category: .configuration)
            throw AppError.configurationInaccessible
        }
    }

    func validate(_ configuration: Configuration, keyMapper: KeyMapping) -> [ConfigurationError] {
        var errors: [ConfigurationError] = []

        for rule in configuration.rules {
            switch rule {
            case .basic(let basicRule):
                errors.append(contentsOf: validateBasicRule(basicRule, keyMapper: keyMapper))
            case .layer(let layerRule):
                errors.append(contentsOf: validateLayerRule(layerRule, keyMapper: keyMapper))
            }
        }

        return errors
    }

    func reload() throws {
        let _ = try load()
    }

    // MARK: - Migration

    private static let currentVersion = "1.0"

    private func needsMigration(_ config: Configuration) -> Bool {
        config.version != Self.currentVersion
    }

    private func migrate(_ config: Configuration) throws -> Configuration {
        logger?.info("Migrating configuration from v\(config.version) to v\(Self.currentVersion)", category: .configuration)

        // Backup before migration
        try backupConfiguration()

        // Currently only v1.0, so just update version
        var migrated = config
        migrated = Configuration(
            version: Self.currentVersion,
            enabled: config.enabled,
            rules: config.rules
        )

        // Save migrated config
        try save(migrated)

        logger?.info("Migration completed successfully", category: .configuration)
        return migrated
    }

    private func backupConfiguration() throws {
        let backupURL = configurationURL.appendingPathExtension("backup")

        if fileManager.fileExists(atPath: configurationURL.path) {
            // Remove old backup if exists
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: backupURL)
            }

            try fileManager.copyItem(at: configurationURL, to: backupURL)
            logger?.info("Configuration backed up to \(backupURL.path)", category: .configuration)
        }
    }

    // MARK: - Private Methods

    private func createDefaultConfiguration() throws {
        let defaultConfig = Configuration.default
        try save(defaultConfig)
        configuration = defaultConfig
    }

    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func validateBasicRule(_ rule: BasicRule, keyMapper: KeyMapping) -> [ConfigurationError] {
        var errors: [ConfigurationError] = []

        if keyMapper.keyCode(for: rule.from) == nil {
            errors.append(ConfigurationError(
                ruleId: rule.id,
                message: "Invalid 'from' key name: '\(rule.from)'"
            ))
        }

        if keyMapper.keyCode(for: rule.to) == nil {
            errors.append(ConfigurationError(
                ruleId: rule.id,
                message: "Invalid 'to' key name: '\(rule.to)'"
            ))
        }

        return errors
    }

    private func validateLayerRule(_ rule: LayerRule, keyMapper: KeyMapping) -> [ConfigurationError] {
        var errors: [ConfigurationError] = []

        if keyMapper.keyCode(for: rule.trigger) == nil {
            errors.append(ConfigurationError(
                ruleId: rule.id,
                message: "Invalid trigger key name: '\(rule.trigger)'"
            ))
        }

        for (fromKey, toKey) in rule.mappings {
            if keyMapper.keyCode(for: fromKey) == nil {
                errors.append(ConfigurationError(
                    ruleId: rule.id,
                    message: "Invalid mapping source key: '\(fromKey)'"
                ))
            }
            if keyMapper.keyCode(for: toKey) == nil {
                errors.append(ConfigurationError(
                    ruleId: rule.id,
                    message: "Invalid mapping target key: '\(toKey)'"
                ))
            }
        }

        return errors
    }

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing required key: '\(key.stringValue)'"
        case .typeMismatch(let type, let context):
            return "Type mismatch for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)"
        case .valueNotFound(let type, let context):
            return "Missing value for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}
