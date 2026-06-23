import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appController: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status indicator
            statusSection

            Divider()

            // Enable/Disable toggle
            Button(appController.isEnabled ? "Disable" : "Enable") {
                if appController.state == .waitingForPermission {
                    PermissionManager().requestPermission()
                } else {
                    appController.toggleEnabled()
                }
            }
            .keyboardShortcut("e", modifiers: .command)

            // Reload configuration
            Button("Reload Configuration") {
                try? appController.reloadConfiguration()
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            // Settings
            if #available(macOS 14.0, *) {
                SettingsMenuButton()
            } else {
                Button("Settings...") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            Divider()

            // Quit
            Button("Quit Kye") {
                appController.stop()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 4)
        .task {
            // Start the app controller when menu appears
            if appController.state == .initializing {
                try? await appController.start()
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Group {
            switch appController.state {
            case .running:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .disabled:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            case .waitingForPermission:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
            case .error(_):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .initializing:
                Image(systemName: "circle.dotted")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
    }

    private var statusTitle: String {
        switch appController.state {
        case .running:
            return "Active"
        case .disabled:
            return "Disabled"
        case .waitingForPermission:
            return "Permission Required"
        case .error(_):
            return "Error"
        case .initializing:
            return "Starting..."
        }
    }

    private var statusMessage: String {
        switch appController.state {
        case .running:
            return "Key remapping is active"
        case .disabled:
            return "Key remapping is paused"
        case .waitingForPermission:
            return "Grant Accessibility access"
        case .error(let message):
            return message
        case .initializing:
            return "Initializing services"
        }
    }
}

/// macOS 14+ "Settings…" menu item. The legacy `showSettingsWindow:` responder action no
/// longer opens the Settings scene from a menu-style `MenuBarExtra`, so use the dedicated
/// `openSettings` action and activate the app so the window comes to the front (accessory app).
@available(macOS 14.0, *)
private struct SettingsMenuButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

// Keep ContentView for backwards compatibility and previews
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Enable") {
                // Toggle remapping
            }
            .keyboardShortcut("e", modifiers: .command)

            Divider()

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Kye") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
