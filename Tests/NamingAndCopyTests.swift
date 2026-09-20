import Foundation
import XCTest
@testable import RightClickCore

final class NamingAndCopyTests: TemporaryDirectoryTestCase {
    func testNamesReceiveExactlyOneSelectedExtension() throws {
        for input in ["config", "config.json", "config.JSON", "  config.json  "] {
            XCTAssertEqual(try NewFileName(input, fileType: .json).fileName, "config.json")
        }
        XCTAssertEqual(try NewFileName("config.prod", fileType: .json).fileName, "config.prod.json")
        XCTAssertEqual(try NewFileName("我的笔记 📒", fileType: .markdown).fileName, "我的笔记 📒.md")
        XCTAssertEqual(try NewFileName(".hidden", fileType: .text).fileName, ".hidden.txt")
    }

    func testInvalidNamesAreRejectedBeforeAnyFileIsWritten() throws {
        let request = FileCreationRequest(directory: directory, fileType: .json)
        for input in ["", "   ", ".", "..", ".json", "../outside", "/tmp/outside", "a/b", "a:b", "a\0b", "a\nb", String(repeating: "a", count: 300)] {
            XCTAssertThrowsError(try FileCreator().create(request, name: input), input)
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testCustomNamePreservesTemplatesAndAvoidsOverwrites() throws {
        let existing = try makeFile("config.json")
        let request = FileCreationRequest(directory: directory, fileType: .json)
        let first = try FileCreator().create(request, name: "config.json")
        let second = try FileCreator().create(request, useTemplate: false, name: "config")
        XCTAssertEqual(first.lastPathComponent, "config 2.json")
        XCTAssertEqual(second.lastPathComponent, "config 3.json")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing content")
        XCTAssertEqual((try JSONSerialization.jsonObject(with: Data(contentsOf: first)) as? [String: String])?.count, 0)
        XCTAssertTrue(try Data(contentsOf: second).isEmpty)
    }

    func testCustomNameDoesNotReplaceAConflictingDirectory() throws {
        _ = try makeDirectory("notes.md")
        let file = try FileCreator().create(FileCreationRequest(directory: directory, fileType: .markdown), name: "notes")
        XCTAssertEqual(file.lastPathComponent, "notes 2.md")
    }

    func testCopyFormatsPreserveSelectionOrder() throws {
        let first = try makeFile("中文 & report.txt")
        let second = try makeDirectory("Project")
        XCTAssertEqual(try CopyPathRequest(style: .fullPath, items: [first, second]).text, "\(first.path)\n\(second.path)")
        XCTAssertEqual(try CopyPathRequest(style: .fileName, items: [first, second]).text, "中文 & report.txt\nProject")
    }

    func testCopyRequestRoundTripsSpecialPathsAndEveryStyle() throws {
        let file = try makeFile("中文 ' & #100% + ?.txt")
        let folder = try makeDirectory("目录 📁")
        for style in PathCopyStyle.allCases {
            let request = try CopyPathRequest(style: style, items: [file, folder])
            XCTAssertEqual(try CopyPathRequest(url: request.url), request)
        }
    }

    func testTerminalPathsRoundTripThroughShellAsLiteralArguments() throws {
        let names = ["simple.txt", "中文 空格.txt", "it's a file.txt", "$HOME `printf injected` $(printf injected).txt", "semi;colon & star*.txt", "line\nbreak.txt"]
        let files = try names.map { try makeFile($0) }
        let request = try CopyPathRequest(style: .terminalPath, items: files)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Only fixed test fixtures are used here. The result must be literal arguments.
        process.arguments = ["-c", "printf '%s\\0' " + request.text]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(decoding: output, as: UTF8.self), files.map { $0.path + "\0" }.joined())
    }

    func testCopyRejectsMalformedRequestsAndNonlocalItems() throws {
        let invalid = [
            "https://copy?style=path&path=/tmp",
            "rightclick-newfile://open?style=path&path=/tmp",
            "rightclick-newfile://copy?style=unknown&path=/tmp",
            "rightclick-newfile://copy?style=path&style=name&path=/tmp",
            "rightclick-newfile://copy?style=path",
            "rightclick-newfile://copy?style=path&path=relative",
            "rightclick-newfile://copy?style=path&path=/tmp%00bad",
            "rightclick-newfile://copy?style=path&path=/tmp&extra=value",
            "rightclick-newfile://copy?style=path&path=/tmp#fragment"
        ]
        for value in invalid {
            XCTAssertThrowsError(try CopyPathRequest(url: XCTUnwrap(URL(string: value))), value)
        }
        XCTAssertThrowsError(try CopyPathRequest(style: .fullPath, items: []))
        XCTAssertThrowsError(try CopyPathRequest(style: .fullPath, items: [URL(string: "https://example.com")!]))
        XCTAssertThrowsError(try CopyPathRequest(style: .fullPath, items: [URL(string: "file://remote/tmp")!]))
    }

    func testCopyUsesMenuSnapshotEvenWhenAnotherMenuIsCreated() throws {
        let first = try makeFile("first.txt")
        let second = try makeFile("second.txt")
        var store = FinderMenuActionStore()
        let tag = store.register(try CopyPathRequest(style: .fileName, items: [first]).url)
        _ = store.register(try CopyPathRequest(style: .fileName, items: [second]).url)
        let url = try XCTUnwrap(store.request(for: tag))
        XCTAssertEqual(try CopyPathRequest(url: url).text, "first.txt")
    }
}
