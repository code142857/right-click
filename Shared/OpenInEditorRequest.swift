import Foundation

/// Carries an allowlisted editor and selected file URLs from the extension to the host.
struct OpenInEditorRequest: Equatable, Sendable {
    let editor: EditorApp
    let items: [URL]

    init(editor: EditorApp, items: [URL]) throws {
        guard !items.isEmpty, items.allSatisfy({
            $0.isFileURL && ($0.host == nil || $0.host == "" || $0.host == "localhost")
                && $0.path.hasPrefix("/") && !$0.path.contains("\0")
        }) else {
            throw RequestError.invalidRequest
        }
        self.editor = editor
        self.items = items.map { URL(fileURLWithPath: $0.path).standardizedFileURL }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = FileCreationRequest.scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "editor", value: editor.rawValue)]
            + items.map { URLQueryItem(name: "path", value: $0.path) }
        return components.url!
    }

    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == FileCreationRequest.scheme,
              components.host == "open",
              components.path.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let query = components.queryItems,
              query.allSatisfy({ $0.name == "editor" || $0.name == "path" }),
              query.filter({ $0.name == "editor" }).count == 1,
              let editorID = query.first(where: { $0.name == "editor" })?.value,
              let editor = EditorApp(rawValue: editorID) else {
            throw RequestError.invalidRequest
        }

        let paths = try query.filter { $0.name == "path" }.map { item -> URL in
            guard let path = item.value, path.hasPrefix("/"), !path.contains("\0") else {
                throw RequestError.invalidRequest
            }
            return URL(fileURLWithPath: path)
        }
        try self.init(editor: editor, items: paths)
    }

    enum RequestError: LocalizedError {
        case invalidRequest

        var errorDescription: String? {
            "打开应用的请求无效。请回到访达，重新选择文件或文件夹。"
        }
    }
}
