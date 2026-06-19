import SwiftUI
import AppTrackingTransparency

struct ContentView: View {
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true

    var body: some View {
        HomeView()
            .task {
                AnalyticsService.shared.track(.appOpen)
                
                // Request ATT tracking permission for AdMob/analytics
                let status = await ATTManager.shared.requestTrackingPermission()
                #if DEBUG
                print("[ATT] Status: \(status.rawValue)")
                #endif
                
                // If GoogleMobileAds is integrated, initialize it after ATT check.
                #if canImport(GoogleMobileAds)
                // import GoogleMobileAds
                // GADMobileAds.sharedInstance().start(completionHandler: nil)
                #endif

                if pushNotificationsEnabled {
                    PushNotifications.requestAuthorizationAndRegister()
                }
            }
    }
}

#Preview {
    ContentView()
}
