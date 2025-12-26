import SwiftUI
import AppKit

@main
struct KyeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Check for existing instance (REQ-052)
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count > 1 {
            // Activate existing instance
            NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                .first { $0 != NSRunningApplication.current }?
                .activate(options: .activateIgnoringOtherApps)

            // Terminate this instance
            NSApplication.shared.terminate(nil)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "keyboard")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App launched
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
