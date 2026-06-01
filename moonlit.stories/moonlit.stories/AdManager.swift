import SwiftUI
import UIKit

// MARK: - Ad Configuration
// ─────────────────────────────────────────────────────────────────────────────
// TO ENABLE REAL ADS (Google AdMob):
//
//  1. Add SDK via Swift Package Manager in Xcode:
//     File → Add Package Dependencies
//     URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
//     Package: "GoogleMobileAds"
//
//  2. Import the module — uncomment all lines marked with:
//       // ADMOB:
//
//  3. In AppDelegate / @main App init, add:
//       // ADMOB: GADMobileAds.sharedInstance().start(completionHandler: nil)
//
//  4. Replace the IDs below with your real AdMob IDs from console.admob.google.com
//
//  5. Set isEnabled = true
// ─────────────────────────────────────────────────────────────────────────────

// ADMOB: import GoogleMobileAds

enum AdConfig {
    static let isEnabled: Bool = false

    // Google-provided test IDs — safe to use while integrating the SDK.
    // Replace with real IDs before App Store release.
    static let appID          = "ca-app-pub-3940256099942544~1458002511"
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    // Production IDs (uncomment and fill in when going live):
    // static let appID          = "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"
    // static let rewardedUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
}

// MARK: - AdManager

@MainActor
@Observable
final class AdManager {
    static let shared = AdManager()

    // Dev-mode overlay state
    var isShowingDevAd = false
    private var pendingReward: (() async -> Void)?
    private var pendingFailure: ((String) -> Void)?

    // ADMOB: private var rewardedAd: GADRewardedAd?
    private(set) var isAdLoaded = false

    private init() {
        if AdConfig.isEnabled {
            loadAd()
        }
    }

    // Pre-load so the ad is ready when the user taps.
    func loadAd() {
        guard AdConfig.isEnabled else { return }

        // ADMOB:
        // GADRewardedAd.load(withAdUnitID: AdConfig.rewardedUnitID, request: GADRequest()) { [weak self] ad, error in
        //     DispatchQueue.main.async {
        //         if let error {
        //             print("[AdManager] load failed: \(error.localizedDescription)")
        //             self?.isAdLoaded = false
        //             return
        //         }
        //         self?.rewardedAd = ad
        //         self?.rewardedAd?.fullScreenContentDelegate = self
        //         self?.isAdLoaded = true
        //     }
        // }
    }

    // Call from a button action. Handles both dev-mode and real-ad flows.
    func requestAd(
        onReward: @escaping () async -> Void,
        onFail: @escaping (String) -> Void
    ) {
        if !AdConfig.isEnabled {
            pendingReward = onReward
            pendingFailure = onFail
            isShowingDevAd = true
            return
        }

        // ADMOB:
        // guard let ad = rewardedAd else {
        //     onFail("Ad not ready yet, please try again.")
        //     loadAd()
        //     return
        // }
        // guard let rootVC = UIApplication.shared.ml_topViewController() else {
        //     onFail("Cannot present ad.")
        //     return
        // }
        // isAdLoaded = false
        // ad.present(fromRootViewController: rootVC) {
        //     Task { await onReward() }
        // }
        // rewardedAd = nil
        // loadAd()   // pre-load next ad
    }

    // Called by DevAdView when the countdown finishes and user claims reward.
    func completeDevAd() {
        isShowingDevAd = false
        let reward = pendingReward
        pendingReward = nil
        pendingFailure = nil
        if let reward {
            Task { await reward() }
        }
    }

    // Called by DevAdView when user dismisses without finishing.
    func cancelDevAd() {
        isShowingDevAd = false
        let fail = pendingFailure
        pendingReward = nil
        pendingFailure = nil
        fail?("Ad was skipped.")
    }
}

// ADMOB: extension AdManager: GADFullScreenContentDelegate {
//     func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
//         isAdLoaded = false
//         pendingFailure?(error.localizedDescription)
//         pendingReward = nil; pendingFailure = nil
//         loadAd()
//     }
//     func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
//         loadAd()
//     }
// }

// MARK: - UIApplication helper

extension UIApplication {
    func ml_topViewController() -> UIViewController? {
        let scene = connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        var vc = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

// MARK: - Dev Ad Simulation View

struct DevAdView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var secondsLeft: Int = 15
    @State private var rewardReady = false
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                adContent
                    .frame(maxHeight: .infinity)
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startCountdown() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: Top bar
    private var topBar: some View {
        HStack {
            Text("AD")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.black)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.75)))

            Spacer()

            if rewardReady {
                Button(action: { AdManager.shared.cancelDevAd() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.10)).frame(width: 32, height: 32)
                    Text("\(secondsLeft)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Ad placeholder content
    private var adContent: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.13), Color(white: 0.09)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )

                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.mlPurple.opacity(0.8), Color.mlPink.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 6) {
                        Text("Sponsored Content")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .tracking(1.2)
                            .textCase(.uppercase)

                        Text("Your ad will appear here")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    Text("TEST MODE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.mlGold)
                        .tracking(1.5)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.mlGold.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Color.mlGold.opacity(0.35), lineWidth: 1))
                }
                .padding(32)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: Bottom bar
    private var bottomBar: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.mlPurple, Color.mlPink],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(15 - secondsLeft) / 15.0,
                            height: 3
                        )
                        .animation(.linear(duration: 1), value: secondsLeft)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)

            if rewardReady {
                Button(action: { AdManager.shared.completeDevAd() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 15))
                        Text("Claim Reward")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.35, green: 0.9, blue: 0.55), Color(red: 0.25, green: 0.75, blue: 0.45)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Watch to unlock this episode for 24 hours")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 36)
        .animation(.spring(duration: 0.4), value: rewardReady)
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                timer?.invalidate()
                rewardReady = true
            }
        }
    }
}
