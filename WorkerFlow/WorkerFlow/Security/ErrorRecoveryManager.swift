import Foundation

/// Handles authentication error recovery and fallback flows
@Observable @MainActor
public final class ErrorRecoveryManager {
    
    public private(set) var currentRecoveryPath: RecoveryPath?
    public private(set) var availableRecoveryOptions: [RecoveryOption] = []
    public private(set) var recoveryError: RecoveryError?
    public private(set) var isRecovering = false
    
    public static let shared = ErrorRecoveryManager()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Analyze error and provide recovery options
    public func analyzeAndRecover(from error: Error) -> [RecoveryOption] {
        var options: [RecoveryOption] = []
        
        if let authError = error as? AuthError {
            options = handleAuthError(authError)
        } else if let sessionError = error as? SessionError {
            options = handleSessionError(sessionError)
        } else if let networkError = error as? NetworkError {
            options = handleNetworkError(networkError)
        } else if let authFlowError = error as? AuthenticationFlowError {
            options = handleAuthFlowError(authFlowError)
        }
        
        availableRecoveryOptions = options
        return options
    }
    
    /// Execute recovery path
    public func executeRecovery(_ option: RecoveryOption) async throws {
        isRecovering = true
        defer { isRecovering = false }
        
        do {
            switch option {
            case .retryOAuth:
                try await retryOAuthFlow()
                
            case .refreshToken:
                try await refreshAccessToken()
                
            case .useBiometricFallback:
                try await useBiometricFallback()
                
            case .usePasswordFallback:
                // Handled by UI, just clear state
                currentRecoveryPath = .passwordEntry
                
            case .resetPassword:
                try await initiatePasswordReset()
                
            case .contactSupport:
                try openSupportChannel()
                
            case .loginAgain:
                await loginAgain()
                currentRecoveryPath = .freshLogin
                
            case .offlineMode:
                currentRecoveryPath = .offlineMode
                
            case .clearCache:
                try clearCacheAndRetry()
            }
            
            recoveryError = nil
        } catch {
            recoveryError = RecoveryError.recoveryFailed(error.localizedDescription)
            throw recoveryError!
        }
    }
    
    /// Get recommended recovery path
    public func getRecommendedPath(for error: Error) -> RecoveryPath {
        if error is NetworkError {
            return .offlineMode
        } else if let authError = error as? AuthError {
            switch authError {
            case .tokenRefreshFailed:
                return .freshLogin
            case .unauthorized:
                return .passwordEntry
            default:
                return .supportContact
            }
        } else if error is SessionError {
            return .freshLogin
        }
        
        return .supportContact
    }
    
    // MARK: - Private Methods
    
    private func handleAuthError(_ error: AuthError) -> [RecoveryOption] {
        switch error {
        case .tokenRefreshFailed:
            return [.refreshToken, .retryOAuth, .loginAgain, .contactSupport]
        case .unauthorized:
            return [.useBiometricFallback, .usePasswordFallback, .resetPassword, .contactSupport]
        case .refreshTokenMissing, .accessTokenMissing:
            return [.loginAgain, .contactSupport]
        default:
            return [.retryOAuth, .loginAgain, .contactSupport]
        }
    }
    
    private func handleSessionError(_ error: SessionError) -> [RecoveryOption] {
        switch error {
        case .sessionExpired:
            return [.loginAgain, .refreshToken, .contactSupport]
        case .deviceNotTrusted:
            return [.useBiometricFallback, .usePasswordFallback, .contactSupport]
        default:
            return [.loginAgain, .contactSupport]
        }
    }
    
    private func handleNetworkError(_ error: NetworkError) -> [RecoveryOption] {
        switch error {
        case .requestFailed:
            return [.retryOAuth, .offlineMode, .contactSupport]
        case .unauthorized:
            return [.refreshToken, .loginAgain, .contactSupport]
        default:
            return [.retryOAuth, .offlineMode, .contactSupport]
        }
    }
    
