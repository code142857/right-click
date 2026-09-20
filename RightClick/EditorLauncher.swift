import AppKit

@MainActor
struct EditorLauncher {
    func applicationURL(for editor: EditorApp) -> URL? {
        // Launch Services also finds apps installed by JetBrains Toolbox or moved by the user.
        for identifier in editor.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // A freshly installed app may not have registered with Launch Services yet.
        let folders = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true)
        ]
        for folder in folders {
            for name in editor.applicationNames {
                let url = folder.appendingPathComponent(name, isDirectory: true)
                if let identifier = Bundle(url: url)?.bundleIdentifier,
                   editor.bundleIdentifiers.contains(identifier) {
                    return url
                }
            }
        }
        return nil
    }

    func open(_ request: OpenInEditorRequest) async throws {
        guard let application = applicationURL(for: request.editor) else {
            throw OpenError.notInstalled(request.editor)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Passing URL objects directly preserves filenames and never evaluates shell input.
        _ = try await NSWorkspace.shared.open(request.items, withApplicationAt: application, configuration: configuration)
    }

    enum OpenError: LocalizedError {
        case notInstalled(EditorApp)

        var errorDescription: String? {
            switch self {
            case .notInstalled(.vscode):
                return "没有找到 VS Code。请安装 Visual Studio Code 并打开一次，然后重试。"
            case .notInstalled(.idea):
                return "没有找到 IDEA。请安装 IntelliJ IDEA 或 Community Edition 并打开一次，然后重试。"
            }
        }
    }
}
