import SwiftUI
import UserNotifications

// MARK: - Page Model (pages 1 & 2 only — page 3 is custom)
private struct OnboardingPage {
    let image:    String
    let title:    String
    let subtitle: String
    let button:   String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        image:    "Onboarding1",
        title:    "Welcome to\nMoonlit Stories",
        subtitle: "Discover enchanting stories, cozy night reads, and magical worlds made for your quiet moments.",
        button:   "Continue"
    ),
    OnboardingPage(
        image:    "Onboarding2",
        title:    "Discover Your\nNext Favorite Story",
        subtitle: "Browse cozy bedtime tales, magical adventures, and enchanting reads curated for every mood.",
        button:   "Continue"
    ),
]
private let totalPages = 3

// MARK: - Onboarding Container
struct OnboardingView: View {
    @Binding var isFinished: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                // Pages 1 & 2 — generic
                ForEach(pages.indices, id: \.self) { i in
                    OnboardingPageView(
                        page:        pages[i],
                        index:       i,
                        total:       totalPages,
                        currentPage: $currentPage,
                        isFinished:  $isFinished
                    )
                    .tag(i)
                    .ignoresSafeArea()
                }
                // Page 3 — custom layered illustration
                Onboarding3PageView(
                    index:       2,
                    total:       totalPages,
                    currentPage: $currentPage,
                    isFinished:  $isFinished
                )
                .tag(2)
                .ignoresSafeArea()
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Skip
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.5)) { isFinished = true }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.trailing, 24)
                    .padding(.top, 60)
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Generic Page (onboarding 1 & 2)
private struct OnboardingPageView: View {
    let page:        OnboardingPage
    let index:       Int
    let total:       Int
    @Binding var currentPage: Int
    @Binding var isFinished:  Bool

    @State private var titleOpacity:   Double  = 0
    @State private var titleOffset:    CGFloat = 24
    @State private var bodyOpacity:    Double  = 0
    @State private var btnScale:       Double  = 0.88

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(page.image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.030, green: 0.045, blue: 0.130).opacity(0.60),
                    Color(red: 0.020, green: 0.030, blue: 0.100).opacity(0.97),
                ],
                startPoint: .init(x: 0.5, y: 0.30),
                endPoint: .bottom
            )
            .ignoresSafeArea()

            BottomContent(
                title:       page.title,
                subtitle:    page.subtitle,
                buttonLabel: page.button,
                index:       index,
                total:       total,
                titleOpacity:  $titleOpacity,
                titleOffset:   $titleOffset,
                bodyOpacity:   $bodyOpacity,
                btnScale:      $btnScale,
                onButton: {
                    withAnimation(.spring(duration: 0.45)) { currentPage = index + 1 }
                }
            )
        }
        .onAppear { animateIn() }
        .onChange(of: currentPage) { _, _ in
            guard currentPage == index else { return }
            resetAndAnimate()
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.15)) {
            titleOpacity = 1; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.45)) { bodyOpacity = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.55)) { btnScale = 1 }
    }
    private func resetAndAnimate() {
        titleOpacity = 0; titleOffset = 24; bodyOpacity = 0; btnScale = 0.88
        animateIn()
    }
}

// MARK: - Onboarding 3 — Layered Illustration
struct Onboarding3PageView: View {
    let index:       Int
    let total:       Int
    @Binding var currentPage: Int
    @Binding var isFinished:  Bool

    // Entry
    @State private var illustrationOpacity: Double  = 0
    @State private var titleOpacity:        Double  = 0
    @State private var titleOffset:         CGFloat = 24
    @State private var bodyOpacity:         Double  = 0
    @State private var btnScale:            Double  = 0.88

    // Floating animations
    @State private var lanternAngle:  Double  = -4
    @State private var featherOffset: CGFloat = 0
    @State private var card1Offset:   CGFloat = 0
    @State private var card2Offset:   CGFloat = 4
    @State private var moonGlow:      Double  = 0.5

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Layer 1: Background ───────────────────────────────────────
            Image("Ob3Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // ── Layers 2-8: Illustration elements ────────────────────────
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Road + castle (center, connects book to sky)
                    Image("Ob3Road")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.70)
                        .position(x: w * 0.50, y: h * 0.33)

