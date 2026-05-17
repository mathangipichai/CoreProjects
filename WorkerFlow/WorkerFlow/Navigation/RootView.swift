import SwiftUI

/// Root application navigation with tab-based interface
@MainActor
struct RootView: View {
    @Environment(BankingViewModel.self) var viewModel
    @State private var selectedTab: AppTab = .dashboard
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(AppTab.dashboard)
            
            // Accounts Tab
            AccountListView()
                .tabItem {
                    Label("Accounts", systemImage: "creditcard.fill")
                }
                .tag(AppTab.accounts)
            
            // Cards Tab
            CardListView()
                .tabItem {
                    Label("Cards", systemImage: "creditcard")
                }
                .tag(AppTab.cards)
            
            // Transfers Tab
            TransfersView()
                .tabItem {
                    Label("Transfer", systemImage: "arrow.left.arrow.right")
                }
                .tag(AppTab.transfers)
            
            // Investments Tab
            InvestmentsView()
                .tabItem {
                    Label("Invest", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.investments)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .task {
            await viewModel.initializeApp()
        }
    }
}

// MARK: - Tab Enum

enum AppTab {
    case dashboard
    case accounts
    case cards
    case transfers
    case investments
    case settings
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(BankingViewModel())
}
