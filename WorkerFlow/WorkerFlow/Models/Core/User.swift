import Foundation

/// Represents a banking user profile with authentication and preferences
@Observable @MainActor
public final class User: Identifiable, Codable, Hashable {
    public let id: String
    public var email: String
    public var fullName: String
    public var phoneNumber: String?
    public var profileImageURL: URL?
    
    // Authentication & Security
    public var oauthToken: String?
    public var tokenExpiresAt: Date?
    public var refreshToken: String?
    public var biometricEnabled: Bool = false
    public var lastLoginDate: Date = Date()
    
    // User Preferences
    public var preferredCurrency: String = "USD"
    public var preferredLanguage: String = "en"
    public var timeZone: String = TimeZone.current.identifier
    public var notificationsEnabled: Bool = true
    
    // Account Settings
    public var accountStatus: AccountStatus = .active
    public var twoFactorEnabled: Bool = false
    public var defaultTransferAccount: String?
    
    // GDPR & Privacy
    public var dataCollectionConsent: Bool = false
    public var consentDate: Date?
    public var dataExportRequested: Bool = false
    public var dataDeleteRequested: Bool = false
    
    public enum AccountStatus: String, Codable {
        case active, suspended, closed
    }
    
    public init(
        id: String,
        email: String,
        fullName: String,
        phoneNumber: String? = nil
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.phoneNumber = phoneNumber
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
