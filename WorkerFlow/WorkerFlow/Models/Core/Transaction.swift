import Foundation

/// Represents a financial transaction (debit, credit, transfer, etc.)
@Observable @MainActor
public final class Transaction: Identifiable, Codable, Hashable {
    public let id: String
    public let accountId: String
    public let userId: String
    
    // Transaction Details
    public var amount: Decimal
    public var currency: String = "USD"
    public var transactionType: TransactionType
    public var description: String
    public var memo: String?
    
    // Counterparty Information
    public var counterpartyName: String?
    public var counterpartyAccountNumber: String?
    public var counterpartyRoutingNumber: String?
    public var counterpartyImageURL: URL?
    
    // Status & Dates
    public var status: TransactionStatus = .pending
    public var postedDate: Date?
    public var transactionDate: Date
    public var settlementDate: Date?
    public var expectedDeliveryDate: Date?
    
    // Additional Information
    public var category: TransactionCategory = .uncategorized
    public var tags: [String] = []
    public var referenceNumber: String?
    public var confirmationNumber: String?
    public var receiptURL: URL?
    
    // Transfer Specific
    public var isRecurring: Bool = false
    public var recurringFrequency: RecurrenceFrequency?
    public var linkedTransactionId: String?
    
    // Dispute Information
    public var isDisputed: Bool = false
    public var disputeReason: String?
    
    public enum TransactionType: String, Codable {
        case debit, credit, transfer, withdrawal, deposit
        case payment, billPay = "bill_pay"
        case checkDeposit = "check_deposit", atmWithdrawal = "atm_withdrawal"
        case fee, interest, other
    }
    
    public enum TransactionStatus: String, Codable {
        case pending, posted, completed, failed, reversed, cancelled
    }
    
    public enum TransactionCategory: String, Codable {
        case groceries, restaurants, shopping, travel
        case utilities, rent, salary, investment
        case uncategorized = "other"
    }
    
    public enum RecurrenceFrequency: String, Codable {
        case daily, weekly, biweekly, monthly, quarterly, annual
    }
    
    public init(
        id: String,
        accountId: String,
        userId: String,
        amount: Decimal,
        transactionType: TransactionType,
        description: String,
        transactionDate: Date = Date()
    ) {
        self.id = id
        self.accountId = accountId
        self.userId = userId
        self.amount = amount
        self.transactionType = transactionType
        self.description = description
        self.transactionDate = transactionDate
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }
}
