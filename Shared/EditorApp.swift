import Foundation

/// A fixed list of editors keeps Finder requests independent of executable paths.
enum EditorApp: String, CaseIterable, Identifiable, Sendable {
    case vscode
    case idea

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vscode: return "VS Code"
        case .idea: return "IDEA"
        }
    }

    var menuTitle: String { "使用 \(title) 打开" }

    var bundleIdentifiers: [String] {
        switch self {
        case .vscode: return ["com.microsoft.VSCode"]
        case .idea: return ["com.jetbrains.intellij", "com.jetbrains.intellij.ce"]
        }
    }

    var applicationNames: [String] {
        switch self {
        case .vscode: return ["Visual Studio Code.app"]
        case .idea: return ["IntelliJ IDEA.app", "IntelliJ IDEA CE.app", "IntelliJ IDEA Ultimate.app"]
        }
    }
}
