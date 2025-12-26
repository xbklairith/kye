import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            RulesSettingsView()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin = true
    @State private var showInMenuBar = true

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
            Toggle("Show in menu bar", isOn: $showInMenuBar)
        }
        .padding()
    }
}

struct RulesSettingsView: View {
    var body: some View {
        VStack {
            Text("Rules configuration")
                .font(.headline)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .padding()
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
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
