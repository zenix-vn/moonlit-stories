import SwiftUI

struct ProfileView: View {
    @State private var meResponse: MeResponse? = nil
    @State private var isSubscribed = false
    @State private var subscriptionDetail: SubscriptionDetail? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    // Streak / stats (mock data or values based on user profiles)
    @State private var readingHours = 12.4
    @State private var activeStreak = 5
    @State private var episodesUnlocked = 38
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background matching Moonlit theme
                Color.mlBg.ignoresSafeArea()
                
                // Decorative background blurs
                ZStack {
                    Circle()
                        .fill(Color.mlPurple.opacity(0.15))
                        .frame(width: 320, height: 320)
                        .blur(radius: 90)
                        .offset(x: -100, y: -150)
                    
                    Circle()
                        .fill(Color.mlPink.opacity(0.08))
                        .frame(width: 240, height: 240)
                        .blur(radius: 80)
                        .offset(x: 120, y: 150)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Header spacer
                        Spacer().frame(height: 20)
                        
                        // LOADING / PROFILE MAIN CONTENT
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(Color.mlPurple)
                                    .scaleEffect(1.2)
                                Text("Loading profile...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.mlSubtext)
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        } else {
                            VStack(spacing: 24) {
                                // User Identity Card
                                UserHeaderView(
                                    user: meResponse?.user,
                                    profile: meResponse?.profile,
                                    isSubscribed: isSubscribed
                                )
                                
                                // Wallet Card (Coins, Gems, Passes)
                                WalletStatusCard(wallet: meResponse?.wallet)
                                
                                // Stats Grid
                                StatsGridView(
                                    readingHours: readingHours,
                                    activeStreak: activeStreak,
                                    episodesUnlocked: episodesUnlocked
                                )
                                
                                // Menu Options List
                                ProfileMenuList(isSubscribed: isSubscribed)
                            }
                        }
                        
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                }
                .refreshable {
                    await loadProfileData()
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadProfileData()
        }
    }
    
    private func loadProfileData() async {
        do {
            async let meTask = NetworkService.shared.fetchMe()
            async let subTask = NetworkService.shared.fetchSubscription()
            
            let (me, sub) = try await (meTask, subTask)
            
            await MainActor.run {
                self.meResponse = me
                self.isSubscribed = sub.isSubscribed
                self.subscriptionDetail = sub.subscription
                
                // Set mock values for demonstration
                self.readingHours = 8.0 + Double(abs(me.user.id.hashValue) % 15) + (Double(abs(me.user.level) % 10) / 10.0)
                self.activeStreak = 2 + (abs(me.user.id.hashValue) % 10)
                self.episodesUnlocked = 12 + (abs(me.user.level * 4) % 40)
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("Failed to load profile data: \(error)")
        }
    }
}

// MARK: - Subviews

struct UserHeaderView: View {
    let user: User?
    let profile: UserProfile?
    let isSubscribed: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar with glowing gradient borders
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: isSubscribed ? [Color.mlGold, Color.mlPink] : [Color.mlPurple, Color.mlPink],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                if let avatarUrl = user?.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 74, height: 74)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.mlCard)
                        .frame(width: 74, height: 74)
                    Text(String((profile?.displayName ?? user?.username ?? "G").prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.displayName ?? user?.username ?? "Guest User")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    
                    if isSubscribed {
                        Text("PREMIUM")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color.mlGold, Color(red: 1.0, green: 0.6, blue: 0.2)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                    } else {
                        Text("LEVEL \(user?.level ?? 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.mlPurple)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.mlPurple.opacity(0.15)))
                            .overlay(Capsule().strokeBorder(Color.mlPurple.opacity(0.3), lineWidth: 1))
                    }
                }
                
                Text(user?.email ?? "Guest account")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mlSubtext)
                    .lineLimit(1)
                
                if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext.opacity(0.8))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mlCard))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct WalletStatusCard: View {
    let wallet: Wallet?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MY WALLET")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.mlSubtext)
                    Text("Coins & Balance")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                Spacer()
                
                Button(action: {
                    // Navigate to shop / buy coins
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Top Up")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.mlPurple))
                }
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            HStack(spacing: 0) {
                // Coins
                WalletItemView(
                    icon: "bitcoinsign.circle.fill",
                    amount: "\(wallet?.coins ?? 0)",
                    label: "Coins",
                    color: Color.mlGold
                )
                
                Spacer()
                
                // Gems
                WalletItemView(
                    icon: "diamond.fill",
                    amount: "\(wallet?.gems ?? 0)",
                    label: "Gems",
                    color: Color.mlPink
                )
                
                Spacer()
                
                // Free pass
                WalletItemView(
                    icon: "ticket.fill",
                    amount: "\(wallet?.freePass ?? 0)",
                    label: "Free Pass",
                    color: Color(red: 0.2, green: 0.8, blue: 0.9)
                )
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.mlCard)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct WalletItemView: View {
    let icon: String
    let amount: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Text(amount)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.mlSubtext)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatsGridView: View {
    let readingHours: Double
    let activeStreak: Int
    let episodesUnlocked: Int
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCell(
                number: String(format: "%.1fh", readingHours),
                label: "Reading time",
                icon: "clock.fill",
                color: Color.mlPurple
            )
            StatCell(
                number: "\(activeStreak)d",
                label: "Streak",
                icon: "flame.fill",
                color: Color.mlPink
            )
            StatCell(
                number: "\(episodesUnlocked)",
                label: "Unlocked eps",
                icon: "lock.open.fill",
                color: Color.mlGold
            )
        }
    }
}

struct StatCell: View {
    let number: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(spacing: 2) {
                Text(number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mlSubtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.mlCard))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }
}

struct ProfileMenuList: View {
    let isSubscribed: Bool
    
    var body: some View {
        VStack(spacing: 1) {
            
            // Link to Coin shop
            ProfileMenuRow(
                icon: "cart.fill",
                color: Color.mlGold,
                title: "Buy Coins & Passes"
            )
            
            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
            
            // Check-in check
            ProfileMenuRow(
                icon: "calendar.badge.clock",
                color: Color.mlPink,
                title: "Daily Rewards & Check-in"
            )
            
            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
            
            // Settings Link
            NavigationLink(destination: SettingsView()) {
                ProfileMenuRow(
                    icon: "gearshape.fill",
                    color: Color.mlPurple,
                    title: "Settings & Options"
                )
            }
            .buttonStyle(.plain)
            
            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
            
            // Help & feedback
            ProfileMenuRow(
                icon: "questionmark.bubble.fill",
                color: Color(red: 0.2, green: 0.8, blue: 0.5),
                title: "Help & Feedback"
            )
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.mlCard))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct ProfileMenuRow: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mlSubtext.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
}
