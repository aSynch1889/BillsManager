import SwiftUI

struct PasscodeLockView: View {
    @Environment(BiometricAuthManager.self) private var authManager
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text(NSLocalizedString("Bills Manager Locked", comment: ""))
                    .font(.title2.bold())
                
                Text(NSLocalizedString("Authentication is required to access your financial data.", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    Task {
                        _ = await authManager.authenticate()
                    }
                }) {
                    HStack {
                        Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text(String(format: NSLocalizedString("Unlock with %@", comment: ""), authManager.biometricName))
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: 260)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                if let error = authManager.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .onAppear {
            Task {
                _ = await authManager.authenticate()
            }
        }
    }
}
