import SwiftUI
import Observation

// MARK: - StoryDetailView ViewModel
@MainActor
@Observable
class StoryDetailViewModel {
    var episodes: [EpisodeMeta] = []
    var isLoading = false
    var errorMessage: String? = nil
    var isSaved = false
    var isUpdatingSave = false

    func loadEpisodes(slug: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            episodes = try await NetworkService.shared.fetchStoryEpisodes(slug: slug)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadSavedState(storyID: String) async {
        do {
            let savedItems = try await NetworkService.shared.fetchLibrary(type: "saved")
            isSaved = savedItems.contains(where: { $0.storyID == storyID })
        } catch {
            isSaved = false
        }
    }

    func toggleSaved(storyID: String) async {
        guard !isUpdatingSave else { return }
        isUpdatingSave = true
        defer { isUpdatingSave = false }
        do {
            if isSaved {
                try await NetworkService.shared.removeFromLibrary(storyID: storyID, type: "saved")
                isSaved = false
            } else {
                try await NetworkService.shared.addToLibrary(storyID: storyID, type: "saved")
                isSaved = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - StoryDetailView
struct StoryDetailView: View {
    let story: Story

    @State private var viewModel = StoryDetailViewModel()
    @State private var selectedEpisode: EpisodeMeta? = nil
    @State private var unlockTarget: EpisodeMeta? = nil
    @Environment(\.dismiss) private var dismiss

    private var colors: (Color, Color) { getGradientForString(story.title) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.mlBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Cover
                        heroSection
                            .frame(width: proxy.size.width)

                        // Story Info
                        storyInfoSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Episodes List
                        episodesSection
                            .padding(.top, 8)

                        Color.clear.frame(height: 90)
                    }
                    .frame(width: proxy.size.width)
                }
                .frame(width: proxy.size.width)

                // Overlay top bar
                overlayTopBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $unlockTarget) { ep in
            UnlockEpisodeSheet(episode: ep, storyTitle: story.title) {
                Task {
                    await viewModel.loadEpisodes(slug: story.slug)
                    selectedEpisode = ep
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            AnalyticsService.shared.track(.storyView, [
                "story_id": story.id,
                "story_slug": story.slug,
                "story_title": story.title
            ])
            // Load episodes and saved state in parallel
            async let episodes: () = viewModel.loadEpisodes(slug: story.slug)
            async let saved: () = viewModel.loadSavedState(storyID: story.id)
            _ = await (episodes, saved)
        }
        .fullScreenCover(item: $selectedEpisode) { ep in
            EpisodeReaderView(episodeId: ep.id, story: story, episodes: viewModel.episodes)
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image or gradient placeholder
            if let coverUrl = story.coverUrl, let url = URL(string: coverUrl) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        heroGradient
                    }
                }
                .frame(height: 340)
                .clipped()
            } else {
                heroGradient.frame(height: 340)
            }

            // Gradient overlay bottom
            LinearGradient(
                colors: [.clear, Color.mlBg.opacity(0.6), Color.mlBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 340)
        }
        .frame(height: 340)
    }

    private var heroGradient: some View {
        LinearGradient(
            colors: [colors.0, colors.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Story Info Section
    private var storyInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Genre tags
            if let genres = story.genres, !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.mlPurple)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(Color.mlPurple.opacity(0.15)))
                                .overlay(Capsule().strokeBorder(Color.mlPurple.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }

            // Title
            Text(story.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(3)

            // Hook / tagline
            if let hook = story.hook {
                Text(hook)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mlSubtext)
                    .lineLimit(3)
            }

            // Stats row
            HStack(spacing: 16) {
                if story.totalEpisodes > 0 {
                    Label("\(story.totalEpisodes) Episodes", systemImage: "doc.text.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mlSubtext)
                }
                Label("\(story.freeEpisodeCount) Free", systemImage: "gift.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.55))
                if story.isHot {
                    Label("HOT", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.mlPink)
                }
            }

            // CTA Buttons
            HStack(spacing: 12) {
                // Start / Continue button
                let firstAccessible = viewModel.episodes.first(where: { $0.hasAccess })
                Button(action: {
                    if let ep = firstAccessible {
                        selectedEpisode = ep
                    } else if let ep = viewModel.episodes.first(where: { $0.isFree }) {
                        selectedEpisode = ep
                    } else if let ep = viewModel.episodes.first {
                        unlockTarget = ep
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(viewModel.episodes.isEmpty ? "Loading..." : "Start Reading")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(
                                colors: [Color.mlPurple, Color.mlPurpleDim],
                                startPoint: .leading, endPoint: .trailing))
                    )
                }
                .disabled(viewModel.episodes.isEmpty)

                // Library save button
                Button(action: {
                    Task { await viewModel.toggleSaved(storyID: story.id) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                        Text(viewModel.isSaved ? "Saved" : "Save")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.mlPurple)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.mlPurple.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mlPurple.opacity(0.25), lineWidth: 1))
                    )
                }
                .disabled(viewModel.isUpdatingSave)
                .opacity(viewModel.isUpdatingSave ? 0.65 : 1.0)
            }
        }
    }

    // MARK: - Episodes Section
    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Episodes")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                if !viewModel.episodes.isEmpty {
                    Text("\(viewModel.episodes.count) chapters")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        EpisodeRowSkeleton()
                    }
                }
                .padding(.horizontal, 20)
            } else if let err = viewModel.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.mlSubtext)
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mlSubtext)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.episodes.enumerated()), id: \.element.id) { index, ep in
                        EpisodeRow(
                            ep: ep,
                            index: index,
                            onTap: {
                                if ep.hasAccess {
                                    selectedEpisode = ep
                                } else {
                                    unlockTarget = ep
                                }
                            }
                        )
                        if index < viewModel.episodes.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .background(Color.mlCard.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        .padding(.horizontal, 20)
                )
            }
        }
    }

    // MARK: - Overlay Top Bar
    private var overlayTopBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 38, height: 38)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
            }
            Spacer()
            if story.isHot {
                Label("TRENDING", systemImage: "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.mlPink.opacity(0.85)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Episode Row
struct EpisodeRow: View {
    let ep: EpisodeMeta
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Ep number circle
                ZStack {
                    Circle()
                        .fill(ep.hasAccess ? Color.mlPurple.opacity(0.18) : Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                    if ep.hasAccess {
                        Text("\(ep.episodeNumber)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mlPurple)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.mlSubtext)
                    }
                }

                // Title & meta
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ep \(ep.episodeNumber) · \(ep.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ep.hasAccess ? Color.white : Color.mlSubtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if ep.wordCount > 0 {
                            Text("\(ep.wordCount.formatted()) words")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mlMuted)
                        }
                        if ep.estimatedReadingTime > 0 {
                            Text("· \(ep.estimatedReadingTime) min read")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mlMuted)
                        }
                    }
                }

                Spacer()

                // Access badge
                if ep.isFree {
                    Text("FREE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.55))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color(red: 0.25, green: 0.85, blue: 0.55).opacity(0.15)))
                } else if ep.hasAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.mlPurple)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mlGold)
                        Text("\(ep.coinPrice)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mlGold)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.mlGold.opacity(0.12)))
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Episode Row Skeleton (loading state)
struct EpisodeRowSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .opacity(shimmer ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}

// MARK: - Unlock Episode Sheet
struct UnlockEpisodeSheet: View {
    let episode: EpisodeMeta
    let storyTitle: String
    var onUnlocked: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShopSheet = false
    @State private var showingMoonPassSheet = false
    @State private var isUnlocking = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.mlPurple.opacity(0.3), Color.mlPink.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 64, height: 64)
                        if isUnlocking {
                            ProgressView().tint(Color.mlPurple)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.mlPurple)
                        }
                    }
                    .padding(.top, 28)

                    Text("Unlock This Episode")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Ep \(episode.episodeNumber) · \(episode.title)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mlSubtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.mlPink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 24)

                Divider().background(Color.white.opacity(0.08))

                // Unlock options
                VStack(spacing: 0) {
                    UnlockOptionRow(
                        icon: "bitcoinsign.circle.fill",
                        iconColor: Color.mlGold,
                        title: "Use \(episode.coinPrice) Coins",
                        subtitle: "Instant access, yours forever",
                        badge: nil,
                        action: {
                            Task {
                                isUnlocking = true
                                errorMessage = nil
                                do {
                                    let res = try await NetworkService.shared.unlockEpisodeWithCoins(episodeId: episode.id)
                                    if res.status == "unlocked" || res.status == "already_unlocked" {
                                        AnalyticsService.shared.track(.episodeUnlock, [
                                            "episode_id": episode.id,
                                            "method": "coins",
                                            "coin_price": episode.coinPrice
                                        ])
                                        NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
                                        onUnlocked()
                                        dismiss()
                                    }
                                } catch {
                                    let errMsg = error.localizedDescription
                                    if errMsg.localizedCaseInsensitiveContains("insufficient") {
                                        showingShopSheet = true
                                    } else {
                                        errorMessage = errMsg
                                    }
                                }
                                isUnlocking = false
                            }
                        }
                    )
                    Divider().background(Color.white.opacity(0.06)).padding(.leading, 56)

                    UnlockOptionRow(
                        icon: "moon.stars.fill",
                        iconColor: Color.mlPurple,
                        title: "MoonPass Subscription",
                        subtitle: "Unlimited access · All stories",
                        badge: "BEST VALUE",
                        action: {
                            showingMoonPassSheet = true
                        }
                    )
                }
                .padding(.bottom, 8)
                .disabled(isUnlocking)

                Button(action: { dismiss() }) {
                    Text("Maybe Later")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mlSubtext)
                }
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingShopSheet) {
            NavigationStack {
                CoinShopView()
            }
        }
        .sheet(isPresented: $showingMoonPassSheet) {
            MoonPassSubscriptionView(
                episodeTitle: "Ep \(episode.episodeNumber) · \(episode.title)",
                onActivated: {
                    onUnlocked()
                    dismiss()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct MoonPassSubscriptionView: View {
    let episodeTitle: String
    let onActivated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var purchaseManager = SubscriptionPurchaseManager()

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.mlPurple.opacity(0.35), Color.mlPink.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.mlPurple)
                    }

                    Text("MoonPass Subscription")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text(episodeTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mlSubtext)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 12) {
                    MoonPassBenefitRow(icon: "book.closed.fill", text: "Unlimited access to all story episodes")
                    MoonPassBenefitRow(icon: "headphones", text: "Premium audio options when available")
                    MoonPassBenefitRow(icon: "sparkles", text: "Ready for future subscriber-only features")
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                .padding(.horizontal, 20)

                if purchaseManager.isLoading {
                    ProgressView().tint(Color.mlPurple)
                } else {
                    VStack(spacing: 10) {
                        Button {
                            Task {
                                if await purchaseManager.purchaseMoonPass() {
                                    onActivated()
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if purchaseManager.isPurchasing {
                                    ProgressView().tint(Color.white)
                                }
                                Text(primaryButtonTitle)
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [Color.mlPurple, Color.mlPurpleDim], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                        }
                        .disabled(purchaseManager.isPurchasing || purchaseManager.offer?.isPurchasable != true)

                        Button {
                            Task {
                                if await purchaseManager.restoreMoonPass() {
                                    onActivated()
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Restore Purchase")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.mlSubtext)
                        }
                        .disabled(purchaseManager.isPurchasing)
                    }
                    .padding(.horizontal, 20)
                }

                if let error = purchaseManager.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlPink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Auto-renewable subscription disclosure (App Store requirement)
                VStack(spacing: 8) {
                    Text(renewalDisclosure)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.mlSubtext.opacity(0.8))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Link("Terms of Use", destination: LegalLinks.termsOfUse)
                        Text("·").foregroundStyle(Color.mlSubtext.opacity(0.5))
                        Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .tint(Color.mlPurple)
                }
                .padding(.horizontal, 24)

                Button("Maybe Later") {
                    dismiss()
                }
                .font(.system(size: 14))
                .foregroundStyle(Color.mlSubtext)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await purchaseManager.loadMoonPassOffer()
        }
    }

    private var primaryButtonTitle: String {
        guard let offer = purchaseManager.offer else {
            return "MoonPass Unavailable"
        }
        if let period = offer.periodText {
            return "Start MoonPass · \(offer.displayPrice)/\(period)"
        }
        return "Start MoonPass · \(offer.displayPrice)"
    }

    private var renewalDisclosure: String {
        guard let offer = purchaseManager.offer, let period = offer.periodText else {
            return "Payment is charged to your Apple ID. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store settings."
        }
        return "\(offer.displayName) is \(offer.displayPrice) per \(period). Payment is charged to your Apple ID at confirmation. It automatically renews unless cancelled at least 24 hours before the period ends. Manage or cancel anytime in App Store settings."
    }
}

// Legal links shown on subscription/purchase screens and in Settings.
// Required for App Store auto-renewable subscription review.
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://moonlit.zenix.vn/privacy")!
    static let termsOfUse = URL(string: "https://moonlit.zenix.vn/terms")!
}

private struct MoonPassBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mlPurple)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.86))
            Spacer()
        }
    }
}

private struct UnlockOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color.mlPurple)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(Color.mlPurple.opacity(0.18)))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mlSubtext)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        StoryDetailView(story: Story(
            id: "preview-1",
            title: "The Billionaire Fake Wife",
            slug: "the-billionaire-fake-wife",
            description: "A year-long contract. A cold billionaire. An unexpected truth.",
            hook: "She signed the contract. She didn't sign up for feelings.",
            coverUrl: nil,
            freeEpisodeCount: 3,
            defaultCoinPrice: 20,
            totalEpisodes: 5,
            isFeatured: false,
            isHot: true,
            isEditorPick: true,
            genres: ["Romance", "Billionaire"],
            moods: ["Addictive"]
        ))
    }
    .preferredColorScheme(.dark)
}
