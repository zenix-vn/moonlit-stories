import SwiftUI

struct RewardedAdSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rewardedManager = AdMobRewardedManager.shared
    @State private var isPresenting = false
    @State private var errorMessage: String? = nil
    @State private var didEarnReward = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Watch an ad to earn 50 coins")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)

            Text("Getting coins from rewarded ads helps you unlock the next episodes without spending real money.")
                .font(.system(size: 13))
                .foregroundStyle(Color.mlSubtext)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)

            if rewardedManager.isLoading {
                Text("Loading ad, please wait...")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mlSubtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mlPink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button(action: {
                Task {
                    await presentRewardedAd()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "play.circle.fill")
                    Text(rewardedManager.isLoaded ? "Watch Ad" : (rewardedManager.isLoading ? "Loading Ad..." : "Retrying..."))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(rewardedManager.isLoaded ? Color.mlPurple : Color.mlMuted)
                )
            }
            .disabled(!rewardedManager.isLoaded || isPresenting)
            .padding(.horizontal, 20)

            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.mlSubtext)
        }
        .padding(24)
        .background(Color.mlBg)
        .cornerRadius(24)
        .padding(12)
        .task {
            await rewardedManager.loadRewardedAd()
        }
        .onChange(of: rewardedManager.isLoaded) { loaded in
            if loaded {
                errorMessage = nil
            }
        }
    }

    private func presentRewardedAd() async {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
                errorMessage = "Unable to show reward ad."
                return
        }

        isPresenting = true
        do {
            #if canImport(GoogleMobileAds)
            let reward = try await AdMobRewardedManager.shared.presentRewardedAd(from: rootVC)
            try await NetworkService.shared.fetchMe()
            await MainActor.run {
                errorMessage = "You earned \(Int(truncating: reward.amount)) coins!"
                self.isPresenting = false
                self.didEarnReward = true
            }
            #else
            throw NSError(domain: "AdMob", code: -1, userInfo: [NSLocalizedDescriptionKey: "AdMob unavailable"])
            #endif
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isPresenting = false
            }
        }
    }
}
