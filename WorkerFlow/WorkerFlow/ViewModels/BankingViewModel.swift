import Foundation

/// Root application state management for the banking app
@Observable @MainActor
public final class BankingViewModel {
    
    // MARK: - Authentication State
    public var isAuthenticated = false
    public var currentUser: User?
    public var authError: AuthError?
    public var isAuthenticating = false
    
    // MARK: - Accounts State
    public var accounts: [Account] = []
    public var selectedAccount: Account?
    public var isLoadingAccounts = false
    public var accountsError: Error?
    
    // MARK: - Transactions State
    public var transactions: [Transaction] = []
    public var selectedTransaction: Transaction?
    public var isLoadingTransactions = false
    public var transactionsError: Error?
    
    // MARK: - Cards State
    public var cards: [Card] = []
    public var selectedCard: Card?
    public var isLoadingCards = false
    public var cardsError: Error?
    
    // MARK: - Investments State
    public var investmentPositions: [InvestmentPosition] = []
    public var investmentPortfolioValue: Decimal = 0
    public var investmentPortfolioGainLoss: Decimal = 0
    public var isLoadingInvestments = false
    public var investmentsError: Error?
    
    // MARK: - Payees & Transfers
    public var billPayees: [BillPayee] = []
    public var favoritePayees: [BillPayee] = []
    public var isLoadingPayees = false
    public var payeesError: Error?
    
    // MARK: - Forex State
    public var forexRates: [ForexRate] = []
    public var watchedCurrencyPairs: [String] = []
    public var isLoadingForex = false
    public var forexError: Error?
    
    // MARK: - App State
    public var isOnline: Bool = true
    public var isSyncing: Bool = false
    public var syncError: Error?
    public var lastSyncTime: Date?
    
    // MARK: - Initialization
    
    public static let shared = BankingViewModel()
    
    public init() {
        Task {
            await setupObservers()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize app with stored session or start fresh
    public func initializeApp() async {
        await OAuthManager.shared.validateStoredSession()
        
        if OAuthManager.shared.isAuthenticated {
            isAuthenticated = true
            currentUser = OAuthManager.shared.currentUser
            
            // Load initial data
            await loadDashboardData()
        }
    }
    
    /// Load all dashboard data (accounts, cards, transactions)
    public func loadDashboardData() async {
        async let accountsTask = loadAccounts()
        async let cardsTask = loadCards()
        async let payeesTask = loadPayees()
        
        _ = await (accountsTask, cardsTask, payeesTask)
    }
    
    /// Load user accounts
    public func loadAccounts() async {
        isLoadingAccounts = true
        defer { isLoadingAccounts = false }
        
        do {
            // In production, call APIClient
            // let accounts: [Account] = try await APIClient.shared.get(
            //     endpoint: "/accounts",
            //     responseType: [Account].self
            // )
            // self.accounts = accounts
            
            // For now, use empty array (mock data)
            self.accounts = []
        } catch {
            accountsError = error
        }
    }
    
    /// Load user cards
    public func loadCards() async {
        isLoadingCards = true
        defer { isLoadingCards = false }
        
        do {
            // In production, call APIClient
            self.cards = []
        } catch {
            cardsError = error
        }
    }
    
    /// Load transactions for selected account
    public func loadTransactions(for account: Account) async {
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }
        
        do {
            // In production, call APIClient
            self.transactions = []
            self.selectedAccount = account
        } catch {
            transactionsError = error
        }
    }
    
    /// Load bill payees
    public func loadPayees() async {
        isLoadingPayees = true
        defer { isLoadingPayees = false }
        
        do {
            // In production, call APIClient
            self.billPayees = []
            self.favoritePayees = []
        } catch {
            payeesError = error
        }
    }
    
    /// Load investment portfolio
    public func loadInvestments() async {
        isLoadingInvestments = true
        defer { isLoadingInvestments = false }
        
        do {
            // In production, call APIClient
            self.investmentPositions = []
            calculatePortfolioMetrics()
        } catch {
            investmentsError = error
        }
    }
    
    /// Load forex rates
    public func loadForexRates() async {
        isLoadingForex = true
        defer { isLoadingForex = false }
        
        do {
            // In production, call APIClient
            self.forexRates = []
        } catch {
            forexError = error
        }
    }
    
    /// Select an account and load its transactions
    public func selectAccount(_ account: Account) async {
        selectedAccount = account
        await loadTransactions(for: account)
    }
    
    /// Logout current user
    public func logout() async {
        await OAuthManager.shared.logout()
        
        // Clear all app state
        isAuthenticated = false
        currentUser = nil
        accounts = []
        cards = []
        transactions = []
        billPayees = []
        investmentPositions = []
        forexRates = []
        selectedAccount = nil
    }
    
    /// Perform a transfer between accounts
    public func performTransfer(
        from: Account,
        to: Account,
        amount: Decimal,
        memo: String?
    ) async throws {
        // In production, call APIClient
        // try await APIClient.shared.post(
        //     endpoint: "/transfers",
        //     body: TransferRequest(fromId: from.id, toId: to.id, amount: amount, memo: memo),
        //     responseType: Transaction.self
        // )
        
        // Reload accounts to reflect new balances
        await loadAccounts()
    }
    
    /// Sync all data with backend
    public func syncData() async {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            lastSyncTime = Date()
            await loadDashboardData()
        } catch {
            syncError = error
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() async {
        // Monitor network connectivity
        // Monitor authentication state changes
        // Setup background sync timers
    }
    
    private func calculatePortfolioMetrics() {
        var totalValue: Decimal = 0
        var totalCost: Decimal = 0
        
        for position in investmentPositions {
            totalValue += position.currentValue
            totalCost += position.totalCost
        }
        
        investmentPortfolioValue = totalValue
        investmentPortfolioGainLoss = totalValue - totalCost
    }
}
