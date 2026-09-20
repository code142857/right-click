import Foundation

struct FileCreator: Sendable {
    /// Exclusive creation prevents both overwrites and races between repeated clicks.
    /// Do not combine .withoutOverwriting with .atomic: Foundation disallows that pair.
    func create(_ request: FileCreationRequest, useTemplate: Bool = true, name: String? = nil) throws -> URL {
        let directory = request.directory
        guard directory.isFileURL,
              try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw CreationError.notDirectory
        }

        let type = request.fileType
        let baseName = try NewFileName(name ?? type.baseName, fileType: type).baseName
        let data = Data((useTemplate ? type.template : "").utf8)

        for index in 1...10_000 {
            let suffix = index == 1 ? "" : " \(index)"
            let fileURL = directory.appendingPathComponent("\(baseName)\(suffix).\(type.rawValue)")
            do {
                try data.write(to: fileURL, options: .withoutOverwriting)
                return fileURL
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                continue
            }
        }

        throw CreationError.tooManyFiles
    }

    enum CreationError: LocalizedError {
        case notDirectory
        case tooManyFiles

        var errorDescription: String? {
            switch self {
            case .notDirectory:
                return "请选择一个实际的文件夹，然后重试。"
            case .tooManyFiles:
                return "这个文件夹中已有太多同名文件，请先重命名部分文件。"
            }
        }
    }
}
