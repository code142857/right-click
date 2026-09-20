import Foundation

/// Finder rebuilds NSMenuItems across process boundaries and does not preserve
/// representedObject. Keep request snapshots in the extension, keyed by the tag.
struct FinderMenuActionStore {
    private var requests: [Int: URL] = [:]
    private var nextTag = 1
    private let capacity: Int

    init(capacity: Int = 512) {
        self.capacity = max(1, capacity)
    }

    mutating func register(_ request: URL) -> Int {
        let tag = nextTag
        nextTag += 1
        requests[tag] = request
        // Retain several recent menus: Finder can request another window's menu
        // before delivering a click on an older one. Never reuse a tag.
        requests.removeValue(forKey: tag - capacity)
        return tag
    }

    func request(for tag: Int) -> URL? {
        requests[tag]
    }
}
