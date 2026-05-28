import SwiftUI

struct ContentView: View {
    @State  private var splashDone      = false
    @State  private var onboardingDone  = false
    @AppStorage("onboardingShownOnce") private var onboardingShownOnce = false

    var body: some View {
        ZStack {
            if !splashDone {
                SplashView(isFinished: $splashDone)
                    .transition(.opacity)
                    .zIndex(3)

            } else if !onboardingShownOnce && !onboardingDone {
                OnboardingView(isFinished: $onboardingDone)
                    .transition(.opacity)
                    .zIndex(2)
                    .onAppear { onboardingShownOnce = true }

            } else {
                HomeView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.55), value: splashDone)
        .animation(.easeInOut(duration: 0.55), value: onboardingDone)
    }
}

#Preview {
    ContentView()
}
