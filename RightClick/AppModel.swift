import AppKit
import Combine
import FinderSync

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var extensionEnabled = false
    @Published private(set) var lastCreatedFile: URL?
    @Published private(set) var pendingCreations = 0

    private let creationQueue = DispatchQueue(label: "RightClick.FileCreation", qos: .userInitiated)

    init() {
        UserDefaults.standard.register(defaults: [
            "useTemplates": true,
            "revealAfterCreation": true
        ])
        refreshExtensionStatus()
    }

    func refreshExtensionStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    func chooseFolderAndCreate(_ type: FileType) {
        let panel = NSOpenPanel()
        panel.title = "新建\(type.title)"
        panel.message = "选择存放新文件的文件夹。"
        panel.prompt = "在此新建"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        create(FileCreationRequest(directory: directory, fileType: type))
    }

    func create(_ request: FileCreationRequest) {
        let useTemplate = UserDefaults.standard.bool(forKey: "useTemplates")
        let reveal = UserDefaults.standard.bool(forKey: "revealAfterCreation")
        pendingCreations += 1
        creationQueue.async { [weak self] in
            let result = Result { try FileCreator().create(request, useTemplate: useTemplate) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.pendingCreations -= 1
                switch result {
                case .success(let url):
                    self.lastCreatedFile = url
                    if reveal {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                case .failure(let error):
                    self.showError(error, directory: request.directory)
                }
            }
        }
    }

    func openInEditor(_ request: OpenInEditorRequest) {
        Task {
            do {
                try await EditorLauncher().open(request)
            } catch {
                showError(error, title: "无法使用 \(request.editor.title) 打开")
            }
        }
    }

    func showError(_ error: Error, directory: URL? = nil, title: String = "无法新建文件") {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        var message = directory.map { "目标文件夹：\($0.path)\n\n" } ?? ""
        let cocoaError = error as NSError
        if cocoaError.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(cocoaError.code) {
            message += "没有访问这个文件夹的权限。请检查文件夹的共享与权限；如果它位于桌面、文稿或下载中，请在系统设置 → 隐私与安全性 → 文件与文件夹中允许 RightClick 访问。"
        } else {
            message += error.localizedDescription
        }
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
