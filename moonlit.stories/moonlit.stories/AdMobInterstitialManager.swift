import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdMobInterstitialManager: NSObject, ObservableObject {
    static let shared = AdMobInterstitialManager()

    @Published var isLoaded = false
    @Published var isLoading = false
    @Published var lastError: Error? = nil

    #if canImport(GoogleMobileAds)
    private var interstitialAd: GADInterstitialAd?
    private let adUnitID = "ca-app-pub-7988416399180373/6649023616"
    #endif

    private override init() {
        super.init()
        #if canImport(GoogleMobileAds)
        Task { await loadInterstitialAd() }
        #endif
    }

    func loadInterstitialAd() async {
        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        do {
            let request = GADRequest()
            let ad = try await GADInterstitialAd.load(withAdUnitID: adUnitID, request: request)
            self.interstitialAd = ad
            self.isLoaded = true
            self.lastError = nil
            ad.fullScreenContentDelegate = self
        } catch {
            self.isLoaded = false
            self.lastError = error
            await scheduleRetryLoad(after: 5)
        }

        isLoading = false
        #else
        isLoaded = false
        #endif
    }

    func presentInterstitial(from rootViewController: UIViewController) async throws {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitialAd else {
            throw NSError(domain: "AdMob", code: -1, userInfo: [NSLocalizedDescriptionKey: "Interstitial ad is not ready"])
        }

        isLoaded = false
        interstitialAd = nil

        return try await withCheckedThrowingContinuation { continuation in
            ad.present(fromRootViewController: rootViewController)
            continuation.resume(returning: ())
        }
        #else
        throw NSError(domain: "AdMob", code: -1, userInfo: [NSLocalizedDescriptionKey: "GoogleMobileAds is not available"])
        #endif
    }

    private func scheduleRetryLoad(after seconds: TimeInterval) async {
        #if canImport(GoogleMobileAds)
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        await loadInterstitialAd()
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension AdMobInterstitialManager: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { await MainActor.run { self.lastError = error; self.isLoaded = false } }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { await loadInterstitialAd() }
    }
}
#endif
