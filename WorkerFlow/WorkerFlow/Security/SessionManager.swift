import Foundation

/// Manages user authentication sessions with lifecycle tracking and multi-device support
@MainActor
public final class SessionManager {
    public static let shared = SessionManager()
    
    // Session state
    public private(set) var activeSession: UserSession?
    public private(set) var isSessionValid = false
    public private(set) var sessionError: SessionError?
    
    private var sessionMonitoringTimer: Timer?
    private let sessionValidationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Create a new session after successful authentication
    public func createSession(user: User, device: Device) throws {
        let session = UserSession(
            id: UUID().uuidString,
            userId: user.id,
            device: device,
            createdAt: Date(),
            lastActivityAt: Date(),
            isActive: true
        )
        
        activeSession = session
        isSessionValid = true
        sessionError = nil
        
        // Start session monitoring
        startSessionMonitoring()
        
        // Store session locally
        try storeSessionLocally(session)
    }
    
    /// Validate current session
    public func validateSession() async throws {
        guard let session = activeSession else {
            throw SessionError.noActiveSession
        }
        
        // Check if session has expired
        let sessionAge = Date().timeIntervalSince(session.createdAt)
        if sessionAge > 86400 { // 24 hours
            try await terminateSession()
            throw SessionError.sessionExpired
        }
        
        // Update last activity
        var updatedSession = session
        updatedSession.lastActivityAt = Date()
        activeSession = updatedSession
        
        // Validate with backend
        try await validateWithBackend(session: updatedSession)
        
        isSessionValid = true
        sessionError = nil
    }
    
    /// Refresh session (check validity, update lastActivity)
    public func refreshSession() async throws {
        guard let session = activeSession else {
            throw SessionError.noActiveSession
        }
        
        try await validateSession()
        
        // Update local storage
        try storeSessionLocally(session)
    }
    
    /// Terminate current session
    public func terminateSession() async throws {
        if let session = activeSession {
            // Notify backend of logout
            try await notifyBackendLogout(session: session)
        }
        
        activeSession = nil
        isSessionValid = false
        sessionMonitoringTimer?.invalidate()
        
        // Clear stored session
        try clearStoredSession()
    }
    
    /// Resume session from storage (on app launch)
    public func resumeStoredSession() async throws {
        guard let storedSession = try retrieveStoredSession() else {
            return
        }
        
        activeSession = storedSession
        
        // Validate session with backend
        try await validateSession()
        startSessionMonitoring()
    }
    
    // MARK: - Private Methods
    
    private func validateWithBackend(session: UserSession) async throws {
        // In production, call API to validate session
        // Example: POST /auth/validate-session with sessionId
        
        // For now, basic validation
        let tokenExpiryDate = try KeychainService.shared.retrieveTokenExpiryDate()
        guard let expiryDate = tokenExpiryDate, expiryDate > Date() else {
            throw SessionError.sessionExpired
        }
    }
    
    private func notifyBackendLogout(session: UserSession) async throws {
        // In production, call API to invalidate session
        // Example: POST /auth/logout with sessionId
    }
    
    private func startSessionMonitoring() {
        sessionMonitoringTimer?.invalidate()
        
        sessionMonitoringTimer = Timer.scheduledTimer(withTimeInterval: sessionValidationInterval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.validateSession()
            }
        }
    }
    
    private func storeSessionLocally(_ session: UserSession) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)
        UserDefaults.standard.set(data, forKey: "banking_active_session")
    }
    
    private func retrieveStoredSession() throws -> UserSession? {
        guard let data = UserDefaults.standard.data(forKey: "banking_active_session") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(UserSession.self, from: data)
    }
    
    private func clearStoredSession() throws {
        UserDefaults.standard.removeObject(forKey: "banking_active_session")
    }
}

// MARK: - Models

/// Represents a user session
public struct UserSession: Codable {
    public let id: String
    public let userId: String
    public let device: Device
    public let createdAt: Date
    public var lastActivityAt: Date
    public var isActive: Bool
    
    public init(id: String, userId: String, device: Device, createdAt: Date, lastActivityAt: Date, isActive: Bool) {
        self.id = id
        self.userId = userId
        self.device = device
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.isActive = isActive
    }
}

/// Represents a user device for multi-device authentication
public struct Device: Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: DeviceType
    public let osVersion: String
    public let appVersion: String
    public let createdAt: Date
    public var lastSeenAt: Date
    public var isVerified: Bool
    public var trustToken: String?
    
    public enum DeviceType: String, Codable {
        case mac, iphone, ipad
    }
    
    public init(
        id: String,
        name: String,
        type: DeviceType,
        osVersion: String,
        appVersion: String,
        createdAt: Date = Date(),
        lastSeenAt: Date = Date(),
        isVerified: Bool = false,
        trustToken: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.isVerified = isVerified
        self.trustToken = trustToken
    }
}

// MARK: - Session Error

public enum SessionError: LocalizedError {
    case noActiveSession
    case sessionExpired
    case sessionInvalid
    case deviceNotTrusted
    case backendValidationFailed(String)
    case sessionStorageFailed
    
    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session found"
        case .sessionExpired:
            return "Session has expired. Please log in again."
        case .sessionInvalid:
            return "Session is invalid"
        case .deviceNotTrusted:
            return "This device is not trusted. Please verify your identity."
        case .backendValidationFailed(let reason):
            return "Session validation failed: \(reason)"
        case .sessionStorageFailed:
            return "Failed to store session"
        }
    }
}
