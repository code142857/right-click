import AppKit
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RightClickFinder", category: "Finder")
    private var volumeObservers: [NSObjectProtocol] = []
    private var menuActions = FinderMenuActionStore()
    private var editorIcons: [EditorApp: NSImage] = [:]

    override init() {
        super.init()
        updateDirectories()

        // Include external and network volumes, including ones mounted after startup.
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            volumeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.updateDirectories()
            })
        }
    }

    deinit {
        for observer in volumeObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func updateDirectories() {
        var roots: Set<URL> = [URL(fileURLWithPath: "/", isDirectory: true)]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
        roots.formUnion(volumes)
        FIFinderSyncController.default().directoryURLs = roots
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let context: FinderDestination.Context
        switch menuKind {
        case .contextualMenuForContainer: context = .container
        case .contextualMenuForItems: context = .items
        case .contextualMenuForSidebar: context = .sidebar
        case .toolbarItemMenu: context = .toolbar
        @unknown default: return nil
        }

        let controller = FIFinderSyncController.default()
        let target = controller.targetedURL()
        let selection = controller.selectedItemURLs() ?? []
        let menu = NSMenu(title: "右键新建")
        menu.autoenablesItems = false

        if let directory = FinderDestination.directory(for: context, target: target, selection: selection) {
            menu.addItem(newFileMenuItem(in: directory))
        }

        let items = FinderDestination.itemsToOpen(for: context, target: target, selection: selection)
        if !items.isEmpty {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            for editor in EditorApp.allCases {
                guard let request = try? OpenInEditorRequest(editor: editor, items: items) else { continue }
                let item = NSMenuItem(title: editor.menuTitle, action: #selector(performMenuAction(_:)), keyEquivalent: "")
                item.target = self
                item.image = icon(for: editor)
                item.tag = menuActions.register(request.url)
                menu.addItem(item)
            }

            menu.addItem(.separator())
            for style in PathCopyStyle.allCases {
                guard let request = try? CopyPathRequest(style: style, items: items) else { continue }
                let item = NSMenuItem(title: style.menuTitle, action: #selector(performMenuAction(_:)), keyEquivalent: "")
                item.target = self
                item.image = NSImage(systemSymbolName: style.symbolName, accessibilityDescription: nil)
                item.tag = menuActions.register(request.url)
                menu.addItem(item)
            }
        }

        if !menu.items.isEmpty { menu.addItem(.separator()) }
        let settings = NSMenuItem(title: "打开右键新建…", action: #selector(performMenuAction(_:)), keyEquivalent: "")
        settings.target = self
        settings.image = menuIcon(NSWorkspace.shared.icon(forFile: containingAppURL.path))
        settings.tag = menuActions.register(FileCreationRequest.settingsURL)
        menu.addItem(settings)
        return menu
    }

    private func newFileMenuItem(in directory: URL) -> NSMenuItem {
        let parent = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        let submenu = NSMenu(title: "新建文件")
        submenu.autoenablesItems = false

        for (index, type) in FileType.allCases.enumerated() {
            if index == 4 { submenu.addItem(.separator()) }
            let item = NSMenuItem(title: type.menuTitle, action: #selector(performMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: type.symbolName, accessibilityDescription: nil)
            // Only the tag survives Finder's cross-process menu serialization.
            item.tag = menuActions.register(FileCreationRequest(directory: directory, fileType: type).url)
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    override var toolbarItemName: String { "新建文件" }
    override var toolbarItemToolTip: String { "新建文件，或使用 VS Code / IDEA 打开当前文件夹" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件")!
    }

    @objc private func performMenuAction(_ sender: NSMenuItem) {
        guard let url = menuActions.request(for: sender.tag) else {
            logger.error("Finder menu request expired or missing, tag: \(sender.tag)")
            let alert = NSAlert()
            alert.messageText = "请重新打开右键菜单"
            alert.informativeText = "这个菜单已经过期，请重新右击目标文件夹后再选择操作。"
            alert.addButton(withTitle: "好")
            alert.runModal()
            return
        }
        logger.notice("Handling Finder menu action: \(url.host ?? "unknown", privacy: .public), tag: \(sender.tag)")
        if url.host == "copy" {
            copyPaths(using: url)
        } else {
            openContainingApp(with: url, activate: url.host == "create" || url == FileCreationRequest.settingsURL)
        }
    }

    private func copyPaths(using url: URL) {
        do {
            let request = try CopyPathRequest(url: url)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(request.text, forType: .string) else {
                throw NSError(domain: "RightClick.Copy", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "无法写入剪贴板，请重试。"
                ])
            }
        } catch {
            logger.error("Unable to copy paths: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "无法复制路径"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    private var containingAppURL: URL {
        Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func icon(for editor: EditorApp) -> NSImage? {
        if let cached = editorIcons[editor] { return cached }
        for identifier in editor.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                let image = menuIcon(NSWorkspace.shared.icon(forFile: url.path))
                editorIcons[editor] = image
                return image
            }
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: editor.title)
    }

    private func menuIcon(_ source: NSImage) -> NSImage {
        let image = source.copy() as? NSImage ?? source
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = false
        return image
    }

    private func openContainingApp(with url: URL, activate: Bool) {
        // App.app/Contents/PlugIns/Extension.appex -> App.app.
        // An explicit app URL also avoids accidentally dispatching to another installed build.
        let appURL = containingAppURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { [weak self] _, error in
            if let error {
                self?.logger.error("Unable to open containing app: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "无法打开右键新建"
                    alert.informativeText = "请先打开一次 RightClick 应用，再重试。\n\n\(error.localizedDescription)"
                    alert.addButton(withTitle: "好")
                    alert.runModal()
                }
            }
        }
    }
}
