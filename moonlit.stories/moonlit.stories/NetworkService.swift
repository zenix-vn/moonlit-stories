import Foundation
import UIKit
import Security

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Network Models

struct User: Codable {
    let id: String
    let email: String?
    let username: String?
    let avatarUrl: String?
    let authProvider: String
    let providerUserId: String?
    let status: String
    let level: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
        case authProvider = "auth_provider"
        case providerUserId = "provider_user_id"
        case status
        case level
    }
}

struct Wallet: Codable {
    let userId: String
    let coins: Int
    let gems: Int
    let freePass: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case coins
        case gems
        case freePass = "free_pass"
    }
}

struct GuestLoginResponse: Codable {
    let token: String
    let user: User
    let wallet: Wallet
    let isNewUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case token
        case user
        case wallet
        case isNewUser = "is_new_user"
    }
}

struct ReaderPreferences: Codable {
    var fontSize: Double?
    var fontName: String?
    var theme: String?
    var autoUnlockEpisodes: Bool?
    var audioPlaybackSpeed: Double?
    var pushNotificationsEnabled: Bool?
    var dailyReadingReminder: Bool?
    
    enum CodingKeys: String, CodingKey {
        case fontSize = "fontSize"
        case fontName = "fontName"
        case theme = "theme"
        case autoUnlockEpisodes = "autoUnlockEpisodes"
        case audioPlaybackSpeed = "audioPlaybackSpeed"
        case pushNotificationsEnabled = "pushNotificationsEnabled"
        case dailyReadingReminder = "dailyReadingReminder"
    }
}

struct UserProfile: Codable {
    let displayName: String?
    let bio: String?
    let countryCode: String?
    let countryName: String?
    let timezone: String?
    let language: String
    let readingPreference: ReaderPreferences?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case bio
        case countryCode = "country_code"
        case countryName = "country_name"
        case timezone
        case language
        case readingPreference = "reading_preference"
    }
}

struct UserStats: Codable {
    let readingHours: Double
    let activeStreak: Int
    let episodesUnlocked: Int
    
    enum CodingKeys: String, CodingKey {
        case readingHours = "reading_hours"
        case activeStreak = "active_streak"
        case episodesUnlocked = "episodes_unlocked"
    }
}

struct MeResponse: Codable {
    let user: User
    let profile: UserProfile?
    let wallet: Wallet
    let stats: UserStats?
}

struct PushNotificationItem: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let deepLink: String?
    let status: String
    let sentAt: String
    let openedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case deepLink = "deep_link"
        case status
        case sentAt = "sent_at"
        case openedAt = "opened_at"
    }
}

struct SubscriptionDetail: Codable {
    let id: String
    let userId: String
    let productId: String?
    let platform: String
    let status: String
    let startedAt: String?
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case platform
        case status
        case startedAt = "started_at"
        case expiresAt = "expires_at"
    }
}

struct SubscriptionResponse: Codable {
    let isSubscribed: Bool
    let subscription: SubscriptionDetail?
    
    enum CodingKeys: String, CodingKey {
        case isSubscribed = "is_subscribed"
        case subscription
    }
}

struct RewardsStreak: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActiveDate: String?

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActiveDate = "last_active_date"
    }
}

struct RewardCalendarItem: Codable, Identifiable {
    let day: Int
    let type: String
    let amount: Int
    var id: Int { day }
}

struct RewardsDashboard: Codable {
    let streak: RewardsStreak
    let checkedInToday: Bool
    let rewardsCalendar: [RewardCalendarItem]
    let todayDate: String

    enum CodingKeys: String, CodingKey {
        case streak
        case checkedInToday = "checked_in_today"
        case rewardsCalendar = "rewards_calendar"
        case todayDate = "today_date"
    }
}

struct DailyTaskProgress: Codable, Identifiable {
    let taskID: String
    let code: String
    let title: String
    let description: String
    let targetEvent: String
    let targetValue: Int
    let rewardType: String
    let rewardAmount: Int
    let progress: Int
    let completedAt: String?
    let claimedAt: String?

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case code
        case title
        case description
        case targetEvent = "target_event"
        case targetValue = "target_value"
        case rewardType = "reward_type"
        case rewardAmount = "reward_amount"
        case progress
        case completedAt = "completed_at"
        case claimedAt = "claimed_at"
    }

    var id: String { taskID }
    var isCompleted: Bool { progress >= targetValue }
    var isClaimed: Bool { claimedAt != nil }
}

