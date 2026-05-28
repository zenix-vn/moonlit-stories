import Foundation

// MARK: - APICache
// Thread-safe in-memory TTL cache for API responses.
// Uses NSCache for automatic memory-pressure eviction.

final class APICache: @unchecked Sendable {
    static let shared = APICache()

    private final class Entry {
        let data: Any
        let expiresAt: Date
        init(data: Any, ttl: TimeInterval) {
            self.data = data
            self.expiresAt = Date().addingTimeInterval(ttl)
        }
        var isExpired: Bool { Date() > expiresAt }
    }

    private let cache = NSCache<NSString, Entry>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 128
    }

    // MARK: - Public API

    func get<T>(_ key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = cache.object(forKey: key as NSString) else { return nil }
        if entry.isExpired {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        return entry.data as? T
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(Entry(data: value as AnyObject, ttl: ttl), forKey: key as NSString)
    }

    func invalidate(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeObject(forKey: key as NSString)
    }

    /// Invalidate all entries whose key has the given prefix
    func invalidatePrefix(_ prefix: String) {
        // NSCache doesn't expose its keys; we track prefixed keys manually
        lock.lock()
        defer { lock.unlock() }
        for key in trackedKeys where key.hasPrefix(prefix) {
            cache.removeObject(forKey: key as NSString)
        }
        trackedKeys = trackedKeys.filter { !$0.hasPrefix(prefix) }
    }

    func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
        trackedKeys.removeAll()
    }

    // MARK: - Key Tracking (for prefix invalidation)

    private var trackedKeys = Set<String>()

    private func track(_ key: String) {
        trackedKeys.insert(key)
    }

    // Override set to also track the key
    func setTracked<T>(_ key: String, value: T, ttl: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(Entry(data: value as AnyObject, ttl: ttl), forKey: key as NSString)
        trackedKeys.insert(key)
    }
}

// MARK: - Cache Keys & TTLs

extension APICache {
    enum Key {
        static let homeFeed       = "home_feed"
        static let genres         = "genres"
        static let libraryMap     = "library_map"
        static func banners(_ placement: String) -> String { "banners_\(placement)" }
        static func episodes(_ slug: String) -> String { "episodes_\(slug)" }
        static func story(_ slug: String) -> String { "story_\(slug)" }
        static func discover(search: String?, genre: String?) -> String {
            "discover_\(search ?? "")_\(genre ?? "")"
        }
    }

    enum TTL {
        static let homeFeed:   TimeInterval = 3 * 60       // 3 min
        static let genres:     TimeInterval = 60 * 60      // 1 hour
        static let banners:    TimeInterval = 10 * 60      // 10 min
        static let stories:    TimeInterval = 5 * 60       // 5 min
        static let episodes:   TimeInterval = 2 * 60       // 2 min
        static let libraryMap: TimeInterval = 2 * 60       // 2 min
    }
}