    private func handleAuthFlowError(_ error: AuthenticationFlowError) -> [RecoveryOption] {
        switch error {
        case .invalidCredentials:
            return [.usePasswordFallback, .resetPassword, .contactSupport]
        case .accountLocked:
            return [.contactSupport]
        case .tokenRefreshFailed:
            return [.refreshToken, .loginAgain, .contactSupport]
        case .biometricFailed, .biometricError:
            return [.usePasswordFallback, .useBiometricFallback, .contactSupport]
        default:
            return [.loginAgain, .contactSupport]
        }
    }
    
    private func retryOAuthFlow() async throws {
        try await OAuthManager.shared.refreshTokens()
    }
    
    private func refreshAccessToken() async throws {
        try await OAuthManager.shared.refreshTokens()
    }
    
    private func useBiometricFallback() async throws {
        let biometricService = BiometricAuthService.shared
        let success = await biometricService.authenticateWithBiometricOrPasscode(
            reason: "Authenticate to recover your session"
        )
        
        guard success else {
            throw RecoveryError.fallbackAuthenticationFailed
        }
    }
    
    private func initiatePasswordReset() async throws {
        // In production, call API to initiate password reset flow
        // This would send an email to the user with reset link
        currentRecoveryPath = .passwordReset
    }
    
    private func openSupportChannel() throws {
        // Open support contact form or chat
        // In production, this would open a help UI
        currentRecoveryPath = .supportContact
    }
    
    private func loginAgain() async {
        // Reset authentication state and restart login flow
        await OAuthManager.shared.logout()
        currentRecoveryPath = .freshLogin
    }
    
    private func clearCacheAndRetry() throws {
        // Clear local cache and retry
        // This removes any corrupted cached state
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        currentRecoveryPath = .freshLogin
    }
}

// MARK: - Recovery Models

public enum RecoveryOption {
    case retryOAuth
    case refreshToken
    case useBiometricFallback
    case usePasswordFallback
    case resetPassword
    case contactSupport
    case loginAgain
    case offlineMode
    case clearCache
    
    public var displayName: String {
        switch self {
        case .retryOAuth:
            return "Retry Authentication"
        case .refreshToken:
            return "Refresh Session"
        case .useBiometricFallback:
            return "Use Biometric"
        case .usePasswordFallback:
            return "Use Password"
        case .resetPassword:
            return "Reset Password"
        case .contactSupport:
            return "Contact Support"
        case .loginAgain:
            return "Login Again"
        case .offlineMode:
            return "Continue Offline"
        case .clearCache:
            return "Clear Cache and Retry"
        }
    }
    
    public var description: String {
        switch self {
        case .retryOAuth:
            return "Try the authentication process again"
        case .refreshToken:
            return "Refresh your session token"
        case .useBiometricFallback:
            return "Authenticate using Face ID or Touch ID"
        case .usePasswordFallback:
            return "Authenticate with your password"
        case .resetPassword:
            return "Reset your password"
        case .contactSupport:
            return "Contact our support team"
        case .loginAgain:
            return "Log out and log back in"
        case .offlineMode:
            return "Use the app in offline mode"
        case .clearCache:
            return "Clear cached data and retry"
        }
    }
}

public enum RecoveryPath {
    case passwordEntry
    case biometricEntry
    case mfaEntry
    case passwordReset
    case supportContact
    case freshLogin
    case offlineMode
}

// MARK: - Recovery Error

public enum RecoveryError: LocalizedError {
    case fallbackAuthenticationFailed
    case recoveryFailed(String)
    case noRecoveryOptionsAvailable
    
    public var errorDescription: String? {
        switch self {
        case .fallbackAuthenticationFailed:
            return "Fallback authentication failed. Please try again."
        case .recoveryFailed(let reason):
            return "Recovery failed: \(reason)"
        case .noRecoveryOptionsAvailable:
            return "No recovery options available. Please contact support."
        }
    }
}
