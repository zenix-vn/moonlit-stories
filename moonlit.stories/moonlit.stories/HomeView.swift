import SwiftUI
import UIKit

// MARK: - Theme Extension
extension Color {
    static let mlBg        = Color(red: 0.043, green: 0.024, blue: 0.090)
    static let mlCard      = Color(red: 0.098, green: 0.059, blue: 0.157)
    static let mlPurple    = Color(red: 0.608, green: 0.349, blue: 1.000)
    static let mlPurpleDim = Color(red: 0.486, green: 0.239, blue: 0.863)
    static let mlPink      = Color(red: 1.000, green: 0.420, blue: 0.616)
    static let mlGold      = Color(red: 1.000, green: 0.780, blue: 0.180)
    static let mlSubtext   = Color(red: 0.655, green: 0.545, blue: 0.800)
    static let mlMuted     = Color(white: 0.45)
}

// Helper to generate consistent gradient colors based on string hash for missing covers
func getGradientForString(_ str: String) -> (Color, Color) {
    let hash = abs(str.hashValue)
    let colors: [(Color, Color)] = [
        (Color(red: 0.08, green: 0.02, blue: 0.20), Color(red: 0.38, green: 0.12, blue: 0.60)),
        (Color(red: 0.10, green: 0.02, blue: 0.08), Color(red: 0.52, green: 0.10, blue: 0.25)),
        (Color(red: 0.05, green: 0.04, blue: 0.18), Color(red: 0.15, green: 0.20, blue: 0.60)),
        (Color(red: 0.08, green: 0.04, blue: 0.16), Color(red: 0.36, green: 0.10, blue: 0.50)),
        (Color(red: 0.10, green: 0.02, blue: 0.06), Color(red: 0.50, green: 0.08, blue: 0.20))
    ]
    return colors[hash % colors.count]
}

// MARK: - Root View
struct HomeView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            MainHomeTab(selectedTab: $tab)
                .tabItem { Label("Home",    systemImage: "house.fill") }
                .tag(0)
            SearchTabView()
                .tabItem { Label("Search",  systemImage: "magnifyingglass") }
                .tag(1)
            LibraryTabView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Color.mlPurple)
        .preferredColorScheme(.dark)
        .task {
            // Pre-warm keyboard service so first tap on Search is instant.
            // becomeFirstResponder + immediate resignFirstResponder boots the keyboard
            // process without showing any animation.
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { prewarmKeyboard() }
        }
    }

    private func prewarmKeyboard() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return }
        let tf = UITextField(frame: .zero)
        tf.isHidden = true
        window.addSubview(tf)
        tf.becomeFirstResponder()
        tf.resignFirstResponder()
        tf.removeFromSuperview()
    }
}

// MARK: - Main Home Tab
struct MainHomeTab: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedGenreFilter: String? = nil

    private func filteredStories(_ stories: [Story]) -> [Story] {
        guard let selected = selectedGenreFilter?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty else {
            return stories
        }

        let selectedLower = selected.lowercased()
        return stories.filter { story in
            guard let storyGenres = story.genres, !storyGenres.isEmpty else {
                return false
            }
            return storyGenres.contains { $0.lowercased() == selectedLower }
        }
    }

    var body: some View {
        NavigationStack {
        ZStack(alignment: .top) {
            Color.mlBg.ignoresSafeArea()

            Circle()
                .fill(Color.mlPurple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -90, y: -120)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            Circle()
                .fill(Color.mlPink.opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: 140, y: -60)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 90)
                    
                    if viewModel.isLoading && viewModel.tonightsPicks.isEmpty {
                        VStack {
                            ProgressView()
                                .tint(Color.mlPurple)
                                .scaleEffect(1.3)
                                .padding(.bottom, 8)
                            Text("Loading stories...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.mlSubtext)
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.mlPink)
                            Text("Oops! Failed to connect to server")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.mlSubtext)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button(action: {
                                Task { await viewModel.loadFeed() }
                            }) {
                                Text("Retry")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(Color.mlPurple))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    } else {
                        VStack(spacing: 26) {
                            HeroBanner(
                                banner: viewModel.topBanners.first ?? viewModel.banners.first,
                                heroCard: viewModel.heroCard
                            )
                            
                            GenrePills(
                                genres: viewModel.genres,
                                selectedGenre: selectedGenreFilter,
                                onSelectGenre: { value in
                                    selectedGenreFilter = value
                                }
                            )
                            
                            if !viewModel.continueReading.isEmpty {
                                ContinueReadingSection(items: viewModel.continueReading)
                            }
                            
                            FeaturedCarousel(
                                stories: filteredStories(viewModel.tonightsPicks),
                                storyLibraryStatuses: viewModel.storyLibraryStatuses
                            )

                            PopularSection(stories: filteredStories(viewModel.trendingNow))

                            GenreGrid(
                                genres: viewModel.genres,
                                selectedGenre: selectedGenreFilter,
                                onSelectGenre: { tappedGenre in
                                    if selectedGenreFilter == tappedGenre {
                                        selectedGenreFilter = nil
                                    } else {
                                        selectedGenreFilter = tappedGenre
                                    }
                                },
                                onClearFilter: {
                                    selectedGenreFilter = nil
                                }
                            )
                            .padding(.horizontal, 20)

                            if !viewModel.midBanners.isEmpty {
                                GeometryReader { geo in
                                    let cardWidth = max(geo.size.width - 40, 280)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(viewModel.midBanners) { midBanner in
                                                MidPromotionBanner(banner: midBanner)
                                                    .frame(width: cardWidth)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .frame(height: 140)
                            }

                            let releases = viewModel.freeEpisodesToday.isEmpty ? viewModel.tonightsPicks : viewModel.freeEpisodesToday
                            NewReleasesSection(stories: filteredStories(releases))
                            
                            Color.clear.frame(height: 90)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadFeed()
            }
            .task {
                await viewModel.loadFeed()
            }

            TopNav(wallet: viewModel.wallet, onProfileTap: {
                selectedTab = 3
            })
        }
        .navigationBarHidden(true)
        } // NavigationStack
    }
}

struct MidPromotionBanner: View {
    let banner: Banner

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: banner.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.08, green: 0.02, blue: 0.22), Color(red: 0.30, green: 0.08, blue: 0.52)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }
            .frame(height: 140)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                if let subtitle = banner.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                }
            }
            .padding(14)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Top Navigation Bar