struct DailyCheckinResponse: Codable {
    let status: String
    let rewardType: String
    let rewardAmount: Int
    let streakDay: Int
    let totalStreak: Int
    let coins: Int?
    let freePasses: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case rewardType = "reward_type"
        case rewardAmount = "reward_amount"
        case streakDay = "streak_day"
        case totalStreak = "total_streak"
        case coins
        case freePasses = "free_passes"
    }
}

struct TaskClaimResponse: Codable {
    let status: String
    let rewardType: String
    let rewardAmount: Int
    let coins: Int?
    let freePasses: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case rewardType = "reward_type"
        case rewardAmount = "reward_amount"
        case coins
        case freePasses = "free_passes"
    }
}

struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let slug: String
    let description: String?
    let hook: String?
    let coverUrl: String?
    let freeEpisodeCount: Int
    let defaultCoinPrice: Int
    let totalEpisodes: Int
    let isFeatured: Bool
    let isHot: Bool
    let isEditorPick: Bool
    let genres: [String]?
    let moods: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case slug
        case description
        case hook
        case coverUrl = "cover_url"
        case freeEpisodeCount = "free_episode_count"
        case defaultCoinPrice = "default_coin_price"
        case totalEpisodes = "total_episodes"
        case isFeatured = "is_featured"
        case isHot = "is_hot"
        case isEditorPick = "is_editor_pick"
        case genres
        case moods
    }
    
    // Hashable conformance to help SwiftUI collections
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Story, rhs: Story) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ContinueReadingItem: Codable, Identifiable {
    var id: String { storyId }
    let storyId: String
    let storyTitle: String
    let storySlug: String
    let coverUrl: String?
    let episodeId: String
    let episodeTitle: String
    let episodeNumber: Int
    let progressPercent: Double
    
    enum CodingKeys: String, CodingKey {
        case storyId = "story_id"
        case storyTitle = "story_title"
        case storySlug = "story_slug"
        case coverUrl = "cover_url"
        case episodeId = "episode_id"
        case episodeTitle = "episode_title"
        case episodeNumber = "episode_number"
        case progressPercent = "progress_percent"
    }
}

struct Banner: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let imageUrl: String
    let deepLink: String?
    let placement: String
    let priority: Int?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case imageUrl = "image_url"
        case deepLink = "deep_link"
        case placement
        case priority
        case createdAt = "created_at"
    }
}

struct HomeResponse: Codable {
    let greeting: String
    let wallet: Wallet
    let featuredStory: Story?
    let continueReading: [ContinueReadingItem]?
    let tonightsPicks: [Story]
    let trendingNow: [Story]
    let freeEpisodesToday: [Story]?
    let banners: [Banner]?
    let heroCard: HomeHeroCard?
}

struct HomeHeroCard: Codable {
    let metric: String
    let title: String
    let subtitle: String
    let ctaText: String
    let ctaDeepLink: String?

    enum CodingKeys: String, CodingKey {
        case metric
        case title
        case subtitle
        case ctaText = "cta_text"
        case ctaDeepLink = "cta_deep_link"
    }
}

struct LibraryItem: Codable, Identifiable {
    var id: String { storyID }
    let storyID: String
    let title: String
    let slug: String
    let description: String
    let coverURL: String
    let type: String
    let savedAt: String

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case title
        case slug
        case description
        case coverURL = "cover_url"
        case type
        case savedAt = "saved_at"
    }
}

struct Genre: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let sortOrder: Int
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case description
        case sortOrder = "sort_order"
        case active
    }
}

// MARK: - Network Client

class NetworkService {
    static let shared = NetworkService()
    
    private let baseURL = URL(string: "https://moonlit.zenix.vn")!
    private let tokenKey = "ml_auth_token"
    private let deviceIdKey = "ml_device_uuid"
    
