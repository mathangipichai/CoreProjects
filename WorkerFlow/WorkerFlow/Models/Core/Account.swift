import Foundation

/// Represents a bank account (checking, savings, credit, investment)
@Observable @MainActor
public final class Account: Identifiable, Codable, Hashable {
    public let id: String
    public let userId: String
    public var accountNumber: String
    public var displayName: String
    public var accountType: AccountType
    public var accountSubType: String?
    
    // Balance Information
    public var currentBalance: Decimal
    public var availableBalance: Decimal
    public var pendingBalance: Decimal = 0
    public var lastUpdated: Date = Date()
    
    // Account Details
    public var currencyCode: String = "USD"
    public var status: AccountStatus = .active
    public var createdDate: Date
    public var routingNumber: String?
    public var swiftCode: String?
    
    // Interest & Fees
    public var annualPercentageYield: Decimal? // For savings accounts
    public var monthlyFee: Decimal = 0
    public var interestEarned: Decimal = 0
    
    // Limits
    public var dailyTransactionLimit: Decimal?
    public var monthlyTransactionLimit: Decimal?
    public var transferLimit: Decimal?
    
    // Settings
    public var isPrimary: Bool = false
    public var isLinkedAccount: Bool = false
    public var linkedAccountId: String?
    public var overdraftProtectionEnabled: Bool = false
    
    public enum AccountType: String, Codable {
        case checking, savings, credit, investment, loan, creditLine = "credit_line"
    }
    
    public enum AccountStatus: String, Codable {
        case active, inactive, closed, suspended
    }
    
    public init(
        id: String,
        userId: String,
        accountNumber: String,
        displayName: String,
        accountType: AccountType,
        currentBalance: Decimal,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.accountNumber = accountNumber
        self.displayName = displayName
        self.accountType = accountType
        self.currentBalance = currentBalance
        self.availableBalance = currentBalance
        self.createdDate = createdDate
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}
