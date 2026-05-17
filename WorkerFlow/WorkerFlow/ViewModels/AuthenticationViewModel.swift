import Foundation

/// Manages authentication UI state and login flows with multi-step auth and error recovery
@Observable @MainActor
public final class AuthenticationViewModel {
    
    // MARK: - Authentication State
    public var authStep: AuthenticationStep = .initial
    public var isLoading = false
    public var error: AuthenticationFlowError?
    public var isAuthenticated = false
    
    // MARK: - User Input
    public var email = ""
    public var password = ""
    public var pin = ""
    public var oauthCode = ""
    public var rememberDevice = true
    
    // MARK: - Authentication Methods Available
    public var biometricAvailable = false
    public var biometricType: BiometricType = .none
    public var passwordAuthAvailable = false
    
    // MARK: - Session State
    public var currentDevice: Device?
    public var trustedDevices: [Device] = []
    
    // MARK: - Error Recovery
    public var retryCount = 0
    public var maxRetries = 3
    public var isLockedOut = false
    public var lockoutTimeRemaining: Int = 0
    
    // MARK: - Dependencies
    private let oauthManager = OAuthManager.shared
    private let biometricService = BiometricAuthService.shared
    private let sessionManager = SessionManager.shared
    
    public static let shared = AuthenticationViewModel()
    
    public init() {
        setupAuthenticationMethods()
    }
    
    // MARK: - Public Methods
    
    /// Start authentication flow - attempt biometric first
    public func startAuthentication() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        // Check if biometric is available and enabled
        if biometricAvailable {
            await attemptBiometricAuthentication()
        } else if passwordAuthAvailable {
            authStep = .passwordEntry
        } else {
            error = AuthenticationFlowError.noAuthMethodsAvailable
        }
    }
    
    /// Attempt biometric authentication
    public func attemptBiometricAuthentication() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let reason = "Authenticate to access your banking information"
            let success = await biometricService.authenticateWithBiometric(reason: reason)
            
            if success {
                // Biometric successful - attempt OAuth with stored credentials
                await proceedWithOAuthFlow()
            } else {
                // Biometric failed - show fallback options
                authStep = .fallbackMethod
                error = AuthenticationFlowError.biometricFailed
            }
        } catch {
            authStep = .fallbackMethod
            self.error = AuthenticationFlowError.biometricError(error.localizedDescription)
        }
    }
    
    /// Attempt password-based authentication
    public func attemptPasswordAuthentication() async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = AuthenticationFlowError.missingCredentials
            return
        }
        
        guard !isLockedOut else {
            error = AuthenticationFlowError.accountLocked(lockoutTimeRemaining)
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // In production, call API to verify password
            // For now, mock validation
            if validatePasswordFormat(password) {
                authStep = .mfaRequired
                error = nil
            } else {
                retryCount += 1
                if retryCount >= maxRetries {
                    isLockedOut = true
                    lockoutTimeRemaining = 900 // 15 minutes
                    error = AuthenticationFlowError.accountLocked(lockoutTimeRemaining)
                    startLockoutTimer()
                } else {
                    error = AuthenticationFlowError.invalidCredentials
                }
            }
        }
    }
    
    /// Submit MFA code
    public func submitMFACode() async {
        guard !pin.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = AuthenticationFlowError.missingMFACode
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate MFA code
            if validateMFACode(pin) {
                authStep = .deviceVerification
                await proceedWithOAuthFlow()
            } else {
                error = AuthenticationFlowError.invalidMFACode
            }
        }
    }
    
    /// Proceed with OAuth authorization code flow
    public func proceedWithOAuthFlow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Request authorization code (in real app, opens browser or auth dialog)
            // For testing, you would provide the authorization code
            
            // Exchange code for tokens
            try await oauthManager.startAuthorizationFlow(authorizationCode: oauthCode)
            
            // Create session
            let device = createCurrentDevice()
            try sessionManager.createSession(user: oauthManager.currentUser!, device: device)
            
            // Store device trust if requested
            if rememberDevice {
                try await markDeviceAsTrusted(device)
            }
            
            isAuthenticated = true
            authStep = .complete
            error = nil
            retryCount = 0
        } catch let authError as AuthError {
            handleAuthError(authError)
        } catch let sessionError as SessionError {
            self.error = AuthenticationFlowError.sessionCreationFailed(sessionError.localizedDescription)
        } catch let caughtError {
            self.error = AuthenticationFlowError.unknown(caughtError.localizedDescription)
        }
    }
    
    /// Logout and clear authentication
    public func logout() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await sessionManager.terminateSession()
            await oauthManager.logout()
            
            // Reset UI state
            isAuthenticated = false
            authStep = .initial
            email = ""
            password = ""
            pin = ""
            oauthCode = ""
            error = nil
            retryCount = 0
            isLockedOut = false
        } catch {
            self.error = AuthenticationFlowError.logoutFailed(error.localizedDescription)
        }
    }
    
    /// Resume existing session on app launch
    public func attemptSessionResume() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await sessionManager.resumeStoredSession()
            
            if sessionManager.isSessionValid {
                isAuthenticated = true
                authStep = .complete
            } else {
                authStep = .initial
            }
        } catch {
            // Session resume failed, start fresh auth
            authStep = .initial
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAuthenticationMethods() {
        biometricAvailable = biometricService.isBiometricAvailable
        biometricType = biometricService.biometricType
        passwordAuthAvailable = true
    }
    
    private func validatePasswordFormat(_ password: String) -> Bool {
        // Basic validation - in production, validate against backend
        return password.count >= 8
    }
    
    private func validateMFACode(_ code: String) -> Bool {
        // Mock validation - in production, verify with backend
        return code.count == 6 && code.allSatisfy({ $0.isNumber })
    }
    
    private func createCurrentDevice() -> Device {
        return Device(
            id: UUID().uuidString,
            name: Host.current().localizedName ?? "Mac",
            type: .mac,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            isVerified: false
        )
    }
    
    private func markDeviceAsTrusted(_ device: Device) async throws {
        // In production, call API to register trusted device
        var trustedDevice = device
        trustedDevice.isVerified = true
        trustedDevice.trustToken = UUID().uuidString
        
        trustedDevices.append(trustedDevice)
    }
    
    private func handleAuthError(_ error: AuthError) {
        switch error {
        case .unauthorized:
            self.error = AuthenticationFlowError.invalidCredentials
            retryCount += 1
        case .tokenRefreshFailed:
            self.error = AuthenticationFlowError.tokenRefreshFailed
        default:
            self.error = AuthenticationFlowError.unknown(error.localizedDescription)
        }
    }
    
    private func startLockoutTimer() {
        var remainingTime = 900
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            remainingTime -= 1
            self?.lockoutTimeRemaining = remainingTime
            
            if remainingTime <= 0 {
                self?.isLockedOut = false
                self?.retryCount = 0
                self?.lockoutTimeRemaining = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 900) {
            timer.invalidate()
        }
    }
}

