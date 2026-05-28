import SwiftUI

// MARK: - Theme
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

// MARK: - Models
struct StoryBook: Identifiable {
    let id        = UUID()
    let title:    String
    let author:   String
    let genre:    String
    let rating:   Double
    let duration: String
    let topColor: Color
    let botColor: Color
    let symbol:   String
    var isAudio:  Bool = false
    var isNew:    Bool = false
    var episodes: Int  = 0
}

struct StoryGenre: Identifiable {
    let id   = UUID()
    let name:  String
    let icon:  String
    let color: Color
}

// MARK: - Data
enum ML {
    static let genres: [StoryGenre] = [
        StoryGenre(name: "All",      icon: "square.grid.2x2.fill", color: Color.mlPurple),
        StoryGenre(name: "Luna",     icon: "moon.stars.fill",       color: Color(red: 0.70, green: 0.40, blue: 1.00)),
        StoryGenre(name: "Alpha",    icon: "pawprint.fill",         color: Color(red: 0.90, green: 0.30, blue: 0.40)),
        StoryGenre(name: "Mate",     icon: "heart.fill",            color: Color.mlPink),
        StoryGenre(name: "Rejected", icon: "heart.slash.fill",      color: Color(red: 0.75, green: 0.20, blue: 0.45)),
        StoryGenre(name: "Omega",    icon: "sparkles",              color: Color(red: 0.40, green: 0.65, blue: 1.00)),
    ]

    static let featured: [StoryBook] = [
        StoryBook(title: "True Luna: Chasing The White Wolf",
                  author: "Tessa Lily",    genre: "Luna",
                  rating: 4.9, duration: "30m",
                  topColor: Color(red: 0.08, green: 0.02, blue: 0.20),
                  botColor: Color(red: 0.38, green: 0.12, blue: 0.60),
                  symbol: "moon.stars.fill", isAudio: true, episodes: 376),
        StoryBook(title: "The Alpha King's Chosen Mate",
                  author: "Rose Midnight", genre: "Alpha",
                  rating: 4.8, duration: "45m",
                  topColor: Color(red: 0.10, green: 0.02, blue: 0.08),
                  botColor: Color(red: 0.52, green: 0.10, blue: 0.25),
                  symbol: "crown.fill", isAudio: true, episodes: 203),
        StoryBook(title: "Rejected by the Alpha, Loved by the Moon",
                  author: "Luna Storm",    genre: "Rejected",
                  rating: 4.7, duration: "1h",
                  topColor: Color(red: 0.05, green: 0.04, blue: 0.18),
                  botColor: Color(red: 0.15, green: 0.20, blue: 0.60),
                  symbol: "heart.slash.circle.fill", episodes: 156),
    ]

    static let popular: [StoryBook] = [
        StoryBook(title: "Alpha's Dark Desire",
                  author: "Aria Night",  genre: "Alpha",
                  rating: 4.9, duration: "2h 30m",
                  topColor: Color(red: 0.08, green: 0.02, blue: 0.18),
                  botColor: Color(red: 0.42, green: 0.12, blue: 0.62),
                  symbol: "crown.fill", isAudio: true),
        StoryBook(title: "The Beta's Forbidden Mate",
                  author: "Maya Wolf",   genre: "Mate",
                  rating: 4.7, duration: "1h 45m",
                  topColor: Color(red: 0.04, green: 0.05, blue: 0.18),
                  botColor: Color(red: 0.10, green: 0.22, blue: 0.62),
                  symbol: "heart.fill", isAudio: true),
        StoryBook(title: "Moon Goddess's Blessed",
                  author: "Sky Silver",  genre: "Luna",
                  rating: 4.8, duration: "3h",
                  topColor: Color(red: 0.10, green: 0.05, blue: 0.18),
                  botColor: Color(red: 0.46, green: 0.15, blue: 0.56),
                  symbol: "moon.circle.fill"),
        StoryBook(title: "Rejected Luna's Revenge",
                  author: "Eve Dark",    genre: "Rejected",
                  rating: 4.6, duration: "2h",
                  topColor: Color(red: 0.12, green: 0.03, blue: 0.08),
                  botColor: Color(red: 0.56, green: 0.12, blue: 0.28),
                  symbol: "flame.fill"),
    ]

