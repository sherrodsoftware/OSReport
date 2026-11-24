import Sparkle
import SwiftUI

@main
struct OSReportApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests load the app as their host; skip the menu, timer, Sparkle and notifications there.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = updaterController
        controller = StatusItemController(updater: updaterController.updater)
    }
}
