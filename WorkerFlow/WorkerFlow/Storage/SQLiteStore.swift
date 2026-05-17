import Foundation
import SQLite3

/// Manages SQLite database operations for persistent local storage
@MainActor
public final class SQLiteStore {
    public static let shared = SQLiteStore()
    
    private var database: OpaquePointer?
    private let databasePath: String
    private let dbLock = NSLock()
    
    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        self.databasePath = documentsDirectory.appendingPathComponent("banking.db").path
        
        Task {
            await initializeDatabase()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize or open database
    public func initializeDatabase() async {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        // Open or create database
        if sqlite3_open(databasePath, &database) == SQLITE_OK {
            createTables()
            setupIndexes()
        }
    }
    
    /// Store a user
    public func storeUser(_ user: User) async throws {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let encoder = JSONEncoder()
        let userData = try encoder.encode(user)
        
        let query = """
        INSERT OR REPLACE INTO users (id, email, fullName, phoneNumber, data, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        
        sqlite3_bind_text(statement, 1, (user.id as NSString).utf8String, -1, transient)
        sqlite3_bind_text(statement, 2, (user.email as NSString).utf8String, -1, transient)
        sqlite3_bind_text(statement, 3, (user.fullName as NSString).utf8String, -1, transient)
        
        if let phoneNumber = user.phoneNumber {
            sqlite3_bind_text(statement, 4, (phoneNumber as NSString).utf8String, -1, transient)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        sqlite3_bind_blob(statement, 5, (userData as NSData).bytes, Int32(userData.count), transient)
        sqlite3_bind_text(statement, 6, (ISO8601DateFormatter().string(from: Date()) as NSString).utf8String, -1, transient)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.executionFailed
        }
    }
    
    /// Retrieve a user by ID
    public func getUser(by id: String) async throws -> User? {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let query = "SELECT data FROM users WHERE id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, transient)
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        
        let data = sqlite3_column_blob(statement, 0)
        let length = sqlite3_column_bytes(statement, 0)
        let userData = Data(bytes: data!, count: Int(length))
        
        let decoder = JSONDecoder()
        return try decoder.decode(User.self, from: userData)
    }
    
    /// Store accounts
    public func storeAccounts(_ accounts: [Account]) async throws {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        
        for account in accounts {
            let encoder = JSONEncoder()
            let accountData = try encoder.encode(account)
            
            let query = """
            INSERT OR REPLACE INTO accounts (id, userId, accountNumber, displayName, type, data, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, (account.id as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 2, (account.userId as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 3, (account.accountNumber as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 4, (account.displayName as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 5, (account.accountType.rawValue as NSString).utf8String, -1, transient)
            sqlite3_bind_blob(statement, 6, (accountData as NSData).bytes, Int32(accountData.count), transient)
            sqlite3_bind_text(statement, 7, (ISO8601DateFormatter().string(from: Date()) as NSString).utf8String, -1, transient)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StorageError.executionFailed
            }
        }
    }
    
    /// Get accounts for user
    public func getAccounts(for userId: String) async throws -> [Account] {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let query = "SELECT data FROM accounts WHERE userId = ? ORDER BY displayName ASC"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, transient)
        
        var accounts: [Account] = []
        let decoder = JSONDecoder()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let data = sqlite3_column_blob(statement, 0)
            let length = sqlite3_column_bytes(statement, 0)
            let accountData = Data(bytes: data!, count: Int(length))
            
            if let account = try? decoder.decode(Account.self, from: accountData) {
                accounts.append(account)
            }
        }
        
        return accounts
    }
    
    /// Store transactions
    public func storeTransactions(_ transactions: [Transaction]) async throws {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        let formatter = ISO8601DateFormatter()
        
        for transaction in transactions {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let txnData = try encoder.encode(transaction)
            
            let query = """
            INSERT OR REPLACE INTO transactions (id, accountId, userId, amount, status, transactionDate, data, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, (transaction.id as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 2, (transaction.accountId as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 3, (transaction.userId as NSString).utf8String, -1, transient)
            sqlite3_bind_double(statement, 4, Double(truncating: transaction.amount as NSNumber))
            sqlite3_bind_text(statement, 5, (transaction.status.rawValue as NSString).utf8String, -1, transient)
            sqlite3_bind_text(statement, 6, (formatter.string(from: transaction.transactionDate) as NSString).utf8String, -1, transient)
            sqlite3_bind_blob(statement, 7, (txnData as NSData).bytes, Int32(txnData.count), transient)
            sqlite3_bind_text(statement, 8, (formatter.string(from: Date()) as NSString).utf8String, -1, transient)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StorageError.executionFailed
            }
        }
    }
    
    /// Get transactions for account
    public func getTransactions(for accountId: String, limit: Int = 100) async throws -> [Transaction] {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let query = "SELECT data FROM transactions WHERE accountId = ? ORDER BY transactionDate DESC LIMIT ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        sqlite3_bind_text(statement, 1, (accountId as NSString).utf8String, -1, transient)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        var transactions: [Transaction] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let data = sqlite3_column_blob(statement, 0)
            let length = sqlite3_column_bytes(statement, 0)
            let txnData = Data(bytes: data!, count: Int(length))
            
            if let transaction = try? decoder.decode(Transaction.self, from: txnData) {
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    /// Delete old transactions (cleanup)
    public func deleteOldTransactions(olderThan days: Int) async throws -> Int {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let cutoffDate = Date().addingTimeInterval(TimeInterval(-days * 86400))
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: cutoffDate)
        
        let query = "DELETE FROM transactions WHERE transactionDate < ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type?.self)
        sqlite3_bind_text(statement, 1, (dateString as NSString).utf8String, -1, transient)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.executionFailed
        }
        
        return Int(sqlite3_changes(database))
    }
    
    /// Get database statistics
    public func getDatabaseStats() async throws -> DatabaseStats {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        guard database != nil else {
            throw StorageError.databaseNotInitialized
        }
        
        let queries = [
            ("SELECT COUNT(*) FROM users", "userCount"),
            ("SELECT COUNT(*) FROM accounts", "accountCount"),
            ("SELECT COUNT(*) FROM transactions", "transactionCount"),
            ("SELECT COUNT(*) FROM cards", "cardCount"),
        ]
        
        var stats: [String: Int] = [:]
        
        for (query, key) in queries {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
                defer { sqlite3_finalize(statement) }
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    stats[key] = Int(sqlite3_column_int(statement, 0))
                }
            }
        }
        
        return DatabaseStats(
            userCount: stats["userCount"] ?? 0,
            accountCount: stats["accountCount"] ?? 0,
            transactionCount: stats["transactionCount"] ?? 0,
            cardCount: stats["cardCount"] ?? 0,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func createTables() {
        let tables = [
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT NOT NULL,
                fullName TEXT NOT NULL,
                phoneNumber TEXT,
                data BLOB NOT NULL,
                updatedAt TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL,
                accountNumber TEXT NOT NULL,
                displayName TEXT NOT NULL,
                type TEXT NOT NULL,
                data BLOB NOT NULL,
                updatedAt TEXT NOT NULL,
                FOREIGN KEY(userId) REFERENCES users(id)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                accountId TEXT NOT NULL,
                userId TEXT NOT NULL,
                amount REAL NOT NULL,
                status TEXT NOT NULL,
                transactionDate TEXT NOT NULL,
                data BLOB NOT NULL,
                updatedAt TEXT NOT NULL,
                FOREIGN KEY(accountId) REFERENCES accounts(id),
                FOREIGN KEY(userId) REFERENCES users(id)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL,
                accountId TEXT NOT NULL,
                type TEXT NOT NULL,
                data BLOB NOT NULL,
                updatedAt TEXT NOT NULL,
                FOREIGN KEY(userId) REFERENCES users(id),
                FOREIGN KEY(accountId) REFERENCES accounts(id)
            )
            """,
        ]
        
        for table in tables {
            var errorMessage: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(database, table, nil, nil, &errorMessage) != SQLITE_OK {
                if errorMessage != nil {
                    sqlite3_free(errorMessage)
                }
            }
        }
    }
    
    private func setupIndexes() {
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_accounts_userId ON accounts(userId)",
            "CREATE INDEX IF NOT EXISTS idx_transactions_accountId ON transactions(accountId)",
            "CREATE INDEX IF NOT EXISTS idx_transactions_userId ON transactions(userId)",
            "CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transactionDate)",
            "CREATE INDEX IF NOT EXISTS idx_cards_userId ON cards(userId)",
        ]
        
        for index in indexes {
            var errorMessage: UnsafeMutablePointer<CChar>?
            sqlite3_exec(database, index, nil, nil, &errorMessage)
            if errorMessage != nil {
                sqlite3_free(errorMessage)
            }
        }
    }
}

// MARK: - Models

public struct DatabaseStats {
    public let userCount: Int
    public let accountCount: Int
    public let transactionCount: Int
    public let cardCount: Int
    public let lastUpdated: Date
}

// MARK: - Storage Error

public enum StorageError: LocalizedError {
    case databaseNotInitialized
    case prepareFailed
    case executionFailed
    case queryFailed(String)
    case encodingFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database not initialized"
        case .prepareFailed:
            return "Failed to prepare SQL statement"
        case .executionFailed:
            return "Failed to execute SQL statement"
        case .queryFailed(let reason):
            return "Query failed: \(reason)"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        }
    }
}