    static let newReleases: [StoryBook] = [
        StoryBook(title: "Lycan's Chosen",
                  author: "Nina Moon",   genre: "Mate",
                  rating: 4.5, duration: "1h 20m",
                  topColor: Color(red: 0.08, green: 0.04, blue: 0.16),
                  botColor: Color(red: 0.36, green: 0.10, blue: 0.50),
                  symbol: "sparkles", isNew: true),
        StoryBook(title: "The Last Omega Wolf",
                  author: "Zara Fox",    genre: "Luna",
                  rating: 4.6, duration: "50m",
                  topColor: Color(red: 0.05, green: 0.02, blue: 0.14),
                  botColor: Color(red: 0.30, green: 0.08, blue: 0.48),
                  symbol: "star.fill", isNew: true),
        StoryBook(title: "Alpha's Forbidden Claim",
                  author: "Rex Stone",   genre: "Alpha",
                  rating: 4.8, duration: "2h",
                  topColor: Color(red: 0.10, green: 0.02, blue: 0.06),
                  botColor: Color(red: 0.50, green: 0.08, blue: 0.20),
                  symbol: "lock.fill", isNew: true),
        StoryBook(title: "Howling at Midnight",
                  author: "Vera Night",  genre: "Mate",
                  rating: 4.4, duration: "1h 10m",
                  topColor: Color(red: 0.06, green: 0.04, blue: 0.14),
                  botColor: Color(red: 0.28, green: 0.12, blue: 0.45),
                  symbol: "moon.fill", isNew: true),
    ]
}

// MARK: - Root View
struct HomeView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            MainHomeTab()
                .tabItem { Label("Home",    systemImage: "house.fill") }
                .tag(0)
            PlaceholderTab(icon: "magnifyingglass",    label: "Search")
                .tabItem { Label("Search",  systemImage: "magnifyingglass") }
                .tag(1)
            PlaceholderTab(icon: "books.vertical.fill", label: "Library")
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(2)
            PlaceholderTab(icon: "person.fill",         label: "Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Color.mlPurple)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Main Home Tab
struct MainHomeTab: View {
    @State private var genre = "All"

    var body: some View {
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
                    VStack(spacing: 26) {
                        HeroBanner()
                        GenrePills(selected: $genre)
                        FeaturedCarousel()
                        PopularSection()
                        GenreGrid().padding(.horizontal, 20)
                        NewReleasesSection()
                        Color.clear.frame(height: 90)
                    }
                }
            }

            TopNav()
        }
    }
}

// MARK: - Top Navigation Bar
struct TopNav: View {
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

                Button(action: {}) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 36, height: 36)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white)
                    }
                }

                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.9, green: 0.5, blue: 0.7), Color.mlPurple],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Text("R")
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
    var body: some View {
        ZStack(alignment: .bottomLeading) {
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

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.white.opacity(0.10))
                    .position(x: g.size.width * 0.65, y: g.size.height * 0.15)

                Image(systemName: "star.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white.opacity(0.12))
                    .position(x: g.size.width * 0.88, y: g.size.height * 0.72)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("1000+")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
                Text("Werewolf Novels")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.90))
                Text("Romance stories · Love episodes")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.60))

                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Reading")
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
        .frame(height: 190)
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - Genre Pills
struct GenrePills: View {
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ML.genres) { g in
                    Button(action: {
                        withAnimation(.spring(duration: 0.25)) { selected = g.name }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: g.icon).font(.system(size: 12))
                            Text(g.name).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(selected == g.name ? Color.white : g.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            Capsule()
                                .fill(selected == g.name ? g.color : g.color.opacity(0.14))
                        }
                        .overlay {
                            if selected != g.name {
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
    @State private var page = 0

    var body: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Featured", action: "See all")
                .padding(.horizontal, 20)

            TabView(selection: $page) {
                ForEach(Array(ML.featured.enumerated()), id: \.element.id) { i, book in
                    FeaturedCard(book: book).tag(i).padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 210)

            HStack(spacing: 6) {
                ForEach(0..<ML.featured.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.mlPurple : Color.white.opacity(0.25))
                        .frame(width: i == page ? 20 : 6, height: 6)
                        .animation(.spring(duration: 0.3), value: page)
                }
            }
        }
    }
}

struct FeaturedCard: View {
    let book: StoryBook

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [book.topColor, book.botColor],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            GeometryReader { g in
                Image(systemName: book.symbol)
                    .font(.system(size: 100))
                    .foregroundStyle(Color.white.opacity(0.08))
                    .position(x: g.size.width * 0.78, y: g.size.height * 0.40)
            }

            if book.isAudio {
                VStack {
                    HStack {
                        Spacer()
                        Label("AUDIO", systemImage: "headphones")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Color.mlPurple.opacity(0.85)))
                    }
                    Spacer()
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(book.genre.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.mlPurple)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.mlPurple.opacity(0.18)))

                Text(book.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(book.author)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.65))
                    if book.episodes > 0 {
                        Text("· \(book.episodes) eps")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.50))
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.mlGold)
                        Text(String(format: "%.1f", book.rating))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(book.duration)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        if book.isAudio {
                            ActionBtn(label: "Listen", icon: "headphones", filled: true)
                        }
                        ActionBtn(label: "Read", icon: "book.fill", filled: false)
                    }
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }
}

