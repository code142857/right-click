import Foundation
import XCTest
@testable import RightClickCore

final class OpenInEditorRequestTests: TemporaryDirectoryTestCase {
    func testSelectedFilesAndFoldersRoundTripWithoutChangingPaths() throws {
        let file = try makeFile("中文 & #100% + ?.md")
        let folder = try makeDirectory("项目 📁")
        for editor in EditorApp.allCases {
            let request = try OpenInEditorRequest(editor: editor, items: [file, folder])
            let decoded = try OpenInEditorRequest(url: request.url)
            XCTAssertEqual(decoded, request)
            XCTAssertEqual(decoded.items.map(\.path), [file.path, folder.path])
        }
    }

    func testInvalidEditorRequestsAreRejected() throws {
        let invalid = [
            "https://open?editor=vscode&path=/tmp",
            "rightclick-newfile://create?editor=vscode&path=/tmp",
            "rightclick-newfile://open/extra?editor=vscode&path=/tmp",
            "rightclick-newfile://open?editor=terminal&path=/tmp",
            "rightclick-newfile://open?editor=/bin/sh&path=/tmp",
            "rightclick-newfile://open?editor=vscode&editor=idea&path=/tmp",
            "rightclick-newfile://open?editor=vscode",
            "rightclick-newfile://open?path=/tmp",
            "rightclick-newfile://open?editor=vscode&path=relative",
            "rightclick-newfile://open?editor=vscode&path=/tmp&path",
            "rightclick-newfile://open?editor=vscode&path=/tmp%00bad",
            "rightclick-newfile://open?editor=vscode&path=/tmp&command=echo",
            "rightclick-newfile://open?editor=vscode&path=/tmp#fragment",
            "rightclick-newfile://user@open?editor=vscode&path=/tmp",
            "rightclick-newfile://open:42?editor=vscode&path=/tmp"
        ]
        for value in invalid {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertThrowsError(try OpenInEditorRequest(url: url), value)
        }
    }

    func testRequestsOnlyAcceptNonemptyLocalFileSelections() {
        XCTAssertThrowsError(try OpenInEditorRequest(editor: .vscode, items: []))
        XCTAssertThrowsError(try OpenInEditorRequest(editor: .vscode, items: [URL(string: "https://example.com")!]))
        XCTAssertThrowsError(try OpenInEditorRequest(editor: .idea, items: [URL(string: "file://other-host/tmp")!]))
    }

    func testBackgroundAndSidebarOpenTargetInsteadOfOldSelection() throws {
        let selected = try makeDirectory("old selection")
        for context in [FinderDestination.Context.container, .sidebar, .toolbar] {
            XCTAssertEqual(FinderDestination.itemsToOpen(for: context, target: directory, selection: [selected]), [directory!])
        }
    }

    func testItemMenuOpensSelectedFileInsteadOfItsContainingFolder() throws {
        let file = try makeFile("main.swift")
        XCTAssertEqual(FinderDestination.itemsToOpen(for: .items, target: directory, selection: [file]), [file])
    }

    func testMultipleFilesFromDifferentFoldersCanBeOpenedTogether() throws {
        let first = try makeFile("first.txt")
        let other = try makeDirectory("other")
        let second = other.appendingPathComponent("second.txt")
        try Data().write(to: second)
        let selection = [first, second]
        XCTAssertNil(FinderDestination.directory(for: .items, target: directory, selection: selection))
        XCTAssertEqual(FinderDestination.itemsToOpen(for: .items, target: directory, selection: selection), selection)
    }

    func testItemMenuOpensSelectedFolders() throws {
        let first = try makeDirectory("first")
        let second = try makeDirectory("second")
        XCTAssertEqual(FinderDestination.itemsToOpen(for: .items, target: directory, selection: [first, second]), [first, second])
    }

    func testVirtualLocationsDoNotBecomeEditorTargets() {
        let virtual = URL(string: "x-finder:search")!
        XCTAssertTrue(FinderDestination.itemsToOpen(for: .container, target: virtual, selection: []).isEmpty)
        XCTAssertTrue(FinderDestination.itemsToOpen(for: .items, target: directory, selection: [virtual]).isEmpty)
        XCTAssertTrue(FinderDestination.itemsToOpen(for: .container, target: nil, selection: []).isEmpty)
    }
}
