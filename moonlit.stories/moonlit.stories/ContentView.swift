import SwiftUI

struct ContentView: View {
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true

    var body: some View {
        HomeView()
            .task {
                AnalyticsService.shared.track(.appOpen)
                if pushNotificationsEnabled {
                    PushNotifications.requestAuthorizationAndRegister()
                }
            }
    }
}

#Preview {
    ContentView()
}
