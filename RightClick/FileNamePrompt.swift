import AppKit

@MainActor
final class FileNamePrompt: NSObject, NSTextFieldDelegate {
    private let request: FileCreationRequest
    private let alert = NSAlert()
    private let nameField = NSTextField()
    private let validationLabel = NSTextField(wrappingLabelWithString: "")

    init(request: FileCreationRequest) {
        self.request = request
        super.init()
        alert.messageText = "新建\(request.fileType.title)"
        alert.informativeText = "保存到：\(request.directory.path)\n已有同名文件时会自动编号。"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")

        nameField.stringValue = request.fileType.baseName
        nameField.placeholderString = "文件名"
        nameField.font = .systemFont(ofSize: 14)
        nameField.cell?.usesSingleLineMode = true
        nameField.delegate = self
        nameField.setAccessibilityLabel("文件名")
        nameField.setAccessibilityHelp("输入文件名，自动补齐 .\(request.fileType.rawValue) 扩展名。")
        validationLabel.font = .systemFont(ofSize: 11)
        validationLabel.maximumNumberOfLines = 2

        let label = NSTextField(labelWithString: "文件名（自动补齐 .\(request.fileType.rawValue)）")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [label, nameField, validationLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        // NSAlert sizes its window from accessoryView.frame, not from that view's
        // Auto Layout constraints. Give it a frame, then lay out the contents inside.
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 116))
        accessory.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: accessory.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: accessory.bottomAnchor, constant: -6),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 32),
            validationLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            validationLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        accessory.layoutSubtreeIfNeeded()
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = nameField
        updateValidation()
    }

    func run() -> String? {
        // The host calls this only after AppKit finishes launching.
        NSApp.unhide(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.async { [nameField] in nameField.selectText(nil) }
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return nameField.stringValue
    }

    func controlTextDidChange(_ notification: Notification) {
        updateValidation()
    }

    private func updateValidation() {
        do {
            let name = try NewFileName(nameField.stringValue, fileType: request.fileType)
            validationLabel.stringValue = "将创建：\(name.fileName)"
            validationLabel.textColor = .secondaryLabelColor
            alert.buttons.first?.isEnabled = true
        } catch {
            validationLabel.stringValue = error.localizedDescription
            validationLabel.textColor = .systemRed
            alert.buttons.first?.isEnabled = false
        }
    }
}
