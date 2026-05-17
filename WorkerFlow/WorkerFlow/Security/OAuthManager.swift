import Foundation

/// Manages OAuth 2.0 authentication flow, token lifecycle, and session management
@Observable @MainActor
public final class OAuthManager: Sendable {
    public static let shared = OAuthManager()
    
    // MARK: - Properties
    
    public private(set) var isAuthenticated = false
    public private(set) var currentUser: User?
    public private(set) var isAuthenticating = false
    public private(set) var authError: AuthError?
    public private(set) var lastAuthAttempt: Date?
    
    private nonisolated(unsafe) var tokenRefreshTimer: Timer?
    private var authenticationTask: Task<Void, Never>?
    
    // OAuth Configuration
    private let clientID = "banking.app.production"
    private let redirectURL = URL(string: "banking://oauth/callback")!
    private let tokenEndpoint = "https://api.banking.example.com/oauth/token"
    private let userEndpoint = "https://api.banking.example.com/user/profile"
    
    private init() {
        Task {
            await validateStoredSession()
        }
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Initiate OAuth 2.0 authorization flow
    public func startAuthorizationFlow(authorizationCode: String) async throws {
        isAuthenticating = true
        authError = nil
        lastAuthAttempt = Date()
        
        defer { isAuthenticating = false }
        
        do {
            // Exchange authorization code for tokens
            let tokens = try await exchangeAuthorizationCode(authorizationCode)
            
            // Store tokens securely
            try storeTokens(tokens)
            
            // Fetch user profile
            let user = try await fetchUserProfile(accessToken: tokens.accessToken)
            
            // Store user info
            try storeUserInfo(user)
            
            self.currentUser = user
            self.isAuthenticated = true
            
            // Start token refresh timer
            startTokenRefreshTimer(expiresIn: tokens.expiresIn)
        } catch {
            authError = error as? AuthError ?? .unknown(error.localizedDescription)
            isAuthenticated = false
            throw authError!
        }
    }
    
    /// Refresh OAuth tokens when expired
    public func refreshTokens() async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            guard let refreshToken = try KeychainService.shared.retrieveRefreshToken() else {
                throw AuthError.refreshTokenMissing
            }
            
            let newTokens = try await requestNewTokens(refreshToken: refreshToken)
            try storeTokens(newTokens)
            
            self.isAuthenticated = true
            self.authError = nil
            
            // Restart token refresh timer
            startTokenRefreshTimer(expiresIn: newTokens.expiresIn)
        } catch {
            authError = error as? AuthError ?? .unknown(error.localizedDescription)
            isAuthenticated = false
            
            // Clear session on refresh failure
            await logout()
            throw error
        }
    }
    
    /// Logout and clear all authentication data
    public func logout() async {
        isAuthenticated = false
        currentUser = nil
        authError = nil
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        
        do {
            try KeychainService.shared.deleteAllCredentials()
        } catch {
            print("Failed to clear credentials: \(error)")
        }
    }
    
    /// Get current access token
    public func getAccessToken() async throws -> String {
        // Check if token needs refresh
        if let expiryDate = try KeychainService.shared.retrieveTokenExpiryDate(),
           expiryDate.timeIntervalSinceNow < 300 { // Refresh if expires in less than 5 minutes
            try await refreshTokens()
        }
        
        guard let token = try KeychainService.shared.retrieveAccessToken() else {
            throw AuthError.accessTokenMissing
        }
        
        return token
    }
    
    /// Validate stored session on app launch
    public func validateStoredSession() async {
        do {
            // Check if we have stored credentials
            guard let accessToken = try KeychainService.shared.retrieveAccessToken() else {
                return
            }
            
            // Check if token is expired
            if let expiryDate = try KeychainService.shared.retrieveTokenExpiryDate(),
               expiryDate < Date() {
                // Token expired, try to refresh
                try await refreshTokens()
            } else {
                // Token is still valid, restore session
                if let userID = try KeychainService.shared.retrieveUserID() {
                    // In production, fetch full user profile
                    // For now, mark as authenticated
                    isAuthenticated = true
                }
            }
        } catch {
            // Session validation failed, clear credentials
            try? KeychainService.shared.deleteAllCredentials()
            isAuthenticated = false
        }
    }
    
    // MARK: - Private Methods
    
    private func exchangeAuthorizationCode(_ code: String) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=authorization_code&code=\(code)&client_id=\(clientID)&redirect_uri=\(redirectURL.absoluteString)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let token = try decoder.decode(OAuthToken.self, from: data)
        
        return token
    }
    
    private func requestNewTokens(refreshToken: String) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientID)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.tokenRefreshFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let token = try decoder.decode(OAuthToken.self, from: data)
        
        return token
    }
    
    private func fetchUserProfile(accessToken: String) async throws -> User {
        var request = URLRequest(url: URL(string: userEndpoint)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: data)
        
        return user
    }
    
    private func storeTokens(_ token: OAuthToken) throws {
        try KeychainService.shared.storeAccessToken(token.accessToken)
        try KeychainService.shared.storeRefreshToken(token.refreshToken)
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        try KeychainService.shared.storeTokenExpiryDate(expiryDate)
    }
    
    private func storeUserInfo(_ user: User) throws {
        try KeychainService.shared.storeUserID(user.id)
    }
    
    private func startTokenRefreshTimer(expiresIn: Int) {
        tokenRefreshTimer?.invalidate()
        
        // Refresh token 5 minutes before expiry
        let refreshInterval = TimeInterval(expiresIn - 300)
        
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: false) { [weak self] _ in
            Task {
                try? await self?.refreshTokens()
            }
        }
    }
}

// MARK: - OAuth Token Model

public struct OAuthToken: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

// MARK: - Authentication Error

public enum AuthError: LocalizedError, Equatable {
    case invalidResponse
    case tokenRefreshFailed
    case refreshTokenMissing
    case accessTokenMissing
    case unauthorized
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from authentication server"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .refreshTokenMissing:
            return "Refresh token not found"
        case .accessTokenMissing:
            return "Access token not found"
        case .unauthorized:
            return "Unauthorized access"
        case .unknown(let message):
            return "Unknown authentication error: \(message)"
        }
    }
    
    public static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
             (.tokenRefreshFailed, .tokenRefreshFailed),
             (.refreshTokenMissing, .refreshTokenMissing),
             (.accessTokenMissing, .accessTokenMissing),
             (.unauthorized, .unauthorized):
            return true
        case (.unknown(let lhsMsg), .unknown(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
