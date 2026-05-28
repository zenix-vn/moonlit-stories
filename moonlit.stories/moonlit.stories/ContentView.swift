import SwiftUI

struct ContentView: View {
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if splashFinished {
                HomeView()
                    .transition(.opacity)
            } else {
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: splashFinished)
    }
}

#Preview {
    ContentView()
}
