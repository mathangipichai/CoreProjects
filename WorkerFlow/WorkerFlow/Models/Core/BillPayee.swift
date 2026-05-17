import Foundation

/// Represents a bill payee (utility company, loan servicer, etc.)
@Observable @MainActor
public final class BillPayee: Identifiable, Codable, Hashable {
    public let id: String
    public let userId: String
    
    // Payee Information
    public var name: String
    public var category: BillCategory = .utilities
    public var accountNumber: String
    public var accountNumberMasked: String
    public var routingNumber: String?
    public var payeeType: PayeeType = .business
    
    // Contact Information
    public var phoneNumber: String?
    public var website: URL?
    public var email: String?
    public var mailing: MailingAddress?
    
    // Payment Information
    public var minimumPaymentAmount: Decimal?
    public var paymentDueDate: Int? // Day of month
    public var gracePeriodDays: Int = 0
    public var standardDeliveryDays: Int = 3
    
    // Bill Tracking
    public var lastPaymentDate: Date?
    public var lastPaymentAmount: Decimal?
    public var currentBalance: Decimal?
    public var dueAmount: Decimal?
    public var statementDate: Date?
    
    // Autopay Setup
    public var autopayEnabled: Bool = false
    public var autopayAmount: Decimal?
    public var autopayFrequency: AutopayFrequency = .monthly
    public var autopayDay: Int?
    public var autopayNextDate: Date?
    
    // Preferences
    public var isFavorite: Bool = false
    public var nickname: String?
    public var paymentIcon: URL?
    public var logoURL: URL?
    
    public enum BillCategory: String, Codable {
        case utilities, insurance, loan, creditCard = "credit_card"
        case mortgage, rent, medical, subscriptions, other
    }
    
    public enum PayeeType: String, Codable {
        case business, individual, government
    }
    
    public enum AutopayFrequency: String, Codable {
        case weekly, biweekly, monthly, quarterly, annual, asNeeded = "as_needed"
    }
    
    public struct MailingAddress: Codable, Hashable {
        public var street: String
        public var city: String
        public var state: String
        public var zipCode: String
        public var country: String = "USA"
        
        public init(street: String, city: String, state: String, zipCode: String) {
            self.street = street
            self.city = city
            self.state = state
            self.zipCode = zipCode
        }
    }
    
    public init(
        id: String,
        userId: String,
        name: String,
        accountNumber: String,
        accountNumberMasked: String
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.accountNumber = accountNumber
        self.accountNumberMasked = accountNumberMasked
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: BillPayee, rhs: BillPayee) -> Bool {
        lhs.id == rhs.id
    }
}
