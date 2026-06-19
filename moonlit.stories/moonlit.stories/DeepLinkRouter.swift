import Foundation
import Observation

// MARK: - DeepLinkRouter
// Central sink for deep links arriving from push notifications (and, later,
// universal links / custom URL schemes). Views observe `pendingStorySlug` and
// present the matching destination.
//
// Supported forms:
//   moonlit://story/<slug>
//   https://moonlit.zenix.vn/story/<slug>   (or /stories/<slug>)
//   <slug>                                  (bare slug)

@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// Slug of a story to open. Set by `handle`, consumed and cleared by the view.
    var pendingStorySlug: String?

    private init() {}

    func handle(_ link: String) {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let slug = Self.storySlug(from: trimmed) {
            pendingStorySlug = slug
        }
    }

    /// Consume the pending slug (returns it once, then clears).
    func consumeStorySlug() -> String? {
        defer { pendingStorySlug = nil }
        return pendingStorySlug
    }

    static func storySlug(from link: String) -> String? {
        // URL-based forms.
        if let comps = URLComponents(string: link) {
            let parts = comps.path.split(separator: "/").map(String.init)
            // Match .../story/<slug> or .../stories/<slug>
            if let idx = parts.firstIndex(where: { $0 == "story" || $0 == "stories" }),
               idx + 1 < parts.count {
                return parts[idx + 1]
            }
            // Custom scheme moonlit://story/<slug> puts "story" in host.
            if let host = comps.host, host == "story" || host == "stories",
               let first = parts.first {
                return first
            }
        }
        // Bare slug (no scheme, no slashes).
        if !link.contains("/"), !link.contains(":") {
            return link
        }
        return nil
    }
}
