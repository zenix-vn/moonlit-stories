import SwiftUI

struct AdMobBannerView: View {
    let adUnitID: String

    var body: some View {
        Group {
            #if canImport(GoogleMobileAds)
            AdMobBannerRepresentable(adUnitID: adUnitID)
                .frame(height: 50)
            #else
            Color.clear.frame(height: 50)
            #endif
        }
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

private struct AdMobBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GADBannerView {
        let width = UIScreen.main.bounds.width
        let adaptiveSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        let bannerView = GADBannerView(adSize: adaptiveSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = findRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.load(GADRequest())
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        uiView.adUnitID = adUnitID
        uiView.rootViewController = findRootViewController()
    }

    private func findRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                return root
            }
        }
        return UIApplication.shared.windows.first?.rootViewController
    }

    class Coordinator: NSObject, GADBannerViewDelegate { }
}
#endif
