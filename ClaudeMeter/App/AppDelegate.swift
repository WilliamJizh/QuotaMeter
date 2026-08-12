import AppKit

/// App delegate to manage menu bar lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appModel: AppModel?
    private var menuBarManager: MenuBarManager?

    func configure(appModel: AppModel) {
        self.appModel = appModel
    }

    /// True when this process is only hosting the XCTest bundle.
    ///
    /// The test bundle launches the app for real, so without this guard every
    /// `xcodebuild test` run fires live provider requests — enough of them,
    /// across enough runs, to earn a rate limit.
    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isTestHost else { return }

        guard let appModel else {
            let fallbackModel = AppModel()
            self.appModel = fallbackModel
            startMenuBar(with: fallbackModel)
            return
        }
        startMenuBar(with: appModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startMenuBar(with appModel: AppModel) {
        let manager = MenuBarManager(appModel: appModel)
        menuBarManager = manager

        manager.start()
    }
}
