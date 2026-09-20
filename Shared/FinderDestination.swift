import Foundation

enum FinderDestination {
    enum Context {
        case container
        case items
        case sidebar
        case toolbar
    }

    static func directory(for context: Context, target: URL?, selection: [URL]) -> URL? {
        switch context {
        case .container, .sidebar, .toolbar:
            // A background click can still have an old selection. Never use it here.
            return target.flatMap { isFolder($0) ? $0 : nil }
        case .items:
            if selection.count == 1, let selected = selection.first, isFolder(selected) {
                return selected
            }

            if !selection.isEmpty {
                guard selection.allSatisfy(\.isFileURL) else { return nil }
                let parents = Set(selection.map { $0.deletingLastPathComponent().standardizedFileURL })
                // Search results can contain items from unrelated folders.
                guard parents.count == 1, let parent = parents.first, isFolder(parent) else {
                    return nil
                }
                return parent
            }

            return target.flatMap { isFolder($0) ? $0 : nil }
        }
    }

    static func itemsToOpen(for context: Context, target: URL?, selection: [URL]) -> [URL] {
        switch context {
        case .items:
            // Editors can open individual files and selections spanning different folders.
            let items = selection.isEmpty ? target.map { [$0] } ?? [] : selection
            return items.allSatisfy(\.isFileURL) ? items : []
        case .container, .sidebar, .toolbar:
            // Right-clicking empty space must open the visible folder, not an old selection.
            return target.flatMap { isFolder($0) ? [$0] : nil } ?? []
        }
    }

    private static func isFolder(_ url: URL) -> Bool {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else {
            return false
        }
        return values.isDirectory == true && values.isPackage != true
    }
}
