import AppKit
import XCTest
@testable import RightClickCore

final class FinderMenuActionStoreTests: XCTestCase {
    @MainActor
    func testFinderReconstructedItemCanResolveRequestWithoutRepresentedObject() throws {
        var store = FinderMenuActionStore()
        let request = FileCreationRequest(directory: URL(fileURLWithPath: "/tmp/中文 & 空格"), fileType: .json)
        let original = NSMenuItem(title: "JSON (.json)", action: nil, keyEquivalent: "")
        original.tag = store.register(request.url)

        // Finder delivers a reconstructed menu item, not the one we returned.
        let callbackItem = NSMenuItem(title: original.title, action: nil, keyEquivalent: "")
        callbackItem.tag = original.tag
        XCTAssertNil(callbackItem.representedObject)
        let resolved = try XCTUnwrap(store.request(for: callbackItem.tag))
        XCTAssertEqual(try FileCreationRequest(url: resolved), request)
    }

    func testOpeningAnotherMenuDoesNotRetargetPreviousActions() throws {
        var store = FinderMenuActionStore()
        let first = FileCreationRequest(directory: URL(fileURLWithPath: "/tmp/first"), fileType: .text)
        let second = FileCreationRequest(directory: URL(fileURLWithPath: "/tmp/second"), fileType: .text)
        let firstTag = store.register(first.url)
        let secondTag = store.register(second.url)
        let settingsTag = store.register(FileCreationRequest.settingsURL)
        XCTAssertEqual(store.request(for: firstTag), first.url)
        XCTAssertEqual(store.request(for: secondTag), second.url)
        XCTAssertEqual(store.request(for: settingsTag), FileCreationRequest.settingsURL)
    }

    func testExpiredTagsNeverRunANewerRequest() {
        var store = FinderMenuActionStore(capacity: 2)
        let first = FileCreationRequest(directory: URL(fileURLWithPath: "/tmp/first"), fileType: .text)
        let expiredTag = store.register(first.url)
        _ = store.register(FileCreationRequest.settingsURL)
        let currentTag = store.register(first.url)
        XCTAssertNotEqual(expiredTag, currentTag)
        XCTAssertNil(store.request(for: expiredTag))
        XCTAssertNil(store.request(for: 0))
        XCTAssertEqual(store.request(for: currentTag), first.url)
    }
}
