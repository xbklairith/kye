import SwiftUI
import AppKit

@main
struct KyeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appController: AppController

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

        // Initialize AppController
        let keyMapper = KeyMapper()
        let modifierHandler = ModifierHandler()
        let logger = LoggerService()

        let permissionManager = PermissionManager(logger: logger)
        let configManager = ConfigurationManager(keyMapper: keyMapper, logger: logger)
        let eventTapManager = EventTapManager()
        let ruleEngine = RuleEngine(keyMapper: keyMapper, modifierHandler: modifierHandler)

        let controller = AppController(
            permissionManager: permissionManager,
            configManager: configManager,
            eventTapManager: eventTapManager,
            ruleEngine: ruleEngine,
            keyMapper: keyMapper,
            logger: logger
        )

        _appController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(appController: appController)
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appController: appController)
        }
    }

    private var menuBarIcon: some View {
        Group {
            switch appController.state {
            case .running:
                Image(systemName: "keyboard.fill")
            case .disabled:
                Image(systemName: "keyboard")
            case .waitingForPermission:
                Image(systemName: "keyboard.badge.exclamationmark")
            case .error:
                Image(systemName: "keyboard.badge.exclamationmark")
            case .initializing:
                Image(systemName: "keyboard")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App launched - initialization handled by AppController
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup handled by AppController deinit
    }
}
