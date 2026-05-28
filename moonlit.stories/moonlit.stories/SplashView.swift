import SwiftUI

struct SplashView: View {
    @Binding var isFinished: Bool

    // ── Entry animation states ────────────────────────────────────────────
    @State private var cloudLeftX:    CGFloat = -0.30
    @State private var cloudRightX:   CGFloat =  1.30
    @State private var cloudsOpacity: Double  = 0
    @State private var starsOpacity:  Double  = 0
    @State private var moonOpacity:   Double  = 0
    @State private var moonY:         CGFloat = -40
    @State private var bookScale:     Double  = 0.72
    @State private var bookOpacity:   Double  = 0
    @State private var textOpacity:   Double  = 0
    @State private var textY:         CGFloat = 22
    @State private var dotsOpacity:   Double  = 0

    // ── Loop animation states ─────────────────────────────────────────────
    @State private var moonGlow:      Double  = 0.40
    @State private var bookFloat:     CGFloat = 0
    @State private var starsTwinkle:  Double  = 0.85

    var body: some View {
        ZStack {
            // ── Layer 1: Background ───────────────────────────────────────
            Image("SplashBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // ── Layer 2: Stars (full-screen sparkle overlay) ──────
                    Image("SplashStars")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .opacity(starsTwinkle)
                        .ignoresSafeArea()
                        .opacity(starsOpacity)

                    // ── Layer 3: Cloud LEFT ───────────────────────────────
                    Image("SplashCloud")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.62)
                        .opacity(cloudsOpacity)
                        .position(x: w * cloudLeftX, y: h * 0.72)

                    // ── Layer 4: Cloud RIGHT (horizontally mirrored) ──────
                    Image("SplashCloud")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.62)
                        .scaleEffect(x: -1, y: 1)
                        .opacity(cloudsOpacity)
                        .position(x: w * cloudRightX, y: h * 0.66)

                    // ── Layer 5: Moon ─────────────────────────────────────
                    Image("Ob3Moon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.48)
                        .shadow(
                            color: Color(red: 1.0, green: 0.78, blue: 0.15).opacity(moonGlow),
                            radius: 40, x: 0, y: 0)
                        .opacity(moonOpacity)
                        .offset(y: moonY)
                        .position(x: w * 0.50, y: h * 0.33)

                    // ── Layer 6: Book ─────────────────────────────────────
                    Image("SplashBook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.78)
                        .shadow(
                            color: Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.45),
                            radius: 28, x: 0, y: 6)
                        .scaleEffect(bookScale)
                        .opacity(bookOpacity)
                        .offset(y: bookFloat)
                        .position(x: w * 0.50, y: h * 0.565)

                    // ── Layer 7: Text logo ────────────────────────────────
                    Image("SplashText")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.82)
                        .opacity(textOpacity)
                        .offset(y: textY)
                        .position(x: w * 0.50, y: h * 0.795)
                }
            }

            // ── Loading dots (bottom) ─────────────────────────────────────
            VStack {
                Spacer()
                LoadingDots()
                    .opacity(dotsOpacity)
                    .padding(.bottom, 58)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            runEntryAnimation()
        }
    }

    // MARK: - Entry sequence
    private func runEntryAnimation() {
        // Clouds slide in from sides
        withAnimation(.easeOut(duration: 0.85).delay(0.1)) {
            cloudLeftX    = 0.13
            cloudRightX   = 0.87
            cloudsOpacity = 1
        }
        // Stars shimmer in
        withAnimation(.easeIn(duration: 0.7).delay(0.25)) {
            starsOpacity = 1
        }
        // Moon descends
        withAnimation(.spring(response: 0.8, dampingFraction: 0.72).delay(0.45)) {
            moonOpacity = 1
            moonY       = 0
        }
        // Book scales up
        withAnimation(.spring(response: 0.75, dampingFraction: 0.70).delay(0.75)) {
            bookScale   = 1.0
            bookOpacity = 1
        }
        // Text fades + rises
        withAnimation(.easeOut(duration: 0.7).delay(1.10)) {
            textOpacity = 1
            textY       = 0
        }
        // Loading dots
        withAnimation(.easeIn(duration: 0.5).delay(1.55)) {
            dotsOpacity = 1
        }

        // Start looping animations after entry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startLoopAnimations()
        }

        // Transition to next screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 0.65)) {
                isFinished = true
            }
        }
    }

    // MARK: - Looping animations
    private func startLoopAnimations() {
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            moonGlow = 0.85
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.4)) {
            bookFloat = -7
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.2)) {
            starsTwinkle = 1.0
        }
    }
}

// MARK: - Loading Dots
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

// MARK: - Preview
#Preview {
    SplashView(isFinished: .constant(false))
}
