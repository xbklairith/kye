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
    @State private var reloadMessage: String?

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

            if let message = reloadMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            Text("Edit ~/.config/kye/config.json to modify rules")
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

    private var rulesListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                // This is a placeholder - actual implementation would read from ConfigurationManager
                Text("Configuration loaded from ~/.config/kye/config.json")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: 150)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }

    private func reloadConfiguration() {
        do {
            try appController.reloadConfiguration()
            reloadMessage = "Configuration reloaded successfully"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                reloadMessage = nil
            }
        } catch {
            reloadMessage = "Failed to reload: \(error.localizedDescription)"
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
