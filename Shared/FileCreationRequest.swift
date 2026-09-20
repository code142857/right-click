import Foundation

/// Only predefined types and an absolute directory path cross the extension boundary.
/// URLComponents preserves spaces, Unicode, '#', '&' and '%' in Finder paths.
struct FileCreationRequest: Equatable, Sendable {
    static let scheme = "rightclick-newfile"
    static let settingsURL = URL(string: "\(scheme)://settings")!

    let directory: URL
    let fileType: FileType

    init(directory: URL, fileType: FileType) {
        self.directory = directory.appendingPathComponent("", isDirectory: true).standardizedFileURL
        self.fileType = fileType
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "create"
        components.queryItems = [
            URLQueryItem(name: "directory", value: directory.path),
            URLQueryItem(name: "type", value: fileType.rawValue)
        ]
        // The scheme and host are constant, and URLComponents encodes both values.
        return components.url!
    }

    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme,
              components.host == "create",
              components.path.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let items = components.queryItems,
              items.count == 2,
              let path = items.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/"),
              !path.contains("\0"),
              let typeName = items.first(where: { $0.name == "type" })?.value,
              let type = FileType(rawValue: typeName) else {
            throw RequestError.invalidRequest
        }
        self.init(directory: URL(fileURLWithPath: path, isDirectory: true), fileType: type)
    }

    enum RequestError: LocalizedError {
        case invalidRequest

        var errorDescription: String? {
            "新建文件请求无效。请回到访达，重新选择文件夹和文件类型。"
        }
    }
}