    private init() {
        // Migrate legacy token from UserDefaults → Keychain (one-time)
        if let legacy = UserDefaults.standard.string(forKey: tokenKey) {
            KeychainHelper.save(legacy, forKey: tokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
        // Migrate legacy deviceId from UserDefaults → Keychain (one-time)
        if let legacy = UserDefaults.standard.string(forKey: deviceIdKey) {
            KeychainHelper.save(legacy, forKey: deviceIdKey)
            UserDefaults.standard.removeObject(forKey: deviceIdKey)
        }
    }
    
    // Check if token exists
    var hasToken: Bool {
        return KeychainHelper.load(forKey: tokenKey) != nil
    }
    
    // Get stored token (from Keychain)
    var token: String? {
        return KeychainHelper.load(forKey: tokenKey)
    }
    
    // Clear stored credentials from Keychain
    func logout() {
        KeychainHelper.delete(forKey: tokenKey)
    }
    
    // Helper to get or create stable device uuid (stored in Keychain, persists across reinstalls)
    private func getOrCreateDeviceID() -> String {
        if let savedID = KeychainHelper.load(forKey: deviceIdKey) {
            return savedID
        }
        let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        KeychainHelper.save(newID, forKey: deviceIdKey)
        return newID
    }
    
    // Perform guest login authentication
    func authenticateGuest() async throws -> GuestLoginResponse {
        let deviceID = getOrCreateDeviceID()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let timezone = TimeZone.current.identifier
        
        let locale = Locale.current
        let countryCode = locale.region?.identifier ?? "US"
        let countryName = locale.localizedString(forRegionCode: countryCode) ?? "United States"
        
        let requestBody: [String: Any] = [
            "device_id": deviceID,
            "platform": "ios",
            "os_version": osVersion,
            "app_version": appVersion,
            "country_code": countryCode,
            "country_name": countryName,
            "timezone": timezone
        ]
        
        let url = baseURL.appendingPathComponent("/v1/auth/guest")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMsg = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let err = errorMsg["error"] {
                throw NSError(domain: "NetworkService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let authResponse = try decoder.decode(GuestLoginResponse.self, from: data)
        
        // Save token securely to Keychain
        KeychainHelper.save(authResponse.token, forKey: tokenKey)
        
        return authResponse
    }
    
    // Fetch home feed
    func fetchHomeFeed(retryCount: Int = 0) async throws -> HomeResponse {
        // Serve from cache if available
        if let cached: HomeResponse = APICache.shared.get(APICache.Key.homeFeed) {
            return cached
        }
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await fetchHomeFeed(retryCount: retryCount + 1)
        }
        
        let url = baseURL.appendingPathComponent("/v1/home")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await fetchHomeFeed(retryCount: retryCount + 1)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(HomeResponse.self, from: data)
        APICache.shared.set(APICache.Key.homeFeed, value: result, ttl: APICache.TTL.homeFeed)
        return result
    }
    
    // Generic authenticated GET helper
    private func authenticatedGet<T: Decodable>(_ path: String, retryCount: Int = 0) async throws -> T {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedGet(path, retryCount: retryCount + 1)
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedGet(path, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errObj = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = errObj["error"] {
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func authenticatedPost<T: Decodable, U: Encodable>(_ path: String, body: U, retryCount: Int = 0) async throws -> T {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedPost(path, body: body, retryCount: retryCount + 1)
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedPost(path, body: body, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func authenticatedPostNoBody<T: Decodable>(_ path: String, retryCount: Int = 0) async throws -> T {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedPostNoBody(path, retryCount: retryCount + 1)
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedPostNoBody(path, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errObj = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = errObj["error"] {
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func authenticatedPostNoContent<U: Encodable>(_ path: String, body: U, retryCount: Int = 0) async throws {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedPostNoContent(path, body: body, retryCount: retryCount + 1)
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await authenticatedPostNoContent(path, body: body, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Fetch episode list for a story (with access info)
    func fetchStoryEpisodes(slug: String) async throws -> [EpisodeMeta] {
        let cacheKey = APICache.Key.episodes(slug)
        if let cached: [EpisodeMeta] = APICache.shared.get(cacheKey) { return cached }
        let result: [EpisodeMeta] = try await authenticatedGet("/v1/stories/\(slug)/episodes")
        APICache.shared.setTracked(cacheKey, value: result, ttl: APICache.TTL.episodes)
        return result
    }

    func startReadingSession(storyID: String, episodeID: String) async throws -> String {
        let locale = Locale.current
        let countryCode = locale.region?.identifier ?? "US"
        let countryName = locale.localizedString(forRegionCode: countryCode) ?? "United States"
        let request = ReadingSessionStartRequest(
            storyID: storyID,
            episodeID: episodeID,
            platform: "ios",
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            countryCode: countryCode,
            countryName: countryName
        )
        let response: ReadingSessionStartResponse = try await authenticatedPost("/v1/reading/session/start", body: request)
        return response.sessionID
    }

    func updateReadingProgress(storyID: String, episodeID: String, progressPercent: Double, currentPosition: Int) async throws {
        let request = ReadingProgressRequest(
            storyID: storyID,
            episodeID: episodeID,
            progressPercent: progressPercent,
            currentPosition: currentPosition
        )
        try await authenticatedPostNoContent("/v1/reading/progress", body: request)
    }

    func endReadingSession(sessionID: String, durationSeconds: Int, progressStart: Double, progressEnd: Double, completed: Bool) async throws {
        let request = ReadingSessionEndRequest(
            sessionID: sessionID,
            durationSeconds: durationSeconds,
            progressStart: progressStart,
            progressEnd: progressEnd,
            completed: completed
        )
        try await authenticatedPostNoContent("/v1/reading/session/end", body: request)
    }
    
    // Fetch full episode content
    func fetchEpisodeDetail(episodeId: String, retryCount: Int = 0) async throws -> EpisodeDetail {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await fetchEpisodeDetail(episodeId: episodeId, retryCount: retryCount + 1)
        }

        let url = baseURL.appendingPathComponent("/v1/episodes/\(episodeId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await fetchEpisodeDetail(episodeId: episodeId, retryCount: retryCount + 1)
        }

        let decoder = JSONDecoder()
        let envelope = try decoder.decode(EpisodeDetailEnvelope.self, from: data)

        if var episode = envelope.episode {
            if let hasAccess = envelope.hasAccess {
                episode.hasAccess = hasAccess
            }
            return episode
        }

        if let message = envelope.error {
            throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid episode response"])
    }
    
    // Unlock episode with Coins
    func unlockEpisodeWithCoins(episodeId: String) async throws -> UnlockResponse {
        let result: UnlockResponse = try await authenticatedPostNoBody("/v1/episodes/\(episodeId)/unlock/coins")
        // Invalidate episode detail cache so hasAccess updates
        APICache.shared.invalidate("episode_\(episodeId)")
        APICache.shared.invalidate(APICache.Key.libraryMap)
        return result
    }

    // Unlock episode with Free Pass
    func unlockEpisodeWithFreePass(episodeId: String) async throws -> UnlockResponse {
        let result: UnlockResponse = try await authenticatedPostNoBody("/v1/episodes/\(episodeId)/unlock/free-pass")
        APICache.shared.invalidate("episode_\(episodeId)")
        APICache.shared.invalidate(APICache.Key.libraryMap)
        return result
    }

    // Unlock episode with Ad
    func unlockEpisodeWithAd(episodeId: String) async throws -> UnlockResponse {
        let result: UnlockResponse = try await authenticatedPostNoBody("/v1/episodes/\(episodeId)/unlock/ad")
        APICache.shared.invalidate("episode_\(episodeId)")
        APICache.shared.invalidate(APICache.Key.libraryMap)
        return result
    }

    // Fetch active products/subscription packages
    func fetchProducts() async throws -> [Product] {
        return try await authenticatedGet("/v1/products")
    }

    // Verify IAP Receipt/Purchase on Server
    func verifyIAPPurchase(productCode: String, transactionId: String) async throws -> IAPVerifyResponse {
        let request = IAPVerifyRequest(productCode: productCode, platform: "apple", transactionID: transactionId)
        return try await authenticatedPost("/v1/iap/verify", body: request)
    }

    func fetchRewardsDashboard() async throws -> RewardsDashboard {
        return try await authenticatedGet("/v1/rewards/dashboard")
    }

    func claimDailyCheckin() async throws -> DailyCheckinResponse {
        return try await authenticatedPostNoBody("/v1/rewards/checkin")
    }

    func fetchDailyTasks() async throws -> [DailyTaskProgress] {
        return try await authenticatedGet("/v1/tasks/daily")
    }

    func claimTaskReward(taskId: String) async throws -> TaskClaimResponse {
        return try await authenticatedPostNoBody("/v1/tasks/\(taskId)/claim")
    }
    
    // Fetch story detail by slug — backend returns { "story": {...}, "episodes": [...] }
    func fetchStoryBySlug(slug: String) async throws -> StoryDetail {
        let cacheKey = APICache.Key.story(slug)
        if let cached: StoryDetail = APICache.shared.get(cacheKey) { return cached }
        let envelope: StoryBySlugEnvelope = try await authenticatedGet("/v1/stories/\(slug)")
        APICache.shared.set(cacheKey, value: envelope.story, ttl: APICache.TTL.stories)
        return envelope.story
    }

    // Fetch active genres for home taxonomy section
    func fetchGenres() async throws -> [Genre] {
        if let cached: [Genre] = APICache.shared.get(APICache.Key.genres) { return cached }
        let result: [Genre] = try await authenticatedGet("/v1/genres")
        APICache.shared.set(APICache.Key.genres, value: result, ttl: APICache.TTL.genres)
        return result
    }

    // Fetch banners by placement
    func fetchBanners(placement: String) async throws -> [Banner] {
        let cacheKey = APICache.Key.banners(placement)
        if let cached: [Banner] = APICache.shared.get(cacheKey) { return cached }
        let encoded = placement.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? placement
        let banners: [Banner] = try await authenticatedGet("/v1/banners?placement=\(encoded)")
        #if DEBUG
        print("[BannerDebug] placement=\(placement), count=\(banners.count)")
        #endif
        APICache.shared.set(cacheKey, value: banners, ttl: APICache.TTL.banners)
        return banners
    }

    // Discover stories for Search tab
    func fetchDiscoverStories(search: String? = nil, genre: String? = nil) async throws -> [Story] {
        let cacheKey = APICache.Key.discover(search: search, genre: genre)
        if let cached: [Story] = APICache.shared.get(cacheKey) { return cached }
        var queryItems: [URLQueryItem] = []
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if let genre, !genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "genre", value: genre.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        var path = "/v1/discover"
        if !queryItems.isEmpty {
            var components = URLComponents()
            components.queryItems = queryItems
            let query = components.percentEncodedQuery ?? ""
            if !query.isEmpty {
                path += "?\(query)"
            }
        }
        let result: [Story] = try await authenticatedGet(path)
        // Only cache if not a live search query (empty or genre-only filters)
        if search == nil || search!.isEmpty {
            APICache.shared.set(cacheKey, value: result, ttl: APICache.TTL.stories)
        }
        return result
    }

    // Library list for Library tab
    func fetchLibrary(type: String? = nil) async throws -> [LibraryItem] {
        var path = "/v1/library"
        if let type, !type.isEmpty {
            let encoded = type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? type
            path += "?type=\(encoded)"
        }
        return try await authenticatedGet(path)
    }

    // Fetch all library statuses for badges
    func fetchLibraryStatusMap() async throws -> [String: Set<String>] {
        if let cached: [String: Set<String>] = APICache.shared.get(APICache.Key.libraryMap) {
            return cached
        }
        async let savedTask = fetchLibrary(type: "saved")
        async let historyTask = fetchLibrary(type: "history")
        async let completedTask = fetchLibrary(type: "completed")

        let saved = try await savedTask
        let history = try await historyTask
        let completed = try await completedTask

        var map: [String: Set<String>] = [:]
        for item in saved     { map[item.storyID, default: []].insert("saved") }
        for item in history   { map[item.storyID, default: []].insert("history") }
        for item in completed { map[item.storyID, default: []].insert("completed") }
        APICache.shared.set(APICache.Key.libraryMap, value: map, ttl: APICache.TTL.libraryMap)
        return map
    }

    // Save story into library
    func addToLibrary(storyID: String, type: String = "saved", retryCount: Int = 0) async throws {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await addToLibrary(storyID: storyID, type: type, retryCount: retryCount + 1)
        }

        let url = baseURL.appendingPathComponent("/v1/library/save")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "story_id": storyID,
            "type": type,
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await addToLibrary(storyID: storyID, type: type, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Invalidate library cache so status badges refresh
        APICache.shared.invalidate(APICache.Key.libraryMap)
    }

    // Remove story from library
    func removeFromLibrary(storyID: String, type: String = "saved", retryCount: Int = 0) async throws {
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await removeFromLibrary(storyID: storyID, type: type, retryCount: retryCount + 1)
        }

        let encodedStoryID = storyID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? storyID
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/v1/library/save/\(encodedStoryID)"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "type", value: type)]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await removeFromLibrary(storyID: storyID, type: type, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Invalidate library cache
        APICache.shared.invalidate(APICache.Key.libraryMap)
    }

    // Fetch profile details
    func fetchMe() async throws -> MeResponse {
        return try await authenticatedGet("/v1/me")
    }

    // Fetch subscription details
    func fetchSubscription() async throws -> SubscriptionResponse {
        return try await authenticatedGet("/v1/me/subscription")
    }
    
    // Update profile details
    func updateMe(displayName: String?, email: String?, bio: String?, preferences: ReaderPreferences?, retryCount: Int = 0) async throws -> MeResponse {
        struct UpdatePayload: Encodable {
            let display_name: String?
            let email: String?
            let bio: String?
            let reading_preference: ReaderPreferences?
        }
        let payload = UpdatePayload(display_name: displayName, email: email, bio: bio, reading_preference: preferences)
        
        guard let token = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await updateMe(displayName: displayName, email: email, bio: bio, preferences: preferences, retryCount: retryCount + 1)
        }
        
        let url = baseURL.appendingPathComponent("/v1/me")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await updateMe(displayName: displayName, email: email, bio: bio, preferences: preferences, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MeResponse.self, from: data)
    }

    // Register push token
    func registerPushToken(token: String, retryCount: Int = 0) async throws {
        struct RegisterPayload: Encodable {
            let token: String
            let platform: String
        }
        let payload = RegisterPayload(token: token, platform: "ios")
        
        guard let authToken = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await registerPushToken(token: token, retryCount: retryCount + 1)
        }
        
        let url = baseURL.appendingPathComponent("/v1/notifications/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await registerPushToken(token: token, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // Fetch notification logs
    func fetchNotifications() async throws -> [PushNotificationItem] {
        return try await authenticatedGet("/v1/notifications")
    }

    // Open notification
    func openNotification(id: String, retryCount: Int = 0) async throws {
        guard let authToken = self.token else {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await openNotification(id: id, retryCount: retryCount + 1)
        }
        
        let url = baseURL.appendingPathComponent("/v1/notifications/\(id)/open")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 {
            guard retryCount < 1 else { throw URLError(.userAuthenticationRequired) }
            _ = try await authenticateGuest()
            return try await openNotification(id: id, retryCount: retryCount + 1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Reader Models

struct EpisodeMeta: Codable, Identifiable {
    let id: String
    let episodeNumber: Int
    let title: String
    let slug: String?
    let isFree: Bool
    let coinPrice: Int
    let wordCount: Int
    let estimatedReadingTime: Int
    let hasAccess: Bool
    let unlockMethod: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case episodeNumber = "episode_number"
        case title
        case slug
        case isFree = "is_free"
        case coinPrice = "coin_price"
        case wordCount = "word_count"
        case estimatedReadingTime = "estimated_reading_time"
        case hasAccess = "has_access"
        case unlockMethod = "unlock_method"
    }
}

struct EpisodeDetail: Codable, Identifiable {
    let id: String
    let storyId: String
    let storyTitle: String?
    let storySlug: String?
    let episodeNumber: Int
    let title: String
    let contentText: String?
    let previewText: String?
    let audioUrl: String?
    let isFree: Bool
    let coinPrice: Int
    let wordCount: Int
    let estimatedReadingTime: Int
    var hasAccess: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case storyTitle = "story_title"
        case storySlug = "story_slug"
        case episodeNumber = "episode_number"
        case title
        case contentText = "content_text"
        case previewText = "preview_text"
        case audioUrl = "audio_url"
        case isFree = "is_free"
        case coinPrice = "coin_price"
        case wordCount = "word_count"
        case estimatedReadingTime = "estimated_reading_time"
        case hasAccess = "has_access"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        storyId = try c.decode(String.self, forKey: .storyId)
        storyTitle = try c.decodeIfPresent(String.self, forKey: .storyTitle)
        storySlug = try c.decodeIfPresent(String.self, forKey: .storySlug)
        episodeNumber = try c.decode(Int.self, forKey: .episodeNumber)
        title = try c.decode(String.self, forKey: .title)
        contentText = try c.decodeIfPresent(String.self, forKey: .contentText)
        previewText = try c.decodeIfPresent(String.self, forKey: .previewText)
        audioUrl = try c.decodeIfPresent(String.self, forKey: .audioUrl)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        coinPrice = try c.decodeIfPresent(Int.self, forKey: .coinPrice) ?? 0
        wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        estimatedReadingTime = try c.decodeIfPresent(Int.self, forKey: .estimatedReadingTime) ?? 0
        hasAccess = try c.decodeIfPresent(Bool.self, forKey: .hasAccess) ?? false
    }
}

struct EpisodeDetailEnvelope: Codable {
    let hasAccess: Bool?
    let method: String?
    let coinPrice: Int?
    let isFree: Bool?
    let episode: EpisodeDetail?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case hasAccess = "has_access"
        case method
        case coinPrice = "coin_price"
        case isFree = "is_free"
        case episode
        case error
    }
}

private struct StoryBySlugEnvelope: Decodable {
    let story: StoryDetail
}

struct StoryDetail: Codable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let description: String?
    let hook: String?
    let coverUrl: String?
    let freeEpisodeCount: Int
    let totalEpisodes: Int
    let isFeatured: Bool
    let isHot: Bool
    let genres: [String]?
    let moods: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, hook
        case coverUrl = "cover_url"
        case freeEpisodeCount = "free_episode_count"
        case totalEpisodes = "total_episodes"
        case isFeatured = "is_featured"
        case isHot = "is_hot"
        case genres, moods
    }
}

struct ReadingSessionStartResponse: Codable {
    let sessionID: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}

struct ReadingSessionStartRequest: Encodable {
    let storyID: String
    let episodeID: String
    let platform: String
    let deviceID: String
    let countryCode: String
    let countryName: String

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case episodeID = "episode_id"
        case platform
        case deviceID = "device_id"
        case countryCode = "country_code"
        case countryName = "country_name"
    }
}

struct ReadingSessionEndRequest: Encodable {
    let sessionID: String
    let durationSeconds: Int
    let progressStart: Double
    let progressEnd: Double
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case durationSeconds = "duration_seconds"
        case progressStart = "progress_start"
        case progressEnd = "progress_end"
        case completed
    }
}

struct ReadingProgressRequest: Encodable {
    let storyID: String
    let episodeID: String
    let progressPercent: Double
    let currentPosition: Int

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case episodeID = "episode_id"
        case progressPercent = "progress_percent"
        case currentPosition = "current_position"
    }
}

struct UnlockResponse: Codable {
    let status: String
    let unlockedAt: String?
    let coinsLeft: Int?
    let freePassesLeft: Int?
    
    enum CodingKeys: String, CodingKey {
        case status
        case unlockedAt = "unlocked_at"
        case coinsLeft = "coins_left"
        case freePassesLeft = "free_passes_left"
    }
}

struct Product: Codable, Identifiable {
    let id: String
    let code: String
    let name: String
    let type: String // 'coin_pack', 'subscription'
    let price: Double
    let currency: String
    let coinAmount: Int?
    let bonusCoinAmount: Int?
    let active: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, code, name, type, price, currency, active
        case coinAmount = "coin_amount"
        case bonusCoinAmount = "bonus_coin_amount"
    }
}

struct IAPVerifyRequest: Encodable {
    let productCode: String
    let platform: String
    let transactionID: String
    
    enum CodingKeys: String, CodingKey {
        case productCode = "product_code"
        case platform
        case transactionID = "transaction_id"
    }
}

struct IAPVerifyResponse: Decodable {
    let status: String
    let wallet: Wallet?
}