struct TopNav: View {
    let wallet: Wallet?
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.mlPurple, Color.mlPurpleDim],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Moonlit Stories")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("Romance · Werewolf · Fantasy")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.mlSubtext)
                }

                Spacer()

                // Coin balance display
                if let coins = wallet?.coins {
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.mlGold)
                        Text("\(coins)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }

                Button(action: {}) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 36, height: 36)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white)
                    }
                }

                Button(action: onProfileTap) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.9, green: 0.5, blue: 0.7), Color.mlPurple],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Text("G")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Hero Banner
struct HeroBanner: View {
    let banner: Banner?
    let heroCard: HomeHeroCard?
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let banner = banner {
                AsyncImage(url: URL(string: banner.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.02, blue: 0.22),
                                Color(red: 0.30, green: 0.08, blue: 0.52),
                                Color(red: 0.55, green: 0.18, blue: 0.65),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 190)
                .clipped()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(banner.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                    
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(1)
                    }

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Start Reading")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.mlPurple, Color.mlPurpleDim],
                                    startPoint: .leading, endPoint: .trailing))
                        )
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.02, blue: 0.22),
                            Color(red: 0.30, green: 0.08, blue: 0.52),
                            Color(red: 0.55, green: 0.18, blue: 0.65),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing))

                GeometryReader { g in
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 110))
                        .foregroundStyle(Color.white.opacity(0.07))
                        .position(x: g.size.width * 0.80, y: g.size.height * 0.42)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(heroCard?.metric ?? "1000+")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(heroCard?.title ?? "Werewolf Novels")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.90))
                    Text(heroCard?.subtitle ?? "Romance stories · Love episodes")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.60))

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(heroCard?.ctaText ?? "Start Reading")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.mlPurple, Color.mlPurpleDim],
                                    startPoint: .leading, endPoint: .trailing))
                        )
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - Genre Pills
struct GenrePills: View {
    let genres: [Genre]
    let selectedGenre: String?
    let onSelectGenre: (String?) -> Void

    private var genreItems: [(name: String, icon: String, color: Color)] {
        var items: [(name: String, icon: String, color: Color)] = [
            ("All", "square.grid.2x2.fill", Color.mlPurple)
        ]

        for genre in genres {
            let style = styleForGenre(slug: genre.slug)
            items.append((genre.name, style.icon, style.color))
        }

        return items
    }

