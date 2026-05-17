import Foundation

/// Manages in-memory cache with TTL (time-to-live) invalidation and fallback to SQLite
@Observable @MainActor
public final class CacheManager {
    public static let shared = CacheManager()
    
    // Cache storage with expiry tracking
    private var cache: [String: CacheEntry<Data>] = [:]
    private let cacheLock = NSLock()
    
    // Configuration
    private let defaultTTL: TimeInterval = 3600 // 1 hour
    private let maxCacheSize = 100 * 1024 * 1024 // 100 MB
    private var currentCacheSize: Int = 0
    
    // Cache statistics
    public private(set) var hitCount = 0
    public private(set) var missCount = 0
    public private(set) var evictionCount = 0
    
    private nonisolated(unsafe) var cleanupTimer: Timer?
    
    private init() {
        startCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Cache data with default TTL
    public func set<T: Encodable>(_ value: T, forKey key: String) throws {
        try set(value, forKey: key, ttl: defaultTTL)
    }
    
    /// Cache data with custom TTL
    public func set<T: Encodable>(_ value: T, forKey key: String, ttl: TimeInterval) throws {
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(value)
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // Check cache size before adding
        if currentCacheSize + encodedData.count > maxCacheSize {
            evictLRUEntry()
        }
        
        let entry = CacheEntry(data: encodedData, expiresAt: Date().addingTimeInterval(ttl))
        cache[key] = entry
        currentCacheSize += encodedData.count
    }
    
    /// Retrieve cached data if valid (not expired)
    public func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let entry = cache[key] else {
            missCount += 1
            return nil
        }
        
        // Check expiration
        if Date() > entry.expiresAt {
            removeEntry(forKey: key)
            missCount += 1
            return nil
        }
        
        // Update last access time
        cache[key]?.lastAccessedAt = Date()
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(T.self, from: entry.data)
        hitCount += 1
        
        return decoded
    }
    
    /// Get raw data from cache
    public func getData(forKey key: String) -> Data? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let entry = cache[key] else {
            missCount += 1
            return nil
        }
        
        if Date() > entry.expiresAt {
            removeEntry(forKey: key)
            missCount += 1
            return nil
        }
        
        cache[key]?.lastAccessedAt = Date()
        hitCount += 1
        return entry.data
    }
    
    /// Remove specific cache entry
    public func remove(forKey key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        removeEntry(forKey: key)
    }
    
    /// Clear all cache
    public func clearAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        cache.removeAll()
        currentCacheSize = 0
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    /// Check if key exists and is valid
    public func exists(forKey key: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let entry = cache[key] else {
            return false
        }
        
        return Date() < entry.expiresAt
    }
    
    /// Get cache hit ratio
    public func getCacheHitRatio() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
    
    /// Get cache statistics
    public func getCacheStats() -> CacheStatistics {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let totalSize = cache.values.reduce(0) { $0 + $1.data.count }
        
        return CacheStatistics(
            itemCount: cache.count,
            totalSize: totalSize,
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            hitRatio: getCacheHitRatio()
        )
    }
    
    /// Warm cache by loading frequently accessed data
    public func warmCache<T: Decodable & Encodable>(_ type: T.Type, fromKeys keys: [String], fallback: @escaping (String) async -> T?) async {
        for key in keys {
            // Try to get from cache
            if let _ = try? get(T.self, forKey: key) {
                continue // Already cached
            }
            
            // Fallback to fetch from API/database
            if let data = await fallback(key) {
                try? set(data, forKey: key)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func removeEntry(forKey key: String) {
        if let entry = cache.removeValue(forKey: key) {
            currentCacheSize -= entry.data.count
        }
    }
    
    private func evictLRUEntry() {
        // Find least recently used entry
        guard let lruKey = cache.min(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?.key else {
            return
        }
        
        removeEntry(forKey: lruKey)
        evictionCount += 1
    }
    
    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupExpiredEntries()
        }
    }
    
    private func cleanupExpiredEntries() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let now = Date()
        let expiredKeys = cache.filter { now > $0.value.expiresAt }.map { $0.key }
        
        for key in expiredKeys {
            removeEntry(forKey: key)
        }
    }
}

// MARK: - Cache Entry

private struct CacheEntry<T> {
    let data: T
    let expiresAt: Date
    var lastAccessedAt: Date = Date()
}

// MARK: - Cache Statistics

public struct CacheStatistics {
    public let itemCount: Int
    public let totalSize: Int
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let hitRatio: Double
    
    public var formattedSize: String {
        let bytes = Double(totalSize)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }
}
