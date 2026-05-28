import Foundation
import UIKit

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
    
    private init() {}
    
    // Check if token exists
    var hasToken: Bool {
        return UserDefaults.standard.string(forKey: tokenKey) != nil
    }
    
    // Get stored token
    var token: String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
    
    // Clear stored credentials
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    // Helper to get or create stable device uuid
    private func getOrCreateDeviceID() -> String {
        if let savedID = UserDefaults.standard.string(forKey: deviceIdKey) {
            return savedID
        }
        let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIdKey)
        return newID
    }
    
    // Perform guest login authentication
    func authenticateGuest() async throws -> GuestLoginResponse {
        let deviceID = getOrCreateDeviceID()
        let osVersion = UIDevice.current.systemVersion
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
        
        // Save token to UserDefaults
        UserDefaults.standard.set(authResponse.token, forKey: tokenKey)
        
        return authResponse
    }
    
    // Fetch home feed
    func fetchHomeFeed() async throws -> HomeResponse {
        guard let token = self.token else {
            // No token found, attempt auto guest authentication first
            _ = try await authenticateGuest()
            return try await fetchHomeFeed()
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
            // Token might be expired, re-authenticate and retry
            _ = try await authenticateGuest()
            return try await fetchHomeFeed()
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(HomeResponse.self, from: data)
    }
    
    // Generic authenticated GET helper
    private func authenticatedGet<T: Decodable>(_ path: String) async throws -> T {
        guard let token = self.token else {
            _ = try await authenticateGuest()
            return try await authenticatedGet(path)
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
            _ = try await authenticateGuest()
            return try await authenticatedGet(path)
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

    private func authenticatedPost<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T {
        guard let token = self.token else {
            _ = try await authenticateGuest()
            return try await authenticatedPost(path, body: body)
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
            _ = try await authenticateGuest()
            return try await authenticatedPost(path, body: body)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func authenticatedPostNoContent<U: Encodable>(_ path: String, body: U) async throws {
        guard let token = self.token else {
            _ = try await authenticateGuest()
            return try await authenticatedPostNoContent(path, body: body)
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
            _ = try await authenticateGuest()
            return try await authenticatedPostNoContent(path, body: body)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Fetch episode list for a story (with access info)
    func fetchStoryEpisodes(slug: String) async throws -> [EpisodeMeta] {
        return try await authenticatedGet("/v1/stories/\(slug)/episodes")
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
    func fetchEpisodeDetail(episodeId: String) async throws -> EpisodeDetail {
        guard let token = self.token else {
            _ = try await authenticateGuest()
            return try await fetchEpisodeDetail(episodeId: episodeId)
        }

        let url = baseURL.appendingPathComponent("/v1/episodes/\(episodeId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if httpResponse.statusCode == 401 {
            _ = try await authenticateGuest()
            return try await fetchEpisodeDetail(episodeId: episodeId)
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
    
    // Fetch story detail by slug — backend returns { "story": {...}, "episodes": [...] }
    func fetchStoryBySlug(slug: String) async throws -> StoryDetail {
        let envelope: StoryBySlugEnvelope = try await authenticatedGet("/v1/stories/\(slug)")
        return envelope.story
    }

    // Fetch active genres for home taxonomy section
    func fetchGenres() async throws -> [Genre] {
        return try await authenticatedGet("/v1/genres")
    }

    // Fetch banners by placement
    func fetchBanners(placement: String) async throws -> [Banner] {
        let encoded = placement.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? placement
        let banners: [Banner] = try await authenticatedGet("/v1/banners?placement=\(encoded)")
        #if DEBUG
        print("[BannerDebug] placement=\(placement), count=\(banners.count)")
        for (index, banner) in banners.enumerated() {
            print("[BannerDebug] \(placement)[\(index)] id=\(banner.id) title=\(banner.title) priority=\(banner.priority ?? -1) created_at=\(banner.createdAt ?? "nil") backendPlacement=\(banner.placement)")
        }
        #endif
        return banners
    }

    // Discover stories for Search tab
    func fetchDiscoverStories(search: String? = nil, genre: String? = nil) async throws -> [Story] {
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
        return try await authenticatedGet(path)
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
        async let savedTask = fetchLibrary(type: "saved")
        async let historyTask = fetchLibrary(type: "history")
        async let completedTask = fetchLibrary(type: "completed")

        let saved = try await savedTask
        let history = try await historyTask
        let completed = try await completedTask

        var map: [String: Set<String>] = [:]
        for item in saved {
            map[item.storyID, default: []].insert("saved")
        }
        for item in history {
            map[item.storyID, default: []].insert("history")
        }
        for item in completed {
            map[item.storyID, default: []].insert("completed")
        }
        return map
    }

    // Save story into library
    func addToLibrary(storyID: String, type: String = "saved") async throws {
        guard let token = self.token else {
            _ = try await authenticateGuest()
            return try await addToLibrary(storyID: storyID, type: type)
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
            _ = try await authenticateGuest()
            return try await addToLibrary(storyID: storyID, type: type)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // Remove story from library
    func removeFromLibrary(storyID: String, type: String = "saved") async throws {
        guard let token = self.token else {
            _ = try await authenticateGuest()
            return try await removeFromLibrary(storyID: storyID, type: type)
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
            _ = try await authenticateGuest()
            return try await removeFromLibrary(storyID: storyID, type: type)
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
