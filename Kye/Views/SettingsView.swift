import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var appController: AppController

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            RulesSettingsView(appController: appController)
                .tabItem {
                    Label("Rules", systemImage: "list.bullet")
                }

            PermissionSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var launchManager: LaunchAtLoginManager {
        LaunchAtLoginManager()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }

                Text("Kye will start automatically when you log in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Text("Configuration file")
                    Spacer()
                    Text("~/.config/kye/config.json")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }

                Button("Open Configuration Folder") {
                    openConfigFolder()
                }
            }
        }
        .padding()
        .onAppear {
            loadLaunchAtLoginStatus()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadLaunchAtLoginStatus() {
        let status = launchManager.checkStatus()
        launchAtLogin = status == .enabled
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try launchManager.register()
            } else {
                try launchManager.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // Revert toggle
            launchAtLogin = !enabled
        }
    }

    private func openConfigFolder() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("kye")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configPath, withIntermediateDirectories: true)

        NSWorkspace.shared.open(configPath)
    }
}

struct RulesSettingsView: View {
    @ObservedObject var appController: AppController
    @State private var statusMessage: String?
    @State private var saveError: String?

    /// Splits rules into basic remaps and layer rules, preserving original order.
    static func groupedRules(_ rules: [Rule]) -> (remaps: [Rule], layers: [Rule]) {
        var remaps: [Rule] = []
        var layers: [Rule] = []
        for rule in rules {
            switch rule.kind {
            case .basic: remaps.append(rule)
            case .layer: layers.append(rule)
            }
        }
        return (remaps, layers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Rules")
                    .font(.headline)
                Spacer()
                Button("Reload") {
                    reloadConfiguration()
                }
            }

            if appController.state == .waitingForPermission {
                permissionRequiredView
            } else {
                rulesListView
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Text("Rules are saved to ~/.config/kye/config.json")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var permissionRequiredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("Accessibility Permission Required")
                .font(.headline)

            Text("Grant permission in System Settings to view and edit rules")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                PermissionManager().openSystemPreferences()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var rulesListView: some View {
        if appController.rules.isEmpty {
            emptyStateView
        } else {
            let grouped = Self.groupedRules(appController.rules)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !grouped.remaps.isEmpty {
                        ruleSection(title: "Remaps", rules: grouped.remaps)
                    }
                    if !grouped.layers.isEmpty {
                        ruleSection(title: "Layers", rules: grouped.layers)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 190)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func ruleSection(title: String, rules: [Rule]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
            // Key by position, not rule.id: duplicate ids are a detected error state
            // (see duplicate-id validation) and would otherwise make ForEach undefined.
            ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                RuleRow(
                    rule: rule,
                    errors: appController.validationErrors[rule.id] ?? [],
                    onToggle: { enabled in setRuleEnabled(rule, enabled: enabled) }
                )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No rules yet")
                .font(.headline)

            Text("Add rules by editing the configuration file, then press Reload.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Configuration Folder") {
                openConfigFolder()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func setRuleEnabled(_ rule: Rule, enabled: Bool) {
        do {
            try appController.setRuleEnabled(id: rule.id, enabled: enabled)
            saveError = nil
            statusMessage = "Saved"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if statusMessage == "Saved" { statusMessage = nil }
            }
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func openConfigFolder() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("kye")
        try? FileManager.default.createDirectory(at: configPath, withIntermediateDirectories: true)
        NSWorkspace.shared.open(configPath)
    }

    private func reloadConfiguration() {
        do {
            try appController.reloadConfiguration()
            saveError = nil
            statusMessage = "Configuration reloaded successfully"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = nil
            }
        } catch {
            saveError = "Failed to reload: \(error.localizedDescription)"
        }
    }
}

/// A single rule row: enable toggle, source→target glyphs, description, and an error badge.
private struct RuleRow: View {
    let rule: Rule
    let errors: [String]
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(get: { isEnabled }, set: { onToggle($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)

                mappingSummary
                    .font(.system(.body, design: .rounded))

                Spacer()

                if !errors.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help(errors.joined(separator: "\n"))
                }
            }

            if let description = ruleDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !errors.isEmpty {
                Text(errors.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .opacity(isEnabled ? 1.0 : 0.55)
    }

    private var isEnabled: Bool {
        switch rule {
        case .basic(let r): return r.enabled
        case .layer(let r): return r.enabled
        }
    }

    private var ruleDescription: String? {
        switch rule {
        case .basic(let r): return r.description
        case .layer(let r): return r.description
        }
    }

    @ViewBuilder
    private var mappingSummary: some View {
        switch rule {
        case .basic(let r):
            HStack(spacing: 4) {
                Text(KeySymbol.glyph(for: r.from))
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(KeySymbol.glyph(for: r.to))
            }
        case .layer(let r):
            HStack(spacing: 4) {
                Text(KeySymbol.glyph(for: r.trigger))
                Text("layer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("· \(r.mappings.count) keys")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PermissionSettingsView: View {
    @State private var hasPermission = false
    private let permissionManager = PermissionManager()

    var body: some View {
        VStack(spacing: 20) {
            statusSection

            Divider()

            instructionsSection
        }
        .padding()
        .onAppear {
            checkPermission()
        }
    }

    private var statusSection: some View {
        HStack(spacing: 16) {
            Image(systemName: hasPermission ? "checkmark.shield.fill" : "xmark.shield.fill")
                .font(.system(size: 36))
                .foregroundColor(hasPermission ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility Permission")
                    .font(.headline)

                Text(hasPermission ? "Granted" : "Not Granted")
                    .foregroundColor(hasPermission ? .green : .red)
            }

            Spacer()

            if !hasPermission {
                Button("Grant Access") {
                    permissionManager.requestPermission()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why is this needed?")
                .font(.headline)

            Text("Kye needs Accessibility permission to intercept and remap keyboard events. Without this permission, key remapping will not work.")
                .foregroundColor(.secondary)

            Text("How to grant permission:")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Click 'Grant Access' or open System Settings manually")
                instructionRow(number: 2, text: "Navigate to Privacy & Security > Accessibility")
                instructionRow(number: 3, text: "Find Kye in the list and enable it")
                instructionRow(number: 4, text: "You may need to unlock settings with your password")
            }

            Button("Open System Settings") {
                permissionManager.openSystemPreferences()
            }
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.medium)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .foregroundColor(.secondary)
        }
    }

    private func checkPermission() {
        hasPermission = permissionManager.checkPermission() == .granted
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Kye")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("A lightweight key remapping utility for macOS")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 8)

            VStack(spacing: 4) {
                Text("Default Mappings:")
                    .font(.headline)
                Text("Right Alt → Right Command")
                    .font(.system(.body, design: .monospaced))
                Text("Right Cmd + HJKL → Arrow Keys")
                    .font(.system(.body, design: .monospaced))
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// Preview disabled - requires mock objects from test target
// #Preview {
//     SettingsView(appController: ...)
// }