                    // Book (bottom-center of illustration)
                    Image("Ob3Book")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.72)
                        .position(x: w * 0.48, y: h * 0.58)

                    // Moon (upper-left)
                    Image("Ob3Moon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.24)
                        .shadow(color: Color(red: 1, green: 0.8, blue: 0.2).opacity(moonGlow),
                                radius: 28, x: 0, y: 0)
                        .rotationEffect(.degrees(8))
                        .position(x: w * 0.20, y: h * 0.16)

                    // Lantern (left, swinging)
                    Image("Ob3Light")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.17)
                        .rotationEffect(.degrees(lanternAngle), anchor: .top)
                        .shadow(color: Color(red: 1, green: 0.75, blue: 0.1).opacity(0.50),
                                radius: 14, x: 0, y: 4)
                        .position(x: w * 0.14, y: h * 0.43)

                    // Feather + bookmark (lower-left, floating)
                    Image("Ob3Feather")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.22)
                        .rotationEffect(.degrees(-12))
                        .offset(y: featherOffset)
                        .position(x: w * 0.21, y: h * 0.56)

                    // Dragon card (upper-right, tilted)
                    Image("Ob3Img1")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.32)
                        .rotationEffect(.degrees(11))
                        .offset(y: card1Offset)
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 2, y: 4)
                        .position(x: w * 0.80, y: h * 0.26)

                    // Couple card (right, counter-tilt)
                    Image("Ob3Img2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.29)
                        .rotationEffect(.degrees(-9))
                        .offset(y: card2Offset)
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: -2, y: 4)
                        .position(x: w * 0.82, y: h * 0.45)
                }
            }
            .opacity(illustrationOpacity)

            // ── Bottom gradient ───────────────────────────────────────────
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.030, green: 0.045, blue: 0.130).opacity(0.55),
                    Color(red: 0.015, green: 0.025, blue: 0.090).opacity(0.98),
                ],
                startPoint: .init(x: 0.5, y: 0.28),
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Text + button ─────────────────────────────────────────────
            BottomContent(
                title:       "Begin Your\nMoonlit Journey",
                subtitle:    "Save favorites, enjoy peaceful night reads, and step into magical worlds whenever you need a quiet escape.",
                buttonLabel: "Get Started",
                index:       index,
                total:       total,
                titleOpacity:  $titleOpacity,
                titleOffset:   $titleOffset,
                bodyOpacity:   $bodyOpacity,
                btnScale:      $btnScale,
                onButton:      handleGetStarted
            )
        }
        .onAppear {
            animateIn()
            startFloating()
        }
        .onChange(of: currentPage) { _, _ in
            guard currentPage == index else { return }
            resetAndAnimate()
        }
    }

    // MARK: Entry
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { illustrationOpacity = 1 }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.25)) {
            titleOpacity = 1; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.55)) { bodyOpacity = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.65)) { btnScale = 1 }
    }

    private func resetAndAnimate() {
        illustrationOpacity = 0
        titleOpacity = 0; titleOffset = 24; bodyOpacity = 0; btnScale = 0.88
        animateIn()
    }

    // MARK: Floating loops
    private func startFloating() {
        // Lantern swing
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            lanternAngle = 4
        }
        // Feather bob
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.3)) {
            featherOffset = -6
        }
        // Cards float (opposite phases)
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.1)) {
            card1Offset = -5
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.8)) {
            card2Offset = -4
        }
        // Moon glow pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            moonGlow = 0.85
        }
    }

    // MARK: Notification + finish
    private func handleGetStarted() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.55)) { isFinished = true }
                }
            }
    }
}

// MARK: - Shared Bottom Content
private struct BottomContent: View {
    let title:       String
    let subtitle:    String
    let buttonLabel: String
    let index:       Int
    let total:       Int
    @Binding var titleOpacity:  Double
    @Binding var titleOffset:   CGFloat
    @Binding var bodyOpacity:   Double
    @Binding var btnScale:      Double
    let onButton: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(title)
                .font(.custom("Georgia-BoldItalic", size: 38))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.96, blue: 0.58),
                            Color(red: 0.95, green: 0.78, blue: 0.20),
                            Color(red: 1.00, green: 0.90, blue: 0.45),
                        ],
                        startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 1, green: 0.85, blue: 0.3).opacity(0.5),
                        radius: 14, x: 0, y: 0)
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                .padding(.horizontal, 28)

            // Sparkle divider
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                    .frame(width: 40, height: 1)
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.8))
                Rectangle()
                    .fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                    .frame(width: 40, height: 1)
            }
            .opacity(titleOpacity)
            .padding(.top, 14)

            // Subtitle
            Text(subtitle)
                .font(.system(size: 15, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.72))
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .padding(.top, 10)
                .opacity(bodyOpacity)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i == index
                              ? Color(red: 1, green: 0.85, blue: 0.3)
                              : Color.white.opacity(0.28))
                        .frame(width: i == index ? 22 : 8, height: 8)
                }
            }
            .padding(.top, 24)
            .opacity(bodyOpacity)

            // CTA button
            Button(action: onButton) {
                Text(buttonLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.06, blue: 0.01))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 50)
                            .fill(LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.90, blue: 0.38),
                                    Color(red: 0.95, green: 0.68, blue: 0.10),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color(red: 1, green: 0.78, blue: 0.2).opacity(0.45),
                                    radius: 16, x: 0, y: 6)
                    )
            }
            .scaleEffect(btnScale)
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 52)
            .opacity(bodyOpacity)
        }
    }
}

// MARK: - Preview
#Preview("Page 3") {
    Onboarding3PageView(
        index: 2, total: 3,
        currentPage: .constant(2),
        isFinished: .constant(false)
    )
    .ignoresSafeArea()
}

#Preview("Full flow") {
    OnboardingView(isFinished: .constant(false))
}
