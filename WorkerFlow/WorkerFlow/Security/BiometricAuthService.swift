import Foundation
import LocalAuthentication

/// Service for biometric authentication (Face ID / Touch ID) on macOS and iOS
@MainActor
public final class BiometricAuthService {
    public static let shared = BiometricAuthService()
    
    private let context = LAContext()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if device supports biometric authentication
    public var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get the type of biometric available (Face ID or Touch ID)
    public var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        @unknown default:
            return .unknown
        }
    }
    
    /// Authenticate user with biometric
    /// - Parameter reason: User-facing reason string for biometric prompt
    /// - Returns: Boolean indicating success or failure
    public func authenticateWithBiometric(reason: String = "Authenticate to access your banking information") async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            return false
        }
    }
    
    /// Authenticate with biometric or passcode fallback
    /// - Parameter reason: User-facing reason string
    /// - Returns: Boolean indicating authentication success
    public func authenticateWithBiometricOrPasscode(reason: String = "Authenticate to access your banking information") async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
              context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        
        do {
            // Try biometric first
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                return try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
            }
            
            // Fall back to passcode
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
    
    /// Setup biometric authentication preference
    public func enableBiometric() throws {
        guard isBiometricAvailable else {
            throw BiometricError.biometricNotAvailable
        }
        try KeychainService.shared.storeBiometricPreference(true)
    }
    
    /// Disable biometric authentication preference
    public func disableBiometric() throws {
        try KeychainService.shared.storeBiometricPreference(false)
    }
    
    /// Check if biometric is enabled in preferences
    public func isBiometricEnabled() throws -> Bool {
        return try KeychainService.shared.retrieveBiometricPreference()
    }
    
    // MARK: - Private Methods
    
    private func evaluateBiometricPolicy(
        reason: String,
        context: LAContext
    ) async throws -> Bool {
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}

// MARK: - Biometric Types

public enum BiometricType {
    case faceID
    case touchID
    case opticID
    case unknown
    case none
    
    public var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .unknown:
            return "Biometric"
        case .none:
            return "None"
        }
    }
}

// MARK: - Biometric Error

public enum BiometricError: LocalizedError {
    case biometricNotAvailable
    case authenticationFailed
    case userCancelled
    case passcodeNotSet
    case keychainError(String)
    
    public var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .userCancelled:
            return "Authentication was cancelled by the user"
        case .passcodeNotSet:
            return "Device passcode is not set"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}
