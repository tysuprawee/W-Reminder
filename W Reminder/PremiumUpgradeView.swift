import SwiftUI
import StoreKit

class StoreManager: ObservableObject {
    static let shared = StoreManager()
    @Published var isPro: Bool = false
    
    // Placeholder for actual StoreKit logic
    func purchasePro() {
        // Mock purchase
        withAnimation {
            isPro = true
        }
    }
    
    func restorePurchases() {
        withAnimation {
            isPro = true
        }
    }
}

struct PremiumUpgradeView: View {
    @StateObject private var store = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    let theme: Theme
    
    var body: some View {
        ZStack {
            // Animated Background
            LinearGradient(
                colors: [theme.background, theme.accent.opacity(0.2), theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding()
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .orange.opacity(0.3), radius: 20)
                        )
                    
                    Text("Unlock Full Potential")
                        .font(.largeTitle.bold())
                        .foregroundStyle(theme.primary)
                    
                    Text("Supercharge your productivity")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                }
                .padding(.top, 40)
                
                // Features Grid
                VStack(spacing: 16) {
                    FeatureRow(icon: "icloud.fill", title: "Cloud Sync & Backup", desc: "Sync across all devices. (Free for now!)", theme: theme)
                    FeatureRow(icon: "chart.xyaxis.line", title: "Productivity Insights", desc: "Analyze your habits with advanced charts.", theme: theme)
                    FeatureRow(icon: "app.gift.fill", title: "Exclusive Customization", desc: "Unlock premium app icons and themes.", theme: theme)
                    FeatureRow(icon: "sparkles", title: "AI Smart Scheduling", desc: "Auto-plan your day for maximum efficiency.", theme: theme)
                    
                    Text("And more coming soon...")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
                
                Spacer()
                
                // Purchase Buttons
                VStack(spacing: 12) {
                    Button {
                        // Action disabled for now
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Subscriptions Coming Soon")
                                    .font(.headline)
                                Text("We are working hard on these features!")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "clock.fill")
                                .font(.title3)
                                .padding(6)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray) // Greyed out
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(true)
                    
                    Button {
                        // store.restorePurchases()
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondary)
                            .opacity(0.5)
                    }
                    .disabled(true)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    let theme: Theme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.primary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        }
    }
}

#Preview {
    PremiumUpgradeView(theme: .default)
}