private struct ActionBtn: View {
    let label:  String
    let icon:   String
    let filled: Bool

    var body: some View {
        Button(action: {}) {
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
}

// MARK: - Popular Audiobooks
struct PopularSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Popular Audiobooks", action: "See all")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ML.popular) { book in AudioCard(book: book) }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct AudioCard: View {
    let book: StoryBook

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [book.topColor, book.botColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 148, height: 176)

                Image(systemName: book.symbol)
                    .font(.system(size: 52))
                    .foregroundStyle(Color.white.opacity(0.18))

                if book.isAudio {
                    VStack {
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { i in
                                let heights: [CGFloat] = [12, 20, 16, 10]
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.mlPurple.opacity(0.85))
                                    .frame(width: 3, height: heights[i])
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .frame(width: 148, height: 176)
                }

                VStack {
                    Spacer()
                    HStack {
                        Label(book.duration, systemImage: book.isAudio ? "headphones" : "book.fill")
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
                Text(book.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .frame(width: 148, alignment: .leading)
                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mlSubtext)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.mlGold)
                    Text(String(format: "%.1f", book.rating))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white)
                    Text("·").foregroundStyle(Color.mlMuted)
                    Text(book.genre)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.mlSubtext)
                }
            }
            .frame(width: 148)
        }
    }
}

// MARK: - Werewolf Genre Grid
struct GenreGrid: View {
    private let cards: [(String, String, Color, Color)] = [
        ("Luna",     "moon.stars.fill",   Color(red: 0.08, green: 0.02, blue: 0.20), Color(red: 0.40, green: 0.12, blue: 0.60)),
        ("Alpha",    "crown.fill",        Color(red: 0.12, green: 0.02, blue: 0.06), Color(red: 0.55, green: 0.10, blue: 0.25)),
        ("Mate",     "heart.fill",        Color(red: 0.10, green: 0.02, blue: 0.12), Color(red: 0.58, green: 0.12, blue: 0.42)),
        ("Rejected", "heart.slash.fill",  Color(red: 0.05, green: 0.05, blue: 0.16), Color(red: 0.16, green: 0.22, blue: 0.58)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Werewolf Genres", action: "See all")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(cards, id: \.0) { c in
                    GenreGridCell(name: c.0, icon: c.1, top: c.2, bot: c.3)
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

    var body: some View {
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - New Releases
struct NewReleasesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "New Releases", action: "See all")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ML.newReleases) { book in SmallCard(book: book) }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct SmallCard: View {
    let book: StoryBook

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [book.topColor, book.botColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 108, height: 143)

                Image(systemName: book.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.white.opacity(0.18))

                if book.isNew {
                    VStack {
                        HStack {
                            Text("NEW")
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
                Text(book.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .frame(width: 108, alignment: .leading)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.mlGold)
                    Text(String(format: "%.1f", book.rating))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 108)
        }
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