    private func styleForGenre(slug: String) -> (icon: String, color: Color) {
        let key = slug.lowercased()
        if key.contains("luna") || key.contains("moon") {
            return ("moon.stars.fill", Color(red: 0.70, green: 0.40, blue: 1.00))
        }
        if key.contains("alpha") {
            return ("pawprint.fill", Color(red: 0.90, green: 0.30, blue: 0.40))
        }
        if key.contains("mate") || key.contains("romance") {
            return ("heart.fill", Color.mlPink)
        }
        if key.contains("reject") {
            return ("heart.slash.fill", Color(red: 0.75, green: 0.20, blue: 0.45))
        }
        return ("sparkles", Color(red: 0.40, green: 0.65, blue: 1.00))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(genreItems, id: \.name) { g in
                    let isSelected = g.name == "All"
                        ? selectedGenre == nil
                        : selectedGenre?.lowercased() == g.name.lowercased()

                    Button(action: {
                        withAnimation(.spring(duration: 0.25)) {
                            if g.name == "All" {
                                onSelectGenre(nil)
                            } else {
                                onSelectGenre(g.name)
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: g.icon).font(.system(size: 12))
                            Text(g.name).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.white : g.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            Capsule()
                                .fill(isSelected ? g.color : g.color.opacity(0.14))
                        }
                        .overlay {
                            if !isSelected {
                                Capsule().strokeBorder(g.color.opacity(0.30), lineWidth: 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Featured Carousel
struct FeaturedCarousel: View {
    let stories: [Story]
    let storyLibraryStatuses: [String: Set<String>]
    @State private var page = 0

    var body: some View {
        if stories.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                SectionHeader(title: "Featured", action: "See all")
                    .padding(.horizontal, 20)

                TabView(selection: $page) {
                    ForEach(Array(stories.enumerated()), id: \.element.id) { i, story in
                        FeaturedCard(
                            story: story,
                            statuses: storyLibraryStatuses[story.id] ?? []
                        )
                        .tag(i)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 238)

                HStack(spacing: 6) {
                    ForEach(0..<stories.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.mlPurple : Color.white.opacity(0.25))
                            .frame(width: i == page ? 20 : 6, height: 6)
                            .animation(.spring(duration: 0.3), value: page)
                    }
                }
            }
        }
    }
}

struct FeaturedCard: View {
    let story: Story
    let statuses: Set<String>

    var body: some View {
        let colors = getGradientForString(story.title)
        let ratingVal = 4.5 + Double(abs(story.title.hashValue) % 5) / 10.0
        let durationStr = "\(1 + abs(story.title.hashValue) % 3)h"
        
        NavigationLink(destination: StoryDetailView(story: story)) {
        ZStack(alignment: .bottomLeading) {
            if let coverUrl = story.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [colors.0, colors.1],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [colors.0, colors.1],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            GeometryReader { g in
                Image(systemName: "sparkles")
                    .font(.system(size: 100))
                    .foregroundStyle(Color.white.opacity(0.04))
                    .position(x: g.size.width * 0.78, y: g.size.height * 0.40)
            }
            
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                LibraryStatusBadges(statuses: statuses)

                let genreText = story.genres?.first ?? "Romance"
                Text(genreText.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.mlPurple)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.mlPurple.opacity(0.18)))

                Text(story.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text("Moonlit Author")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.65))
                    if story.totalEpisodes > 0 {
                        Text("· \(story.totalEpisodes) eps")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.50))
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.mlGold)
                        Text(String(format: "%.1f", ratingVal))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(durationStr)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        ActionBtn(label: "Read", icon: "book.fill", filled: false)
                    }
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
        .frame(height: 228)
        } // NavigationLink
        .buttonStyle(.plain)
    }
}

private struct LibraryStatusBadges: View {
    let statuses: Set<String>

    private var orderedStatuses: [String] {
        ["saved", "history", "completed"].filter { statuses.contains($0) }
    }

    private func style(for status: String) -> (label: String, color: Color) {
        switch status {
        case "saved":
            return ("Saved", Color.mlPurple)
        case "history":
            return ("History", Color.mlSubtext)
        case "completed":
            return ("Completed", Color(red: 0.25, green: 0.85, blue: 0.55))
        default:
            return (status.capitalized, Color.mlSubtext)
        }
    }

    var body: some View {
        if orderedStatuses.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(orderedStatuses, id: \.self) { status in
                    let item = style(for: status)
                    Text(item.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(item.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(item.color.opacity(0.16)))
                        .overlay(Capsule().strokeBorder(item.color.opacity(0.28), lineWidth: 1))
                }
            }
        }
    }
}

private struct ActionBtn: View {
    let label:  String
    let icon:   String
    let filled: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(filled ? Color.white : Color.mlPurple)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(
            Capsule().fill(filled ? Color.mlPurple : Color.mlPurple.opacity(0.18))
        )
    }
}

