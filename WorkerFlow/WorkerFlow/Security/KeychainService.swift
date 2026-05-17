import Foundation
import Security

/// Secure storage service for credentials, tokens, and sensitive data using iOS Keychain
@MainActor
public final class KeychainService: Sendable {
    public static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Keys
    private enum Keys {
        static let accessToken = "banking_access_token"
        static let refreshToken = "banking_refresh_token"
        static let tokenExpiryDate = "banking_token_expiry"
        static let userID = "banking_user_id"
        static let biometricEnabled = "banking_biometric_enabled"
        static let deviceCertificate = "banking_device_cert"
        static let certificatePinningKey = "banking_cert_pinning"
    }
    
    // MARK: - Public Methods
    
    /// Store access token securely
    public func storeAccessToken(_ token: String) throws {
        try store(token, forKey: Keys.accessToken, attributes: [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ])
    }
    
    /// Retrieve stored access token
    public func retrieveAccessToken() throws -> String? {
        return try retrieve(forKey: Keys.accessToken)
    }
    
    /// Store refresh token securely
    public func storeRefreshToken(_ token: String) throws {
        try store(token, forKey: Keys.refreshToken, attributes: [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ])
    }
    
    /// Retrieve stored refresh token
    public func retrieveRefreshToken() throws -> String? {
        return try retrieve(forKey: Keys.refreshToken)
    }
    
    /// Store token expiry date
    public func storeTokenExpiryDate(_ date: Date) throws {
        let data = try JSONEncoder().encode(date)
        try storeData(data, forKey: Keys.tokenExpiryDate)
    }
    
    /// Retrieve token expiry date
    public func retrieveTokenExpiryDate() throws -> Date? {
        guard let data = try retrieveData(forKey: Keys.tokenExpiryDate) else {
            return nil
        }
        return try JSONDecoder().decode(Date.self, from: data)
    }
    
    /// Store user ID
    public func storeUserID(_ userID: String) throws {
        try store(userID, forKey: Keys.userID)
    }
    
    /// Retrieve user ID
    public func retrieveUserID() throws -> String? {
        return try retrieve(forKey: Keys.userID)
    }
    
    /// Store biometric preference
    public func storeBiometricPreference(_ enabled: Bool) throws {
        try store(enabled ? "true" : "false", forKey: Keys.biometricEnabled)
    }
    
    /// Retrieve biometric preference
    public func retrieveBiometricPreference() throws -> Bool {
        let value = try retrieve(forKey: Keys.biometricEnabled)
        return value == "true"
    }
    
    /// Store certificate for pinning
    public func storeCertificatePinning(_ certificate: SecCertificate) throws {
        let certificateData = SecCertificateCopyData(certificate) as Data
        try storeData(certificateData, forKey: Keys.certificatePinningKey)
    }
    
    /// Retrieve certificate for pinning
    public func retrieveCertificatePinning() throws -> SecCertificate? {
        guard let data = try retrieveData(forKey: Keys.certificatePinningKey) else {
            return nil
        }
        return SecCertificateCreateWithData(nil, data as CFData)
    }
    
    /// Delete all stored credentials (logout)
    public func deleteAllCredentials() throws {
        try delete(forKey: Keys.accessToken)
        try delete(forKey: Keys.refreshToken)
        try delete(forKey: Keys.tokenExpiryDate)
        try delete(forKey: Keys.userID)
        try delete(forKey: Keys.biometricEnabled)
    }
    
    // MARK: - Private Methods
    
    private func store(_ value: String, forKey key: String, attributes: [String: Any] = [:]) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try storeData(data, forKey: key, attributes: attributes)
    }
    
    private func storeData(_ data: Data, forKey key: String, attributes: [String: Any] = [:]) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Try to update existing
        SecItemDelete(query as CFDictionary)
        
        var finalQuery = query
        finalQuery.merge(attributes) { (current, _) in current }
        
        let status = SecItemAdd(finalQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    private func retrieve(forKey key: String) throws -> String? {
        guard let data = try retrieveData(forKey: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private func retrieveData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status)
        }
    }
    
    private func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Error

public enum KeychainError: LocalizedError {
    case encodingFailed
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for Keychain storage"
        case .storeFailed(let status):
            return "Failed to store in Keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}
