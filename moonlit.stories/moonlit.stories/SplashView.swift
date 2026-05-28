import SwiftUI

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var imageOpacity: Double  = 0
    @State private var imageScale:   Double  = 1.04
    @State private var dotsOpacity:  Double  = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("SplashImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(imageOpacity)
                .scaleEffect(imageScale)

            VStack {
                Spacer()
                LoadingDots()
                    .opacity(dotsOpacity)
                    .padding(.bottom, 58)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.easeOut(duration: 0.9)) {
            imageOpacity = 1
        }
        withAnimation(.easeOut(duration: 3.5)) {
            imageScale = 1.0
        }
        withAnimation(.easeIn(duration: 0.5).delay(0.8)) {
            dotsOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 0.6)) {
                isFinished = true
            }
        }
    }
}

private struct LoadingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 1, green: 0.85, blue: 0.30)
                        .opacity(active == i ? 1.0 : 0.28))
                    .frame(width: 7, height: 7)
                    .scaleEffect(active == i ? 1.35 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: active)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
                active = (active + 1) % 3
            }
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
