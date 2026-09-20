import Foundation
import XCTest
@testable import RightClickCore

class TemporaryDirectoryTestCase: XCTestCase {
    var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RightClickTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func makeDirectory(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func makeFile(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("existing content".utf8).write(to: url)
        return url
    }
}

final class FileCreatorTests: TemporaryDirectoryTestCase {
    private let creator = FileCreator()

    func testCreatesEverySupportedFormatWithUTF8Contents() throws {
        for type in FileType.allCases {
            let url = try creator.create(FileCreationRequest(directory: directory, fileType: type))
            XCTAssertEqual(url.pathExtension, type.rawValue)
            XCTAssertNoThrow(try String(contentsOf: url, encoding: .utf8))
            XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, directory.standardizedFileURL)
            if type == .json {
                let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
                XCTAssertEqual((object as? [String: String])?.count, 0)
            }
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 12)
    }

    func testDisablingTemplatesCreatesEmptyFiles() throws {
        for type in [FileType.json, .markdown, .html, .xml, .shell] {
            let url = try creator.create(FileCreationRequest(directory: directory, fileType: type), useTemplate: false)
            XCTAssertEqual(try Data(contentsOf: url).count, 0)
        }
    }

    func testRepeatedCreationNumbersNamesAndPreservesExistingContents() throws {
        let existing = try makeFile("新建文件.json")
        let second = try makeFile("新建文件 2.json")
        let created = try creator.create(FileCreationRequest(directory: directory, fileType: .json))
        XCTAssertEqual(created.lastPathComponent, "新建文件 3.json")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing content")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "existing content")
    }

    func testDirectoryWithSameNameIsNotReplaced() throws {
        let existing = try makeDirectory("新建文本.txt")
        let created = try creator.create(FileCreationRequest(directory: directory, fileType: .text))
        XCTAssertEqual(created.lastPathComponent, "新建文本 2.txt")
        XCTAssertTrue(try existing.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
    }

    func testSymbolicLinkWithSameNameDoesNotOverwriteItsTarget() throws {
        let existing = try makeFile("original.txt")
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("新建文本.txt"), withDestinationURL: existing
        )
        let created = try creator.create(FileCreationRequest(directory: directory, fileType: .text))
        XCTAssertEqual(created.lastPathComponent, "新建文本 2.txt")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing content")
    }

    func testConcurrentCreationDoesNotLoseOrOverwriteFiles() throws {
        let request = FileCreationRequest(directory: directory, fileType: .json)
        let results = ConcurrentResults()
        DispatchQueue.concurrentPerform(iterations: 24) { _ in
            results.append(Result { try FileCreator().create(request) })
        }
        let urls = try results.values.map { try $0.get() }
        XCTAssertEqual(Set(urls).count, 24)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 24)
        for url in urls {
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(contentsOf: url)))
        }
    }

    func testRegularFileCannotBeUsedAsDirectory() throws {
        let file = try makeFile("file.txt")
        XCTAssertThrowsError(try creator.create(FileCreationRequest(directory: file, fileType: .text)))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "existing content")
    }

    func testDeletedDirectoryIsNotSilentlyRecreated() throws {
        let missing = directory.appendingPathComponent("missing", isDirectory: true)
        XCTAssertThrowsError(try creator.create(FileCreationRequest(directory: missing, fileType: .text)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testReadOnlyDirectoryReportsError() throws {
        let readOnly = try makeDirectory("read-only")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path) }
        XCTAssertThrowsError(try creator.create(FileCreationRequest(directory: readOnly, fileType: .text)))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: readOnly.path).isEmpty)
    }

    func testCreationThroughURLRequestPreservesSpecialCharactersInPath() throws {
        let special = try makeDirectory("中文 & 空格 #100% + ? 📁")
        let original = FileCreationRequest(directory: special, fileType: .markdown)
        let decoded = try FileCreationRequest(url: original.url)
        let created = try creator.create(decoded)
        XCTAssertEqual(created.deletingLastPathComponent().standardizedFileURL, special.standardizedFileURL)
        XCTAssertEqual(created.lastPathComponent, "新建文档.md")
    }
}

