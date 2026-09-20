import Foundation

struct NewFileName: Equatable, Sendable {
    let baseName: String
    let fileType: FileType

    var fileName: String { "\(baseName).\(fileType.rawValue)" }

    init(_ input: String, fileType: FileType) throws {
        guard !input.unicodeScalars.contains(where: {
            CharacterSet.controlCharacters.contains($0) || $0 == "/" || $0 == ":"
        }) else {
            throw ValidationError.invalidCharacters
        }
        var name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ValidationError.emptyName }
        guard name != ".", name != ".." else { throw ValidationError.reservedName }

        let suffix = ".\(fileType.rawValue)"
        if name.lowercased().hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw ValidationError.emptyName }
        guard "\(name)\(suffix)".utf8.count <= 255 else { throw ValidationError.tooLong }
        self.baseName = name
        self.fileType = fileType
    }

    enum ValidationError: LocalizedError {
        case emptyName
        case invalidCharacters
        case reservedName
        case tooLong

        var errorDescription: String? {
            switch self {
            case .emptyName: return "请输入文件名。"
            case .invalidCharacters: return "文件名不能包含 /、:、换行或控制字符。"
            case .reservedName: return "不能使用 . 或 .. 作为文件名。"
            case .tooLong: return "文件名过长，请缩短后重试。"
            }
        }
    }
}
