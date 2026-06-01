import SwiftUI

struct CoinShopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var currentBalance: Int = 0
    @State private var freePasses: Int = 0
    @State private var gems: Int = 0
    
    var body: some View {
        ZStack {
            Color.mlBg.ignoresSafeArea()
            
            // Decorative background blurs
            VStack {
                HStack {
                    Circle()
                        .fill(Color.mlPurple.opacity(0.12))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: -50, y: -20)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.mlPink.opacity(0.10))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: 50, y: 50)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(Color.mlPurple)
                        .scaleEffect(1.2)
                    Text("Loading wallet...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mlSubtext)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        // Wallet Card
                        VStack(spacing: 20) {
                            Text("YOUR WALLET")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.mlSubtext)
                                .tracking(1.5)
                            
                            HStack(spacing: 0) {
                                // Coins
                                WalletDetailItem(
                                    icon: "bitcoinsign.circle.fill",
                                    amount: "\(currentBalance)",
                                    label: "Coins",
                                    color: Color.mlGold
                                )
                                
                                Spacer()
                                
                                // Free Pass
                                WalletDetailItem(
                                    icon: "ticket.fill",
                                    amount: "\(freePasses)",
                                    label: "Free Pass",
                                    color: Color(red: 0.2, green: 0.8, blue: 0.9)
                                )
                            }
                        }
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mlCard.opacity(0.92)))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Informational Banner
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "gift.fill")
                                    .foregroundStyle(Color.mlPink)
                                    .font(.system(size: 18))
                                Text("Earn Free Coins")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                            
                            Text("In this version of the app, coin purchasing is disabled. Instead, the coin system functions as points you can earn completely free through in-app achievements!")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.mlSubtext)
                                .lineSpacing(4)
                            
                            Text("💡 How to get more coins:")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                BulletPointRow(text: "Check in daily to claim escalating rewards.")
                                BulletPointRow(text: "Keep up your reading streak for multiplier bonuses.")
                                BulletPointRow(text: "Complete daily tasks like reading for 10 minutes.")
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Navigate to Daily Rewards Button
                        NavigationLink(destination: DailyRewardsView()) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                Text("Go to Daily Rewards")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.mlPurple, Color.mlPurpleDim],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Coin Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWallet()
        }
    }
    
    private func loadWallet() async {
        isLoading = true
        errorMessage = nil
        do {
            let me = try await NetworkService.shared.fetchMe()
            await MainActor.run {
                self.currentBalance = me.wallet.coins
                self.freePasses = me.wallet.freePass
                self.gems = me.wallet.gems
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct WalletDetailItem: View {
    let icon: String
    let amount: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                Text(amount)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mlSubtext)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BulletPointRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundStyle(Color.mlPink)
                .font(.system(size: 14, weight: .bold))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.mlSubtext)
        }
    }
}