// MARK: - Continue Reading Section
struct ContinueReadingSection: View {
    let items: [ContinueReadingItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Continue Reading", action: "See all")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink {
                            ContinueReadingDestinationView(item: item)
                        } label: {
                            ContinueCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ContinueCard: View {
    let item: ContinueReadingItem
    
    var body: some View {
        let colors = getGradientForString(item.storyTitle)
        HStack(spacing: 12) {
            ZStack {
                if let coverUrl = item.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .frame(width: 50, height: 68)
                    .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 68)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.storyTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                
                Text("Ep \(item.episodeNumber) · \(item.episodeTitle)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mlSubtext)
                    .lineLimit(1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [Color.mlPurple, Color.mlPink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(item.progressPercent / 100.0))
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
            .frame(width: 140)
        }
        .padding(10)
        .background(Color.mlCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct ContinueReadingDestinationView: View {
    let item: ContinueReadingItem
    @State private var story: Story? = nil
    @State private var episodes: [EpisodeMeta] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView().tint(Color.mlPurple)
                    Text("Loading chapter...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.mlSubtext)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.mlBg.ignoresSafeArea())
            } else if let story {
                EpisodeReaderView(
                    episodeId: item.episodeId,
                    story: story,
                    episodes: episodes
                )
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.mlPink)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mlSubtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button("Retry") {
                        Task { await loadDestinationData() }
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.mlPurple))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.mlBg.ignoresSafeArea())
            } else {
                EmptyView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadDestinationData()
        }
    }

    private func loadDestinationData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let storyTask = NetworkService.shared.fetchStoryBySlug(slug: item.storySlug)
            async let episodesTask = NetworkService.shared.fetchStoryEpisodes(slug: item.storySlug)
            let storyDetail = try await storyTask
            let storyEpisodes = try await episodesTask
            story = Story(
                id: storyDetail.id,
                title: storyDetail.title,
                slug: storyDetail.slug,
                description: storyDetail.description,
                hook: storyDetail.hook,
                coverUrl: storyDetail.coverUrl,
                freeEpisodeCount: storyDetail.freeEpisodeCount,
                defaultCoinPrice: 0,
                totalEpisodes: storyDetail.totalEpisodes,
                isFeatured: storyDetail.isFeatured,
                isHot: storyDetail.isHot,
                isEditorPick: false,
                genres: storyDetail.genres,
                moods: storyDetail.moods
            )
            episodes = storyEpisodes
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Popular Section
struct PopularSection: View {
    let stories: [Story]
    
    var body: some View {
        if stories.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Popular Stories", action: "See all")
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(stories) { story in AudioCard(story: story) }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct AudioCard: View {
    let story: Story

    var body: some View {
        let colors = getGradientForString(story.title)
        let ratingVal = 4.5 + Double(abs(story.title.hashValue) % 5) / 10.0
        let durationStr = "\(1 + abs(story.title.hashValue) % 3)h"
        
        NavigationLink(destination: StoryDetailView(story: story)) {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                if let coverUrl = story.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [colors.0, colors.1],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 148, height: 176)
                    .cornerRadius(16)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [colors.0, colors.1],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 148, height: 176)
                }

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 148, height: 176)
                .cornerRadius(16)

                VStack {
                    Spacer()
                    HStack {
                        Label(durationStr, systemImage: "book.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.45)))
                        Spacer()
                        Image(systemName: "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.30)))
                    }
                    .padding(10)
                }
                .frame(width: 148, height: 176)
            }
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(story.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .frame(width: 148, alignment: .leading)
                Text("Moonlit Author")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mlSubtext)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.mlGold)
                    Text(String(format: "%.1f", ratingVal))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white)
                    Text("·").foregroundStyle(Color.mlMuted)
                    Text(story.genres?.first ?? "Romance")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.mlSubtext)
                }
            }
            .frame(width: 148)
        }
        } // NavigationLink
        .buttonStyle(.plain)
    }
}

// MARK: - Werewolf Genre Grid
struct GenreGrid: View {
    let genres: [Genre]
    let selectedGenre: String?
    let onSelectGenre: (String) -> Void
    let onClearFilter: () -> Void

    private var cards: [(String, String, Color, Color)] {
        let fallback: [(String, String, Color, Color)] = [
            ("Luna", "moon.stars.fill", Color(red: 0.08, green: 0.02, blue: 0.20), Color(red: 0.40, green: 0.12, blue: 0.60)),
            ("Alpha", "crown.fill", Color(red: 0.12, green: 0.02, blue: 0.06), Color(red: 0.55, green: 0.10, blue: 0.25)),
            ("Mate", "heart.fill", Color(red: 0.10, green: 0.02, blue: 0.12), Color(red: 0.58, green: 0.12, blue: 0.42)),
            ("Rejected", "heart.slash.fill", Color(red: 0.05, green: 0.05, blue: 0.16), Color(red: 0.16, green: 0.22, blue: 0.58))
        ]

        guard !genres.isEmpty else { return fallback }

        return genres.prefix(4).map { genre in
            let style = styleForGenre(slug: genre.slug, name: genre.name)
            return (genre.name, style.icon, style.top, style.bottom)
        }
    }

