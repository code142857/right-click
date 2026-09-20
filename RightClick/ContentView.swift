import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @AppStorage("useTemplates") private var useTemplates = true
    @AppStorage("revealAfterCreation") private var revealAfterCreation = true
    @AppStorage("askForFileName") private var askForFileName = true
    private let statusTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    setupCard
                    fileTypes
                    preferences
                }
                .padding(.vertical, 1)
            }
            footer
        }
        .padding(24)
        .frame(width: 660, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(statusTimer) { _ in model.refreshExtensionStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshExtensionStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("右键，就能新建。")
                    .font(.system(size: 26, weight: .bold))
                Text("新建文件，用熟悉的编辑器打开。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(model.extensionEnabled ? "Finder 扩展已启用" : "启用 Finder 扩展", systemImage: model.extensionEnabled ? "checkmark.circle.fill" : "puzzlepiece.extension")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(model.extensionEnabled ? Color.green : Color.primary)
                Spacer()
                Button(model.extensionEnabled ? "扩展设置…" : "打开系统设置…") {
                    model.openExtensionSettings()
                }
                .controlSize(.regular)
            }
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                instruction("1", text: "在系统设置的「访达扩展」中打开「右键新建」。")
                instruction("2", text: "右击 → 新建文件 → 选择格式，输入文件名后创建。")
                instruction("3", text: "一级菜单可用编辑器打开项目，也可复制路径和文件名。")
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var fileTypes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("从一个新文件开始")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(FileType.allCases.count) 种常用格式")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(FileType.allCases) { type in
                    Button {
                        model.chooseFolderAndCreate(type)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: type.symbolName)
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(".\(type.rawValue)")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                Text(type.title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(cardBackground)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.pendingCreations > 0)
                    .help("选择文件夹，新建\(type.menuTitle)")
                    .accessibilityLabel("新建\(type.menuTitle)")
                }
            }
            Text("也可以点击上面的格式，选择文件夹试用。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 14) {
            preferenceToggle(
                "创建前输入文件名",
                detail: "自动补齐扩展名；关闭后使用默认名称直接创建。",
                isOn: $askForFileName
            )
            Divider()
            preferenceToggle(
                "使用初始模板",
                detail: "为 JSON、Markdown、XML、HTML 和 Shell 添加起始内容。",
                isOn: $useTemplates
            )
            Divider()
            preferenceToggle(
                "创建后在访达中选中",
                detail: "选中后按回车，即可修改文件名。",
                isOn: $revealAfterCreation
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if model.pendingCreations > 0 {
                ProgressView().controlSize(.small)
                Text("正在创建…")
            } else if let url = model.lastCreatedFile {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("已创建 \(url.lastPathComponent)")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("查看") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .buttonStyle(.link)
            } else {
                Image(systemName: "doc.on.doc")
                Text("重名自动编号，已有文件始终保留。")
            }
            Spacer(minLength: 8)
            Button("完成") { NSApp.keyWindow?.close() }
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))
    }

    private func instruction(_ number: String, text: String) -> some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 19, height: 19)
                .background(Circle().fill(Color.primary.opacity(0.06)))
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func preferenceToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}