// MARK: - Authentication Step

public enum AuthenticationStep: Equatable {
    case initial
    case passwordEntry
    case mfaRequired
    case deviceVerification
    case fallbackMethod
    case complete
}

// MARK: - Authentication Flow Error

public enum AuthenticationFlowError: LocalizedError, Equatable {
    case noAuthMethodsAvailable
    case biometricFailed
    case biometricError(String)
    case missingCredentials
    case invalidCredentials
    case missingMFACode
    case invalidMFACode
    case accountLocked(Int) // lockout time in seconds
    case tokenRefreshFailed
    case sessionCreationFailed(String)
    case logoutFailed(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .noAuthMethodsAvailable:
            return "No authentication methods available"
        case .biometricFailed:
            return "Biometric authentication failed. Please try another method."
        case .biometricError(let reason):
            return "Biometric error: \(reason)"
        case .missingCredentials:
            return "Please enter both email and password"
        case .invalidCredentials:
            return "Invalid email or password"
        case .missingMFACode:
            return "Please enter the MFA code"
        case .invalidMFACode:
            return "Invalid MFA code. Please try again."
        case .accountLocked(let seconds):
            let minutes = seconds / 60
            return "Account locked. Try again in \(minutes) minute(s)."
        case .tokenRefreshFailed:
            return "Session token refresh failed. Please log in again."
        case .sessionCreationFailed(let reason):
            return "Failed to create session: \(reason)"
        case .logoutFailed(let reason):
            return "Logout failed: \(reason)"
        case .unknown(let reason):
            return "Authentication error: \(reason)"
        }
    }
    
    public static func == (lhs: AuthenticationFlowError, rhs: AuthenticationFlowError) -> Bool {
        switch (lhs, rhs) {
        case (.noAuthMethodsAvailable, .noAuthMethodsAvailable),
             (.biometricFailed, .biometricFailed),
             (.missingCredentials, .missingCredentials),
             (.invalidCredentials, .invalidCredentials),
             (.missingMFACode, .missingMFACode),
             (.invalidMFACode, .invalidMFACode):
            return true
        case (.accountLocked(let lhsTime), .accountLocked(let rhsTime)):
            return lhsTime == rhsTime
        case (.biometricError(let lhsMsg), .biometricError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.sessionCreationFailed(let lhsMsg), .sessionCreationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.logoutFailed(let lhsMsg), .logoutFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unknown(let lhsMsg), .unknown(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
