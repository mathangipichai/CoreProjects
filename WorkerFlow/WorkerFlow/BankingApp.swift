import SwiftUI

/// Main app entry point and root view routing
@main
struct BankingApp: App {
    @State private var viewModel = BankingViewModel.shared
    @State private var authManager = OAuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    // Main app after authentication
                    BankingMainView()
                        .environment(viewModel)
                } else if authManager.isAuthenticating {
                    // Loading/authenticating state
                    ProgressView("Authenticating...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Login/auth view
                    AuthenticationView()
                        .environment(authManager)
                }
            }
            .task {
                await viewModel.initializeApp()
            }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @Environment(OAuthManager.self) var authManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var authorizationCode: String = ""
    @State private var showCodeInput = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                VStack(spacing: 4) {
                    Text("Banking App")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Secure Financial Management")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error Alert
            if let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Authentication Failed")
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: { errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    Text(error)
                        .font(.caption)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Auth Code Input
            VStack(spacing: 12) {
                if showCodeInput {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Authorization Code")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        TextField("Enter authorization code", text: $authorizationCode)
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, 4)
                        
                        Text("Get your authorization code from the banking portal and paste it here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Login Button
                Button(action: {
                    if showCodeInput && !authorizationCode.isEmpty {
                        Task {
                            await handleOAuthFlow()
                        }
                    } else {
                        showCodeInput = true
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8, anchor: .center)
                        }
                        Text(showCodeInput ? "Authenticate" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
            }
            
            Spacer()
            
            // Security Info
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Secure Connection")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("End-to-end encrypted")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy Protected")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Your data is encrypted")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
    
    private func handleOAuthFlow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.startAuthorizationFlow(authorizationCode: authorizationCode)
            errorMessage = nil
        } catch let error {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Main App View

struct BankingMainView: View {
    @Environment(BankingViewModel.self) var viewModel
    
    var body: some View {
        Text("Banking Main App")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
}

// #Preview {
//     BankingApp()
// }
