# 右键新建 · RightClick

一个原生 macOS 小工具，为访达（Finder）的右键菜单添加「新建文件」，并可直接使用 VS Code、IDEA 打开文件或项目。支持 macOS 13 及以上，无第三方依赖。

## 使用

1. 用 Xcode 打开 `RightClick.xcodeproj`，选择 **RightClick → My Mac**，按 `⌘R` 运行。
2. 在应用中点击「打开系统设置…」，启用「右键新建」的 **Finder / 访达扩展**。
   - macOS 15 及较新系统：系统设置 → 通用 → 登录项与扩展 → 扩展 → 访达。
   - macOS 13 / 14：系统设置 → 隐私与安全性 → 扩展 → 访达扩展。
   - 系统版本不同，入口文字可能略有不同，优先使用应用内按钮。
3. 回到访达，打开一个普通文件夹，在空白处右击，选择 **新建文件 → JSON / 文本文件 / Markdown …**。
4. 新文件会被选中，按回车即可改名。
5. 右键一级菜单还有 **使用 VS Code 打开**、**使用 IDEA 打开** 和 **打开右键新建…**，无需进入子菜单。

右击空白处时，编辑器打开当前文件夹；右击文件或文件夹时，打开选中项，支持多选。VS Code 和 IntelliJ IDEA / Community Edition 会按系统登记的安装位置自动识别，也支持 `~/Applications` 中的安装，无需配置 `code` 或 `idea` 命令。未安装时会提示安装对应应用。

也可以点击主窗口中的格式卡片，选择文件夹直接创建文件。设置完成后可关闭窗口；下次从右键菜单创建时，主应用会在后台自动启动。

长期使用时，建议把构建出的 `RightClick.app` 放入 `/Applications`（应用程序），从那里打开一次并启用扩展，避免 Xcode 清理构建目录后找不到应用。不要单独移动 `.appex`。

## 功能

- 支持 TXT、Markdown、JSON、CSV、YAML、XML、HTML、CSS、JavaScript、TypeScript、Python、Shell，共 12 种格式。
- 右击空白处：创建到当前目录，忽略此前遗留的选中项。
- 右击单个文件夹：创建到该文件夹中。
- 右击文件、同一目录中的多个项目：创建到这些项目所在的目录。
- 多选来自不同目录的搜索结果时隐藏「新建文件」，避免误选保存位置；仍可使用编辑器打开这些选中项。
- 一级菜单直接提供「使用 VS Code 打开」「使用 IDEA 打开」和「打开右键新建…」，使用对应应用的原生彩色图标。
- 在访达「自定工具栏」中也可以添加「新建文件」按钮。
- 重名自动使用 `新建文件 2.json`、`新建文件 3.json` 等名称，不覆盖已有文件、文件夹或符号链接。
- JSON 默认是有效的空对象；Markdown、XML、HTML、Shell 有起始模板。关闭「使用初始模板」可创建完全空白的文件。
- 支持中文、空格和特殊字符路径；支持本地磁盘和已挂载的外接／网络卷，实际写入仍受目录权限限制。
- 可关闭「创建后在访达中选中」。所有文本使用 UTF-8。

## 命令行构建与测试

需要完整 Xcode，并让 `xcode-select` 指向该 Xcode。

```bash
# 构建 macOS 通用应用（Apple Silicon + Intel）
./Scripts/build.sh

# 打开构建结果
open .build/xcode/Build/Products/Release/RightClick.app

# 运行核心逻辑测试
swift test
```

工程通过 `Configuration/Signing.xcconfig` 使用本机已有的 **Apple Development** 证书，主应用和 Finder 扩展的 Debug / Release 共用同一签名配置：

- 证书：`Apple Development: 285134371@qq.com (8A948M4ZRH)`
- 开发团队：`8W6G366YWZ`（来自证书的 OU 字段）

配置中只保存证书名称和团队 ID，私钥由本机钥匙串管理。更换开发机器或续签证书时，更新该配置即可。正式分发需配置自己的 Bundle Identifier、Developer ID 签名与公证。

`Scripts/build.sh` 会把额外参数传给 `xcodebuild`，例如：

```bash
./Scripts/build.sh CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=你的团队ID
```

## 工程结构

```text
RightClick/             主应用、原生 SwiftUI 设置页、编辑器发现与启动、错误提示
RightClickFinder/       Finder Sync 扩展与右键菜单
Shared/                 文件类型、编辑器定义、请求编解码、目标判断、文件创建
Configuration/          主应用和扩展共用的本机证书签名配置
Tests/                  核心逻辑测试（由 Swift Package 运行）
Scripts/                构建脚本、可复现的图标生成脚本
RightClick.xcodeproj/   主应用 + 嵌入式 Finder 扩展，已共享 scheme
```

Finder 扩展运行在沙盒中，提供菜单并把请求交给包含它的应用。主应用通过 `NSWorkspace` 接收固定格式的 URL 请求，使用 Foundation 创建文件，或通过 `NSWorkspace.open` 将选中的文件 URL 交给指定编辑器；不需要 AppleScript、辅助功能权限、完全磁盘访问权限或 shell 命令。打开请求仅接受预定义的 VS Code / IDEA，不接受任意可执行文件或命令行参数。

主应用采用非沙盒配置，用于本机运行或 Developer ID 分发。访问桌面、文稿、下载和部分磁盘时仍遵守 macOS 的隐私授权。这个工程没有采用 Mac App Store 所需的主应用沙盒／安全书签授权流程。

写入使用 `Data.WritingOptions.withoutOverwriting` 进行排他创建，避免「先检查不存在、再写入」带来的并发覆盖。磁盘操作放在后台串行队列上，不阻塞设置窗口。菜单生成时固定目标目录，避免点击后选区变化。

Finder 会跨进程重建菜单项，不能依赖 `NSMenuItem.representedObject` 传递请求。扩展使用唯一的 `tag` 关联本地请求快照，并保留多个最近菜单的请求，避免菜单重建后点击失效或目标目录串位。主应用收到冷启动的设置请求时，会等 AppKit 完成启动后再显示并激活窗口。

新增文件类型只需修改 `Shared/FileType.swift` 中的枚举、名称、图标和模板，Finder 菜单与设置页的格式卡片共用该定义。

## 排查右键菜单没有出现

1. 确认打开过完整的 `RightClick.app`，并且系统设置已启用对应的 Finder 扩展。
2. 使用实际文件夹测试，例如自己创建的测试文件夹；「最近使用」等虚拟视图没有可写的目录背景。
3. 在扩展设置中关闭后重新打开「右键新建」，重新打开访达窗口。
4. 如有多个构建版本，保留一个稳定位置的应用并从该位置打开。查看系统注册的版本：

   ```bash
   pluginkit -m -A -D -i com.rightclick.app.finder
   ```

5. 重新签名或升级后若仍显示旧菜单，关闭后重新打开「右键新建」扩展，确保当前应用及扩展都使用 `Configuration/Signing.xcconfig` 中的同一证书。
6. 创建时报权限错误时，检查该文件夹的读写权限，以及「系统设置 → 隐私与安全性 → 文件与文件夹」中 RightClick 的授权。

扩展启用开关必须由用户在 macOS 中操作，应用不会自动更改该开关或重启访达。
