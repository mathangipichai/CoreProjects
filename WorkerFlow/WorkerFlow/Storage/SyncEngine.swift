import Foundation

/// Manages background data synchronization with conflict resolution
@Observable @MainActor
public final class SyncEngine {
    public static let shared = SyncEngine()
    
    // Sync state
    public private(set) var isSyncing = false
    public private(set) var lastSyncTime: Date?
    public private(set) var syncError: SyncError?
    public private(set) var pendingChanges: Int = 0
    
    // Sync configuration
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private let retryBackoffBaseInterval: TimeInterval = 5
    private var retryCount = 0
    private let maxRetries = 3
    
    // Dependencies
    private let apiClient = APIClient.shared
    private let sqliteStore = SQLiteStore.shared
    private let cacheManager = CacheManager.shared
    private nonisolated(unsafe) var syncTimer: Timer?
    private var changeQueue: [SyncOperation] = []
    
    private init() {
        startSyncTimer()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start automatic syncing
    public func startSyncing() {
        syncTimer?.invalidate()
        startSyncTimer()
    }
    
    /// Stop automatic syncing
    public func stopSyncing() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Manually trigger sync
    public func syncNow() async {
        await performSync()
    }
    
    /// Enqueue an operation to be synced
    public func enqueueChange(_ operation: SyncOperation) {
        changeQueue.append(operation)
        pendingChanges = changeQueue.count
    }
    
    /// Sync pending changes to backend
    public func syncPendingChanges() async throws {
        guard !changeQueue.isEmpty else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let operationsToSync = changeQueue
        changeQueue.removeAll()
        pendingChanges = 0
        
        for operation in operationsToSync {
            try await executeSync(operation)
        }
        
        lastSyncTime = Date()
        retryCount = 0
        syncError = nil
    }
    
    /// Resolve conflicts between local and remote data
    public func resolveConflict(
        local: SyncableData,
        remote: SyncableData,
        strategy: ConflictResolutionStrategy = .lastWriteWins
    ) -> SyncableData {
        switch strategy {
        case .lastWriteWins:
            return local.updatedAt > remote.updatedAt ? local : remote
            
        case .localWins:
            return local
            
        case .remoteWins:
            return remote
            
        case .custom(let resolver):
            return resolver(local, remote)
        }
    }
    
    // MARK: - Private Methods
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
    }
    
    private func performSync() async {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Sync pending changes first
            try await syncPendingChanges()
            
            // Fetch latest data from backend
            try await fetchLatestData()
            
            lastSyncTime = Date()
            retryCount = 0
            syncError = nil
        } catch {
            syncError = error as? SyncError ?? .syncFailed(error.localizedDescription)
            
            // Retry with exponential backoff
            if retryCount < maxRetries {
                retryCount += 1
                let backoffInterval = retryBackoffBaseInterval * pow(2, Double(retryCount - 1))
                
                try? await Task.sleep(nanoseconds: UInt64(backoffInterval * 1_000_000_000))
                await performSync()
            }
        }
    }
    
    private func executeSync(_ operation: SyncOperation) async throws {
        switch operation {
        case .create(let type, let data):
            try await syncCreate(type: type, data: data)
            
        case .update(let type, let id, let data):
            try await syncUpdate(type: type, id: id, data: data)
            
        case .delete(let type, let id):
            try await syncDelete(type: type, id: id)
        }
    }
    
    private func syncCreate(type: String, data: Data) async throws {
        // In production, call API to create resource
        // Example: POST /api/resource with data
    }
    
    private func syncUpdate(type: String, id: String, data: Data) async throws {
        // In production, call API to update resource
        // Example: PUT /api/resource/{id} with data
    }
    
    private func syncDelete(type: String, id: String) async throws {
        // In production, call API to delete resource
        // Example: DELETE /api/resource/{id}
    }
    
    private func fetchLatestData() async throws {
        // Fetch accounts
        // let accounts: [Account] = try await apiClient.get(
        //     endpoint: "/accounts",
        //     responseType: [Account].self
        // )
        // try await sqliteStore.storeAccounts(accounts)
        // try cacheManager.set(accounts, forKey: "accounts")
        
        // Fetch transactions
        // Similar pattern...
        
        // Fetch cards
        // Similar pattern...
    }
}

// MARK: - Sync Operation

public enum SyncOperation {
    case create(type: String, data: Data)
    case update(type: String, id: String, data: Data)
    case delete(type: String, id: String)
}

// MARK: - Syncable Data Protocol

public protocol SyncableData {
    var id: String { get }
    var updatedAt: Date { get }
}

// MARK: - Conflict Resolution Strategy

public enum ConflictResolutionStrategy {
    case lastWriteWins
    case localWins
    case remoteWins
    case custom((_ local: SyncableData, _ remote: SyncableData) -> SyncableData)
}

// MARK: - Sync Error

public enum SyncError: LocalizedError {
    case syncFailed(String)
    case conflictDetected
    case networkUnavailable
    case invalidData
    case backendError(String)
    
    public var errorDescription: String? {
        switch self {
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .conflictDetected:
            return "Data conflict detected during sync"
        case .networkUnavailable:
            return "Network unavailable"
        case .invalidData:
            return "Invalid data received from backend"
        case .backendError(let reason):
            return "Backend error: \(reason)"
        }
    }
}
