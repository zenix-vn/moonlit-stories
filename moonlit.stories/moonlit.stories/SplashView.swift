import SwiftUI

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var bgOpacity: Double = 0

    @State private var moonOffset: CGFloat = -30
    @State private var moonOpacity: Double = 0

    @State private var bookScale: CGFloat = 0.80
    @State private var bookOpacity: Double = 0
    @State private var bookGlow: Double = 0

    @State private var featherOffset: CGFloat = 18
    @State private var featherOpacity: Double = 0

    @State private var titleOffset: CGFloat = 24
    @State private var titleOpacity: Double = 0

    @State private var dotsOpacity: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // ── Background ──────────────────────────────────────
                Image("SplashBg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(bgOpacity)

                // Top fade — deepen the sky at the very top
                LinearGradient(
                    colors: [Color.black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.38)
                )

                // Bottom fade — let text sit cleanly
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.62)],
                    startPoint: UnitPoint(x: 0.5, y: 0.54),
                    endPoint: .bottom
                )

                // ── Moon ────────────────────────────────────────────
                Image("SplashMoon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130)
                    .offset(x: proxy.size.width * 0.22, y: moonOffset)
                    .opacity(moonOpacity)
                    .shadow(color: Color(red: 1, green: 0.82, blue: 0.3).opacity(0.55), radius: 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, proxy.size.height * 0.10)

                // ── Content ─────────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // Book glow halo
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.35 * bookGlow),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 160
                                )
                            )
                            .frame(width: 320, height: 320)
                            .blur(radius: 36)

                        Image("SplashBook")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300)
                            .scaleEffect(bookScale)
                            .opacity(bookOpacity)
                    }

                    Spacer().frame(height: 36)

                    // Feather accent + title row
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: MoonlitTheme.Spacing.sm) {
                            Text(String(localized: "splash.title"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)

                            Text(String(localized: "splash.subtitle"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)

                        Image("SplashFeather")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72)
                            .rotationEffect(.degrees(-18))
                            .offset(x: 28, y: featherOffset - 52)
                            .opacity(featherOpacity)
                    }
                    .padding(.horizontal, MoonlitTheme.Spacing.xl)

                    Spacer()

                    LoadingDots()
                        .opacity(dotsOpacity)
                        .padding(.bottom, MoonlitTheme.Spacing.xxl)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        // Background fades in immediately
        withAnimation(.easeOut(duration: 0.7)) {
            bgOpacity = 1
        }
        // Moon drifts down
        withAnimation(.easeOut(duration: 1.0).delay(0.18)) {
            moonOffset = 0
            moonOpacity = 1
        }
        // Book scales up with golden glow
        withAnimation(.spring(response: 0.72, dampingFraction: 0.74).delay(0.32)) {
            bookScale = 1
            bookOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.42)) {
            bookGlow = 1
        }
        // Feather floats in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.55)) {
            featherOffset = 0
            featherOpacity = 1
        }
        // Title rises
        withAnimation(.spring(response: 0.62, dampingFraction: 0.78).delay(0.52)) {
            titleOffset = 0
            titleOpacity = 1
        }
        // Dots
        withAnimation(.easeIn(duration: 0.3).delay(0.95)) {
            dotsOpacity = 1
        }

        Task {
            let startTime = Date()
            
            // Perform guest login authentication in the background
            do {
                _ = try await NetworkService.shared.authenticateGuest()
                #if DEBUG
                print("Guest authentication successful!")
                #endif
            } catch {
                #if DEBUG
                print("Guest authentication failed: \(error)")
                #endif
                // Do not block app transition on authentication error;
                // HomeView's network retrieval will handle error and retry states.
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, 2.8 - elapsed)
            
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    isFinished = true
                }
            }
        }
    }
}

private struct LoadingDots: View {
    @State private var active = 0
    @State private var timer: Timer? = nil

    var body: some View {
        HStack(spacing: MoonlitTheme.Spacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(MoonlitTheme.ColorToken.gold.opacity(active == index ? 1.0 : 0.28))
                    .frame(width: 7, height: 7)
                    .scaleEffect(active == index ? 1.35 : 1.0)
                    .animation(.easeInOut(duration: 0.35), value: active)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.42, repeats: true) { _ in
                active = (active + 1) % 3
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
