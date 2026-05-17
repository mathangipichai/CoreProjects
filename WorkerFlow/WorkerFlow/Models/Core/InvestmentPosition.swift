import Foundation

/// Represents an investment holding (stocks, ETFs, mutual funds)
@Observable @MainActor
public final class InvestmentPosition: Identifiable, Codable, Hashable {
    public let id: String
    public let userId: String
    public let accountId: String
    
    // Position Details
    public var symbol: String // Stock ticker/CUSIP
    public var displayName: String
    public var securityType: SecurityType
    public var quantity: Decimal
    public var quantityUnit: String = "shares"
    
    // Pricing Information
    public var purchasePrice: Decimal
    public var currentPrice: Decimal
    public var lastPriceUpdate: Date = Date()
    public var currency: String = "USD"
    
    // Performance Metrics
    public var totalCost: Decimal
    public var currentValue: Decimal
    public var gainLoss: Decimal
    public var gainLossPercentage: Decimal
    public var purchaseDate: Date
    
    // Asset Allocation
    public var assetClass: AssetClass = .stocks
    public var sector: String?
    public var industry: String?
    public var region: String?
    
    // Dividend & Income
    public var dividendYield: Decimal?
    public var annualDividendPerShare: Decimal?
    public var totalDividendsReceived: Decimal = 0
    public var nextDividendDate: Date?
    
    // Trading Information
    public var averageCostPerShare: Decimal
    public var holdingPeriod: HoldingPeriod
    public var isFractionalShare: Bool = false
    public var canBeSold: Bool = true
    
    // Alerts & Monitoring
    public var isPinnedToWatchlist: Bool = false
    public var priceAlert: Decimal?
    public var alertType: AlertType = .none
    
    public enum SecurityType: String, Codable {
        case stock, etf, mutualFund = "mutual_fund"
        case bond, commodity, crypto, option
    }
    
    public enum AssetClass: String, Codable {
        case stocks, bonds, commodities, realEstate = "real_estate"
        case crypto, alternatives, cash
    }
    
    public enum HoldingPeriod: String, Codable {
        case shortTerm, longTerm
    }
    
    public enum AlertType: String, Codable {
        case none, above, below, both
    }
    
    public init(
        id: String,
        userId: String,
        accountId: String,
        symbol: String,
        displayName: String,
        securityType: SecurityType,
        quantity: Decimal,
        purchasePrice: Decimal,
        currentPrice: Decimal,
        purchaseDate: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.accountId = accountId
        self.symbol = symbol
        self.displayName = displayName
        self.securityType = securityType
        self.quantity = quantity
        self.purchasePrice = purchasePrice
        self.currentPrice = currentPrice
        self.purchaseDate = purchaseDate
        
        let totalCost = purchasePrice * quantity
        let currentValue = currentPrice * quantity
        let gain = currentValue - totalCost
        
        self.totalCost = totalCost
        self.currentValue = currentValue
        self.gainLoss = gain
        self.gainLossPercentage = totalCost > 0 ? (gain / totalCost) * 100 : 0
        self.averageCostPerShare = purchasePrice
        
        let yearsHeld = Calendar.current.dateComponents([.year], from: purchaseDate, to: Date()).year ?? 0
        self.holdingPeriod = yearsHeld >= 1 ? .longTerm : .shortTerm
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: InvestmentPosition, rhs: InvestmentPosition) -> Bool {
        lhs.id == rhs.id
    }
}
