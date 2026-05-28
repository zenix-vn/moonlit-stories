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
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case imageUrl = "image_url"
        case deepLink = "deep_link"
        case placement
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
}
