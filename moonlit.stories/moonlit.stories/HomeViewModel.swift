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
    
    // Refresh function for the home page feed
    func loadFeed() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkService.shared.fetchHomeFeed()
            self.greeting = response.greeting
            self.wallet = response.wallet
            self.featuredStory = response.featuredStory
            self.continueReading = response.continueReading ?? []
            self.tonightsPicks = response.tonightsPicks
            self.trendingNow = response.trendingNow
            self.freeEpisodesToday = response.freeEpisodesToday ?? []
            self.banners = response.banners ?? []
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            print("Error loading home feed: \(error)")
        }
    }
}
