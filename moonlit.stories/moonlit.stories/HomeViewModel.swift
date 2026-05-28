import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    @Published var greeting: String = "Good Evening"
    @Published var wallet: Wallet? = nil
    @Published var featuredStory: Story? = nil
    @Published var continueReading: [ContinueReadingItem] = []
    @Published var tonightsPicks: [Story] = []
    @Published var trendingNow: [Story] = []
    @Published var freeEpisodesToday: [Story] = []
    @Published var banners: [Banner] = []
    @Published var topBanners: [Banner] = []
    @Published var midBanners: [Banner] = []
    @Published var genres: [Genre] = []
    @Published var heroCard: HomeHeroCard? = nil
    @Published var storyLibraryStatuses: [String: Set<String>] = [:]

    private static let bannerDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let bannerDateFormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func parseBannerDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = HomeViewModel.bannerDateFormatter.date(from: value) {
            return date
        }
        return HomeViewModel.bannerDateFormatterNoFractional.date(from: value)
    }

    private func sortBanners(_ banners: [Banner]) -> [Banner] {
        banners.sorted { lhs, rhs in
            let lp = lhs.priority ?? Int.max
            let rp = rhs.priority ?? Int.max
            if lp != rp {
                return lp < rp
            }

            let ld = parseBannerDate(lhs.createdAt)
            let rd = parseBannerDate(rhs.createdAt)
            switch (ld, rd) {
            case let (l?, r?):
                if l != r {
                    return l < r
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.id < rhs.id
        }
    }
    
    // Refresh function for the home page feed
    func loadFeed() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let homeFeedTask = NetworkService.shared.fetchHomeFeed()
            async let genresTask = NetworkService.shared.fetchGenres()
            async let topBannersTask = NetworkService.shared.fetchBanners(placement: "home_top")
            async let midBannersTask = NetworkService.shared.fetchBanners(placement: "home_mid")
            async let libraryStatusTask = NetworkService.shared.fetchLibraryStatusMap()

            let response = try await homeFeedTask
            let serverGenres = try await genresTask
            let fetchedTopBanners = try await topBannersTask
            let fetchedMidBanners = try await midBannersTask
            let libraryStatus = try await libraryStatusTask
            let sortedTopBanners = sortBanners(fetchedTopBanners)
            let sortedMidBanners = sortBanners(fetchedMidBanners)

            self.greeting = response.greeting
            self.wallet = response.wallet
            self.featuredStory = response.featuredStory
            self.continueReading = response.continueReading ?? []
            self.tonightsPicks = response.tonightsPicks
            self.trendingNow = response.trendingNow
            self.freeEpisodesToday = response.freeEpisodesToday ?? []
            self.banners = response.banners ?? []
            self.topBanners = sortedTopBanners
            self.midBanners = sortedMidBanners
            self.genres = serverGenres.filter { $0.active }
            self.heroCard = response.heroCard
            self.storyLibraryStatuses = libraryStatus
            self.isLoading = false
            #if DEBUG
            print("[BannerDebug] sorted home_top priorities=\(self.topBanners.map { $0.priority ?? -1 })")
            print("[BannerDebug] sorted home_mid priorities=\(self.midBanners.map { $0.priority ?? -1 })")
            print("[BannerDebug] sorted home_top created_at=\(self.topBanners.map { $0.createdAt ?? "nil" })")
            print("[BannerDebug] sorted home_mid created_at=\(self.midBanners.map { $0.createdAt ?? "nil" })")
            #endif
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            print("Error loading home feed: \(error)")
        }
    }
}
