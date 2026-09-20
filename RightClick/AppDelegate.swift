import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private let logger = Logger(subsystem: "com.rightclick.app", category: "Requests")
    private var settingsWindow: NSWindow?
    private var receivedURL = false
    private var hasFinishedLaunching = false
    private var pendingSettingsOpen = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "右键新建")
        let settingsItem = NSMenuItem(title: "右键新建设置…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出右键新建", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true
        // Finder can deliver a settings URL before AppKit finishes launching.
        // Opening/activating the window that early loses the activation request.
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        if pendingSettingsOpen || (isDefaultLaunch && !receivedURL) {
            showSettings()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedURL = true
        for url in urls {
            logger.notice("Received Finder request: \(url.host ?? "unknown", privacy: .public)")
            if url == FileCreationRequest.settingsURL {
                showSettings()
                continue
            }
            let isEditorRequest = url.host == "open"
            do {
                if isEditorRequest {
                    model.openInEditor(try OpenInEditorRequest(url: url))
                } else {
                    model.create(try FileCreationRequest(url: url))
                }
            } catch {
                model.showError(error, title: isEditorRequest ? "无法打开应用" : "无法新建文件")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    @objc private func showSettings() {
        guard hasFinishedLaunching else {
            pendingSettingsOpen = true
            return
        }
        pendingSettingsOpen = false
        model.refreshExtensionStatus()
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 660, height: 700),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "右键新建"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: ContentView(model: model))
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        // Let the policy change reach the window server before requesting activation.
        DispatchQueue.main.async { [self] in
            NSApp.unhide(nil)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            settingsWindow?.deminiaturize(nil)
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Keep URL handling available, without occupying the Dock after setup.
        NSApp.setActivationPolicy(.accessory)
    }
}
