import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

// MARK: - AnalyticsService
// Lightweight, fire-and-forget behavioral analytics client.
// Sends events to the backend `/v1/events` ingestion endpoint, which writes to
// the `analytics_events` table powering the admin dashboard. Events never block
// the UI and silently no-op if the user is not yet authenticated.

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    /// Stable per-app-launch session identifier. Groups events into a session.
    let sessionID = UUID().uuidString

    private let platform = "ios"
    private let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

    private init() {}

    /// Track a behavioral event. Fire-and-forget; safe to call from any UI path.
    func track(_ event: Event, _ properties: [String: Any] = [:]) {
        let locale = Locale.current
        let countryCode = locale.region?.identifier
        let countryName = countryCode.flatMap { locale.localizedString(forRegionCode: $0) }
        let session = sessionID
        let platform = self.platform
        let appVersion = self.appVersion

        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: properties)
        #endif

        Task.detached(priority: .background) {
            await NetworkService.shared.logEvent(
                name: event.rawValue,
                properties: properties,
                sessionID: session,
                platform: platform,
                appVersion: appVersion,
                countryCode: countryCode,
                countryName: countryName
            )
        }
    }
}

// MARK: - Event Catalog
// Centralized, typo-proof event names. Keep in sync with backend consumers.

extension AnalyticsService {
    enum Event: String {
        case appOpen          = "app_open"
        case storyView        = "story_view"
        case episodeView      = "episode_view"
        case episodeUnlock    = "episode_unlock"
        case episodeCompleted = "episode_completed"
        case search           = "search"
        case purchaseSuccess  = "purchase_success"
        case rewardClaim      = "reward_claim"
    }
}
