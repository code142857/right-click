import Foundation

/// The single source of truth for the Finder menu, the settings window and file contents.
enum FileType: String, CaseIterable, Identifiable, Sendable {
    case text = "txt"
    case markdown = "md"
    case json
    case csv
    case yaml
    case xml
    case html
    case css
    case javascript = "js"
    case typescript = "ts"
    case python = "py"
    case shell = "sh"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "文本文件"
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .csv: return "CSV 表格"
        case .yaml: return "YAML"
        case .xml: return "XML"
        case .html: return "HTML 页面"
        case .css: return "CSS 样式"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .python: return "Python"
        case .shell: return "Shell 脚本"
        }
    }

    var menuTitle: String { "\(title) (.\(rawValue))" }

    var baseName: String {
        switch self {
        case .text: return "新建文本"
        case .markdown: return "新建文档"
        case .csv: return "新建表格"
        case .html: return "新建页面"
        case .css: return "新建样式"
        case .javascript, .typescript, .python, .shell: return "新建脚本"
        default: return "新建文件"
        }
    }

    var symbolName: String {
        switch self {
        case .text: return "doc.text"
        case .markdown: return "text.alignleft"
        case .json, .yaml, .xml: return "curlybraces"
        case .csv: return "tablecells"
        case .html: return "globe"
        case .css: return "paintbrush.pointed"
        case .javascript, .typescript: return "chevron.left.forwardslash.chevron.right"
        case .python, .shell: return "terminal"
        }
    }

    var template: String {
        switch self {
        case .json:
            return "{\n}\n"
        case .markdown:
            return "# 新建文档\n\n"
        case .xml:
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n</root>\n"
        case .html:
            return """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>新建页面</title>
            </head>
            <body>
            </body>
            </html>

            """
        case .shell:
            return "#!/bin/zsh\n\n"
        default:
            return ""
        }
    }
}
