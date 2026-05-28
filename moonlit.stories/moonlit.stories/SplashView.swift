import SwiftUI

// MARK: - Splash Screen
struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var logoOpacity:    Double = 0
    @State private var logoScale:      Double = 0.75
    @State private var titleOpacity:   Double = 0
    @State private var titleOffset:    CGFloat = 28
    @State private var subtitleOpacity: Double = 0
    @State private var dotsOpacity:    Double = 0
    @State private var glowRadius:     CGFloat = 0

    var body: some View {
        ZStack {
            // ── Background ───────────────────────────────────────────────
            SplashBackground()

            // ── Stars ────────────────────────────────────────────────────
            StarField()
                .opacity(logoOpacity)

            VStack(spacing: 0) {
                Spacer()

                // ── Logo (moon + book) ────────────────────────────────────
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                    .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.45),
                            radius: glowRadius, x: 0, y: 0)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)

                Spacer().frame(height: 36)

                // ── Title ─────────────────────────────────────────────────
                VStack(spacing: 4) {
                    Text("Moonlit")
                        .font(.custom("Georgia-BoldItalic", size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.95, blue: 0.55),
                                    Color(red: 0.95, green: 0.78, blue: 0.20),
                                    Color(red: 1.00, green: 0.90, blue: 0.45),
                                ],
                                startPoint: .top,
                                endPoint: .bottom))
                        .shadow(color: Color(red: 1, green: 0.85, blue: 0.3).opacity(0.6),
                                radius: 12, x: 0, y: 0)

                    Text("Stories")
                        .font(.custom("Georgia-BoldItalic", size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.95, blue: 0.55),
                                    Color(red: 0.95, green: 0.78, blue: 0.20),
                                    Color(red: 1.00, green: 0.90, blue: 0.45),
                                ],
                                startPoint: .top,
                                endPoint: .bottom))
                        .shadow(color: Color(red: 1, green: 0.85, blue: 0.3).opacity(0.6),
                                radius: 12, x: 0, y: 0)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)

                Spacer().frame(height: 14)

                // ── Subtitle ──────────────────────────────────────────────
                Text("Stories for the quiet night")
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .tracking(1.2)
                    .opacity(subtitleOpacity)
                    .offset(y: titleOffset)

                Spacer()

                // ── Loading dots ──────────────────────────────────────────
                LoadingDots()
                    .opacity(dotsOpacity)
                    .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        // Logo fades + scales in
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
            logoOpacity = 1
            logoScale   = 1
        }
        // Glow pulses on
        withAnimation(.easeInOut(duration: 1.2).delay(0.4)) {
            glowRadius = 30
        }
        // Title slides up + fades in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.7)) {
            titleOpacity = 1
            titleOffset  = 0
        }
        // Subtitle fades in
        withAnimation(.easeOut(duration: 0.7).delay(1.1)) {
            subtitleOpacity = 1
        }
        // Dots appear
        withAnimation(.easeOut(duration: 0.5).delay(1.5)) {
            dotsOpacity = 1
        }
        // Transition to HomeView
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.6)) {
                isFinished = true
            }
        }
    }
}

// MARK: - Background
private struct SplashBackground: View {
    var body: some View {
        ZStack {
            // Base deep navy
            Color(red: 0.030, green: 0.045, blue: 0.130)
                .ignoresSafeArea()

            // Radial center glow (slightly lighter center)
            RadialGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.25),
                    Color(red: 0.02, green: 0.03, blue: 0.10),
                ],
                center: .center,
                startRadius: 20,
                endRadius: 420)
            .ignoresSafeArea()

            // Purple cloud — left
            Ellipse()
                .fill(Color(red: 0.28, green: 0.12, blue: 0.52).opacity(0.55))
                .frame(width: 260, height: 180)
                .blur(radius: 55)
                .offset(x: -130, y: -80)

            // Purple cloud — right
            Ellipse()
                .fill(Color(red: 0.22, green: 0.08, blue: 0.45).opacity(0.50))
                .frame(width: 220, height: 160)
                .blur(radius: 50)
                .offset(x: 130, y: -40)

            // Bottom vignette
            LinearGradient(
                colors: [Color.clear, Color(red: 0.01, green: 0.02, blue: 0.08).opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Star Field
private struct StarField: View {
    // Fixed star positions (deterministic so no re-randomise on redraw)
    private struct Star {
        let x: CGFloat; let y: CGFloat
        let size: CGFloat; let opacity: Double
    }
    private let stars: [Star] = {
        let positions: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.12, 0.08, 2.0, 0.9), (0.85, 0.06, 1.5, 0.7), (0.65, 0.12, 2.5, 1.0),
            (0.30, 0.15, 1.5, 0.8), (0.90, 0.20, 2.0, 0.9), (0.05, 0.25, 1.2, 0.6),
            (0.75, 0.18, 1.8, 0.8), (0.48, 0.05, 1.5, 0.7), (0.20, 0.30, 1.2, 0.5),
            (0.92, 0.35, 1.5, 0.8), (0.55, 0.22, 2.0, 0.9), (0.38, 0.10, 1.2, 0.6),
            (0.10, 0.45, 1.5, 0.7), (0.80, 0.42, 1.8, 0.8), (0.60, 0.38, 1.2, 0.5),
            (0.25, 0.55, 1.5, 0.6), (0.70, 0.08, 2.2, 0.9), (0.42, 0.28, 1.0, 0.5),
        ]
        return positions.map { Star(x: $0.0, y: $0.1, size: $0.2, opacity: $0.3) }
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(stars.indices, id: \.self) { i in
                let s = stars[i]
                Circle()
                    .fill(Color.white.opacity(s.opacity))
                    .frame(width: s.size, height: s.size)
                    .position(x: s.x * geo.size.width,
                              y: s.y * geo.size.height)
            }
            // Sparkle crosses for a few prominent stars
            SparkleShape()
                .fill(Color(red: 1, green: 0.92, blue: 0.5).opacity(0.9))
                .frame(width: 18, height: 18)
                .position(x: geo.size.width * 0.65, y: geo.size.height * 0.12)
            SparkleShape()
                .fill(Color.white.opacity(0.85))
                .frame(width: 12, height: 12)
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.07)
            SparkleShape()
                .fill(Color(red: 1, green: 0.92, blue: 0.5).opacity(0.75))
                .frame(width: 10, height: 10)
                .position(x: geo.size.width * 0.30, y: geo.size.height * 0.14)
        }
    }
}

// MARK: - Sparkle (4-pointed star) Shape
private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r  = min(rect.width, rect.height) / 2
        let ri = r * 0.18
        var p  = Path()
        let pts = 4
        for i in 0..<pts {
            let outerAngle = CGFloat(i) / CGFloat(pts) * .pi * 2 - .pi / 2
            let innerAngle = outerAngle + .pi / CGFloat(pts)
            let op = CGPoint(x: cx + cos(outerAngle) * r,  y: cy + sin(outerAngle) * r)
            let ip = CGPoint(x: cx + cos(innerAngle) * ri, y: cy + sin(innerAngle) * ri)
            if i == 0 { p.move(to: op) } else { p.addLine(to: op) }
            p.addLine(to: ip)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Loading Dots
private struct LoadingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 1, green: 0.85, blue: 0.3)
                        .opacity(active == i ? 1.0 : 0.30))
                    .frame(width: 7, height: 7)
                    .scaleEffect(active == i ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: active)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { t in
                active = (active + 1) % 3
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SplashView(isFinished: .constant(false))
}
