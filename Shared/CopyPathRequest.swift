import Foundation

enum PathCopyStyle: String, CaseIterable, Sendable {
    case fullPath = "path"
    case fileName = "name"
    case terminalPath = "terminal"

    var menuTitle: String {
        switch self {
        case .fullPath: return "复制完整路径"
        case .fileName: return "复制文件名"
        case .terminalPath: return "复制终端路径"
        }
    }

    var symbolName: String {
        switch self {
        case .fullPath: return "doc.on.clipboard"
        case .fileName: return "textformat"
        case .terminalPath: return "terminal"
        }
    }
}

struct CopyPathRequest: Equatable, Sendable {
    let style: PathCopyStyle
    let items: [URL]

    init(style: PathCopyStyle, items: [URL]) throws {
        guard !items.isEmpty, items.allSatisfy({
            $0.isFileURL && ($0.host == nil || $0.host == "" || $0.host == "localhost")
                && $0.path.hasPrefix("/") && !$0.path.contains("\0")
        }) else {
            throw RequestError.invalidRequest
        }
        self.style = style
        self.items = items.map { URL(fileURLWithPath: $0.path).standardizedFileURL }
    }

    var text: String {
        switch style {
        case .fullPath:
            return items.map(\.path).joined(separator: "\n")
        case .fileName:
            return items.map(\.lastPathComponent).joined(separator: "\n")
        case .terminalPath:
            // POSIX single quotes work in zsh/bash, including spaces, $, backticks,
            // newlines and embedded apostrophes. Spaces separate multiple arguments.
            return items.map { "'" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
                .joined(separator: " ")
        }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = FileCreationRequest.scheme
        components.host = "copy"
        components.queryItems = [URLQueryItem(name: "style", value: style.rawValue)]
            + items.map { URLQueryItem(name: "path", value: $0.path) }
        return components.url!
    }

    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == FileCreationRequest.scheme,
              components.host == "copy",
              components.path.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let query = components.queryItems,
              query.allSatisfy({ $0.name == "style" || $0.name == "path" }),
              query.filter({ $0.name == "style" }).count == 1,
              let styleName = query.first(where: { $0.name == "style" })?.value,
              let style = PathCopyStyle(rawValue: styleName) else {
            throw RequestError.invalidRequest
        }
        let paths = try query.filter { $0.name == "path" }.map { item -> URL in
            guard let path = item.value, path.hasPrefix("/"), !path.contains("\0") else {
                throw RequestError.invalidRequest
            }
            return URL(fileURLWithPath: path)
        }
        try self.init(style: style, items: paths)
    }

    enum RequestError: LocalizedError {
        case invalidRequest

        var errorDescription: String? {
            "复制路径的请求无效，请重新选择文件或文件夹。"
        }
    }
}