    private func styleForGenre(slug: String, name: String) -> (icon: String, top: Color, bottom: Color) {
        let key = slug.lowercased()
        if key.contains("luna") || key.contains("moon") {
            return ("moon.stars.fill", Color(red: 0.08, green: 0.02, blue: 0.20), Color(red: 0.40, green: 0.12, blue: 0.60))
        }
        if key.contains("alpha") {
            return ("crown.fill", Color(red: 0.12, green: 0.02, blue: 0.06), Color(red: 0.55, green: 0.10, blue: 0.25))
        }
        if key.contains("mate") || key.contains("romance") {
            return ("heart.fill", Color(red: 0.10, green: 0.02, blue: 0.12), Color(red: 0.58, green: 0.12, blue: 0.42))
        }
        if key.contains("reject") {
            return ("heart.slash.fill", Color(red: 0.05, green: 0.05, blue: 0.16), Color(red: 0.16, green: 0.22, blue: 0.58))
        }

        let palette: [(String, Color, Color)] = [
            ("sparkles", Color(red: 0.08, green: 0.03, blue: 0.24), Color(red: 0.34, green: 0.10, blue: 0.62)),
            ("shield.lefthalf.filled", Color(red: 0.07, green: 0.04, blue: 0.18), Color(red: 0.20, green: 0.26, blue: 0.60)),
            ("flame.fill", Color(red: 0.14, green: 0.02, blue: 0.07), Color(red: 0.58, green: 0.12, blue: 0.24)),
            ("book.fill", Color(red: 0.07, green: 0.03, blue: 0.16), Color(red: 0.34, green: 0.14, blue: 0.52))
        ]
        let index = abs(name.hashValue) % palette.count
        let picked = palette[index]
        return (picked.0, picked.1, picked.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Werewolf Genres")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                Button(action: {
                    if selectedGenre != nil {
                        onClearFilter()
                    }
                }) {
                    Text(selectedGenre == nil ? "See all" : "Clear")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.mlPurple)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(cards, id: \.0) { c in
                    GenreGridCell(
                        name: c.0,
                        icon: c.1,
                        top: c.2,
                        bot: c.3,
                        isSelected: selectedGenre?.lowercased() == c.0.lowercased(),
                        onTap: {
                            onSelectGenre(c.0)
                        }
                    )
                }
            }
        }
    }
}

struct GenreGridCell: View {
    let name: String
    let icon: String
    let top:  Color
    let bot:  Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [top, bot], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 100)

                Image(systemName: icon)
                    .font(.system(size: 58))
                    .foregroundStyle(Color.white.opacity(0.11))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 8).padding(.top, 8)

                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.leading, 14).padding(.bottom, 14)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.mlPurple : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: - New Releases
struct NewReleasesSection: View {
    let stories: [Story]

    var body: some View {
        if stories.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "New Releases", action: "See all")
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(stories) { story in SmallCard(story: story) }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct SmallCard: View {
    let story: Story

    var body: some View {
        let colors = getGradientForString(story.title)
        let ratingVal = 4.5 + Double(abs(story.title.hashValue) % 5) / 10.0
        
        NavigationLink(destination: StoryDetailView(story: story)) {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                if let coverUrl = story.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(
                                    colors: [colors.0, colors.1],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 108, height: 143)
                    .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [colors.0, colors.1],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 108, height: 143)
                }

                if story.isHot || story.isFeatured {
                    VStack {
                        HStack {
                            Text(story.isHot ? "HOT" : "NEW")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.mlPink))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    .frame(width: 108, height: 143)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .frame(width: 108, alignment: .leading)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.mlGold)
                    Text(String(format: "%.1f", ratingVal))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 108)
        }
        } // NavigationLink
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title:  String
    let action: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white)
            Spacer()
            Button(action: {}) {
                Text(action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mlPurple)
            }
        }
    }
}

// MARK: - Placeholder Tabs
struct PlaceholderTab: View {
    let icon:  String
    let label: String

    var body: some View {
        ZStack {
            Color.mlBg.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.mlPurple, Color.mlPink],
                            startPoint: .top, endPoint: .bottom))
                Text(label)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
