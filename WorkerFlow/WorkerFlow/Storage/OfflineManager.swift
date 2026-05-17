import Foundation
import Network

/// Manages offline functionality and network state
@Observable @MainActor
public final class OfflineManager {
    public static let shared = OfflineManager()
    
    // Network state
    public private(set) var isOnline = true
    public private(set) var isExpensiveConnection = false
    public private(set) var connectionType: NWInterface.InterfaceType?
    
    // Offline queue
    private var offlineOperations: [OfflineOperation] = []
    public private(set) var offlineOperationCount: Int = 0
    
    // Dependencies
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "banking.network.monitor")
    private let syncEngine = SyncEngine.shared
    
    private init() {
        monitor = NWPathMonitor()
        setupNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start network monitoring
    public func startMonitoring() {
        monitor.start(queue: monitorQueue)
    }
    
    /// Stop network monitoring
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Enqueue operation for offline execution
    public func enqueueOfflineOperation(_ operation: OfflineOperation) {
        offlineOperations.append(operation)
        offlineOperationCount = offlineOperations.count
    }
    
    /// Get data from cache/database (offline mode)
    public func getDataOffline<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        // Try cache first
        if let cached = try? CacheManager.shared.get(T.self, forKey: key) {
            return cached
        }
        
        // Fallback to SQLite if needed
        // (Implementation depends on model type)
        return nil
    }
    
    /// Store operation for sync when online
    public func storeForSync(_ operation: SyncOperation) {
        syncEngine.enqueueChange(operation)
        
        if isOnline {
            Task {
                try await syncEngine.syncPendingChanges()
            }
        }
    }
    
    /// Sync pending operations when connection restored
    public func syncWhenOnline() async {
        while !isOnline {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
        
        do {
            try await syncEngine.syncPendingChanges()
            offlineOperations.removeAll()
            offlineOperationCount = 0
        } catch {
            print("Failed to sync offline operations: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkState(path)
            }
        }
    }
    
    private func updateNetworkState(_ path: NWPath) {
        let previousOnlineState = isOnline
        
        // Update online status
        isOnline = path.status == .satisfied
        
        // Update connection type
        if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
            isExpensiveConnection = true
        } else if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
            isExpensiveConnection = false
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
            isExpensiveConnection = false
        } else {
            connectionType = nil
            isExpensiveConnection = true
        }
        
        // Handle connection restored
        if !previousOnlineState && isOnline {
            Task {
                await syncWhenOnline()
            }
        }
    }
}

// MARK: - Offline Operation

public struct OfflineOperation {
    public let id: String
    public let operationType: String
    public let data: Data
    public let timestamp: Date
    
    public init(id: String, operationType: String, data: Data) {
        self.id = id
        self.operationType = operationType
        self.data = data
        self.timestamp = Date()
    }
}

// MARK: - Network State Extensions

extension NWInterface.InterfaceType {
    public var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Wired"
        case .loopback:
            return "Loopback"
        @unknown default:
            return "Unknown"
        }
    }
}
