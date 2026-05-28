import SwiftUI

struct ContentView: View {
    @State  private var splashDone      = false
    @State  private var onboardingDone  = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some View {
        ZStack {
            if !splashDone {
                SplashView(isFinished: $splashDone)
                    .transition(.opacity)
                    .zIndex(3)

            } else if !onboardingCompleted && !onboardingDone {
                OnboardingView(isFinished: $onboardingDone)
                    .transition(.opacity)
                    .zIndex(2)
                    .onChange(of: onboardingDone) { _, finished in
                        if finished { onboardingCompleted = true }
                    }

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