private final class ConcurrentResults: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Result<URL, Error>] = []

    func append(_ value: Result<URL, Error>) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }

    var values: [Result<URL, Error>] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

final class FileCreationRequestTests: XCTestCase {
    func testURLRoundTripForEveryType() throws {
        for type in FileType.allCases {
            let original = FileCreationRequest(directory: URL(fileURLWithPath: "/tmp/我的 文档&100%#?+"), fileType: type)
            XCTAssertEqual(try FileCreationRequest(url: original.url), original)
        }
    }

    func testMalformedRequestsAreRejected() throws {
        let invalid = [
            "https://create?directory=/tmp&type=json",
            "rightclick-newfile://other?directory=/tmp&type=json",
            "rightclick-newfile://create/path?directory=/tmp&type=json",
            "rightclick-newfile://create?directory=relative&type=json",
            "rightclick-newfile://create?directory=/tmp&type=unknown",
            "rightclick-newfile://create?directory=/tmp&type=../json",
            "rightclick-newfile://create?directory=/tmp",
            "rightclick-newfile://create?directory=/tmp&type=json&type=txt",
            "rightclick-newfile://create?directory=/tmp&directory=/etc",
            "rightclick-newfile://create?directory=/tmp%00bad&type=txt",
            "rightclick-newfile://create?directory=/tmp&type=txt#fragment",
            "rightclick-newfile://user@create?directory=/tmp&type=txt"
        ]
        for value in invalid {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertThrowsError(try FileCreationRequest(url: url), value)
        }
    }
}

final class FinderDestinationTests: TemporaryDirectoryTestCase {
    func testBackgroundClickIgnoresPreviouslySelectedFolder() throws {
        let selected = try makeDirectory("selected")
        XCTAssertEqual(FinderDestination.directory(for: .container, target: directory, selection: [selected]), directory)
    }

    func testClickingOneFolderCreatesInsideIt() throws {
        let selected = try makeDirectory("selected")
        XCTAssertEqual(FinderDestination.directory(for: .items, target: directory, selection: [selected]), selected)
    }

    func testClickingFilesUsesTheirContainingFolder() throws {
        let first = try makeFile("first.txt")
        let second = try makeFile("second.txt")
        XCTAssertEqual(
            FinderDestination.directory(for: .items, target: first, selection: [first, second])?.standardizedFileURL,
            directory.standardizedFileURL
        )
    }

    func testMixedSearchResultsDoNotChooseAnArbitraryFolder() throws {
        let other = try makeDirectory("other")
        let first = try makeFile("first.txt")
        let second = other.appendingPathComponent("second.txt")
        try Data().write(to: second)
        XCTAssertNil(FinderDestination.directory(for: .items, target: directory, selection: [first, second]))
    }

    func testSidebarAndToolbarUseTargetInsteadOfSelection() throws {
        let selected = try makeDirectory("selected")
        for context in [FinderDestination.Context.sidebar, .toolbar] {
            XCTAssertEqual(FinderDestination.directory(for: context, target: directory, selection: [selected]), directory)
        }
    }

    func testPackagesAreNotTreatedAsUserFolders() throws {
        let app = try makeDirectory("Example.app")
        XCTAssertEqual(
            FinderDestination.directory(for: .items, target: directory, selection: [app])?.standardizedFileURL,
            directory.standardizedFileURL
        )
        XCTAssertNil(FinderDestination.directory(for: .container, target: app, selection: []))
    }

    func testVirtualLocationsAndMissingTargetsHaveNoDestination() {
        XCTAssertNil(FinderDestination.directory(for: .container, target: URL(string: "x-finder:search"), selection: []))
        XCTAssertNil(FinderDestination.directory(for: .container, target: nil, selection: []))
    }
}
