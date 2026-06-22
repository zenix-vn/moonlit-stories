import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdMobRewardedManager: NSObject, ObservableObject {
    static let shared = AdMobRewardedManager()

    @Published var isLoaded = false
    @Published var isLoading = false
    @Published var lastError: Error? = nil

    #if canImport(GoogleMobileAds)
    private var rewardedAd: GADRewardedAd?
    private let adUnitID = "ca-app-pub-7988416399180373/6649023616"
    #endif

    private override init() {
        super.init()
        #if canImport(GoogleMobileAds)
        Task { await loadRewardedAd() }
        #endif
    }

    func loadRewardedAd() async {
        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        do {
            let request = GADRequest()
            let ad = try await GADRewardedAd.load(withAdUnitID: adUnitID, request: request)
            self.rewardedAd = ad
            self.isLoaded = true
            self.lastError = nil
            ad.fullScreenContentDelegate = self
        } catch {
            self.isLoaded = false
            self.lastError = error
            await scheduleRetryLoad(after: 10)
        }

        isLoading = false
        #else
        self.isLoaded = false
        #endif
    }

    #if canImport(GoogleMobileAds)
    func presentRewardedAd(from rootViewController: UIViewController) async throws -> GADAdReward {
        guard let ad = rewardedAd else {
            throw NSError(domain: "AdMob", code: -1, userInfo: [NSLocalizedDescriptionKey: "Rewarded ad is not ready"])
        }

        isLoaded = false
        rewardedAd = nil

        return try await withCheckedThrowingContinuation { continuation in
            ad.present(fromRootViewController: rootViewController) {
                continuation.resume(returning: ad.adReward)
            }
        }
    }
    #endif

    private func scheduleRetryLoad(after seconds: TimeInterval) async {
        #if canImport(GoogleMobileAds)
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        await loadRewardedAd()
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension AdMobRewardedManager: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { await MainActor.run { self.lastError = error; self.isLoaded = false } }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { await loadRewardedAd() }
    }
}
#endif
