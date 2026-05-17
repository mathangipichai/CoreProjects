import Foundation

/// Represents a payment card (debit, credit, or virtual)
@Observable @MainActor
public final class Card: Identifiable, Codable, Hashable {
    public let id: String
    public let userId: String
    public let accountId: String
    
    // Card Details
    public var cardType: CardType
    public var cardSubType: CardSubType = .physical
    public var displayName: String
    public var lastFourDigits: String
    public var cardNetwork: CardNetwork = .visa
    
    // Card Status
    public var status: CardStatus = .active
    public var isLocked: Bool = false
    public var activationDate: Date
    public var expiryDate: Date
    public var createdDate: Date = Date()
    
    // Physical Card Info
    public var holderName: String
    public var cardImageURL: URL?
    public var pin: String? // Hashed in production
    
    // Virtual Card Info (if applicable)
    public var virtualCardNumber: String?
    public var virtualCVV: String?
    public var virtualExpiryDate: Date?
    public var merchantName: String?
    public var merchantCategory: String?
    public var isAutoExpiring: Bool = false
    public var expiresAfterUse: Bool = false
    
    // Spending Limits
    public var dailySpendingLimit: Decimal?
    public var monthlySpendingLimit: Decimal?
    public var transactionLimit: Decimal?
    public var currentMonthlySpend: Decimal = 0
    public var currentDailySpend: Decimal = 0
    
    // Card Controls
    public var contactlessEnabled: Bool = true
    public var onlineTransactionsEnabled: Bool = true
    public var atmWithdrawalEnabled: Bool = true
    public var internationalTransactionsEnabled: Bool = true
    public var allowedMerchantCategories: [String] = []
    
    // Rewards (if applicable)
    public var rewardsProgram: String?
    public var rewardsPoints: Decimal = 0
    public var cashbackPercentage: Decimal?
    
    // Linked Services
    public var isPrimary: Bool = false
    public var isLinkedToBillPay: Bool = false
    public var autoPayEnabled: Bool = false
    public var autoPayAmount: Decimal?
    
    public enum CardType: String, Codable {
        case debit, credit, prepaid
    }
    
    public enum CardSubType: String, Codable {
        case physical, virtual, digital
    }
    
    public enum CardNetwork: String, Codable {
        case visa, mastercard, amex, discover
    }
    
    public enum CardStatus: String, Codable {
        case active, inactive, blocked, expired, cancelled, reported
    }
    
    public init(
        id: String,
        userId: String,
        accountId: String,
        cardType: CardType,
        displayName: String,
        lastFourDigits: String,
        holderName: String,
        activationDate: Date = Date(),
        expiryDate: Date
    ) {
        self.id = id
        self.userId = userId
        self.accountId = accountId
        self.cardType = cardType
        self.displayName = displayName
        self.lastFourDigits = lastFourDigits
        self.holderName = holderName
        self.activationDate = activationDate
        self.expiryDate = expiryDate
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.id == rhs.id
    }
}
