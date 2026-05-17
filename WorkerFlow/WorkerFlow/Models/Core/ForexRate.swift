import Foundation

/// Represents foreign exchange rates and conversion data
@Observable @MainActor
public final class ForexRate: Identifiable, Codable, Hashable {
    public let id: String
    public let userId: String
    
    // Currency Pair
    public var baseCurrency: String
    public var quoteCurrency: String
    public var currencyPair: String { "\(baseCurrency)/\(quoteCurrency)" }
    
    // Exchange Rates
    public var bid: Decimal // Bank's buying rate
    public var ask: Decimal // Bank's selling rate
    public var midRate: Decimal // Average rate
    public var lastUpdated: Date = Date()
    
    // Rate History
    public var openRate: Decimal?
    public var highRate: Decimal?
    public var lowRate: Decimal?
    public var previousClose: Decimal?
    
    // Spread & Fees
    public var spread: Decimal { ask - bid }
    public var margin: Decimal? // Bank's markup percentage
    public var transactionFee: Decimal?
    
    // Favorites & Monitoring
    public var isFavorite: Bool = false
    public var isWatched: Bool = false
    public var lastConversionAmount: Decimal?
    public var lastConversionDate: Date?
    
    // Real-time Indicators
    public var isUpdating: Bool = false
    public var updateFrequency: UpdateFrequency = .realtime
    public var dataSource: String = "market_data"
    
    public enum UpdateFrequency: String, Codable {
        case realtime, hourly, daily
    }
    
    public init(
        id: String,
        userId: String,
        baseCurrency: String,
        quoteCurrency: String,
        bid: Decimal,
        ask: Decimal
    ) {
        self.id = id
        self.userId = userId
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.bid = bid
        self.ask = ask
        self.midRate = (bid + ask) / 2
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ForexRate, rhs: ForexRate) -> Bool {
        lhs.id == rhs.id
    }
}
