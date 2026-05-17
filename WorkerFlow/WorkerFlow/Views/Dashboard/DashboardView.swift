import SwiftUI

/// Dashboard view showing account summaries and quick actions
struct DashboardView: View {
    @Environment(BankingViewModel.self) var viewModel
    @State private var showingTransferSheet = false
    @State private var showingPayBillSheet = false
    
    var totalBalance: Decimal {
        viewModel.accounts.reduce(0) { $0 + $1.currentBalance }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Balance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(formatCurrency(totalBalance, currency: viewModel.currentUser?.preferredCurrency ?? "USD"))
                            .font(.system(size: 36, weight: .bold, design: .default))
                            .contentTransition(.numericText())
                        
                        if let lastUpdate = viewModel.lastSyncTime {
                            Text("Updated \(formatTime(lastUpdate))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Quick Actions
                    VStack(spacing: 12) {
                        Label("Quick Actions", systemImage: "bolt.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            QuickActionButton(
                                title: "Transfer",
                                icon: "arrow.left.arrow.right",
                                color: .blue
                            ) {
                                showingTransferSheet = true
                            }
                            
                            QuickActionButton(
                                title: "Pay Bill",
                                icon: "bill",
                                color: .green
                            ) {
                                showingPayBillSheet = true
                            }
                            
                            QuickActionButton(
                                title: "Deposit",
                                icon: "doc.text.below.ecg",
                                color: .orange
                            ) {
                                // Deposit check flow
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Accounts Summary
                    VStack(spacing: 12) {
                        Label("Your Accounts", systemImage: "creditcard.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        if viewModel.isLoadingAccounts {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.accounts.isEmpty {
                            ContentUnavailableView(
                                "No Accounts",
                                systemImage: "creditcard.slash",
                                description: Text("You don't have any accounts yet.")
                            )
                            .padding()
                        } else {
                            VStack(spacing: 10) {
                                ForEach(viewModel.accounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountSummaryCell(account: account)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingTransferSheet) {
                TransferSetupView(isPresented: $showingTransferSheet)
            }
            .sheet(isPresented: $showingPayBillSheet) {
                PayBillSetupView(isPresented: $showingPayBillSheet)
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
        }
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .foregroundStyle(.white)
            .background(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Account Summary Cell

private struct AccountSummaryCell: View {
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.headline)
                    
                    Text(account.accountType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(formatCurrency(account.currentBalance, currency: "USD"))
                    .font(.headline)
                    .contentTransition(.numericText())
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(account.availableBalance, currency: "USD"))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(account.accountStatus == .active ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text(account.accountStatus.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Helper Views (Stubs)

struct TransferSetupView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Transfer Setup")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") { isPresented = false }
            }
            .navigationTitle("Transfer Money")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PayBillSetupView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Pay Bill Setup")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") { isPresented = false }
            }
            .navigationTitle("Pay a Bill")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Utility Functions

private func formatCurrency(_ value: Decimal, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
}

private func formatTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(BankingViewModel())
}
