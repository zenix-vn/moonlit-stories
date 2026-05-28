import SwiftUI
import UserNotifications

// MARK: - Page Model
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
    OnboardingPage(
        image:    "Onboarding3",
        title:    "Begin Your\nMoonlit Journey",
        subtitle: "Save favorites, enjoy peaceful night reads, and step into magical worlds whenever you need a quiet escape.",
        button:   "Get Started"
    ),
]

// MARK: - Onboarding Container
struct OnboardingView: View {
    @Binding var isFinished: Bool
    @State private var currentPage = 0
    @State private var dragOffset:  CGFloat = 0
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            // ── Swipeable pages ──────────────────────────────────────────
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { i in
                    OnboardingPageView(
                        page:        pages[i],
                        index:       i,
                        total:       pages.count,
                        currentPage: $currentPage,
                        isFinished:  $isFinished
                    )
                    .tag(i)
                    .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // ── Skip ─────────────────────────────────────────────────────
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isFinished = true
                        }
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

// MARK: - Single Page
private struct OnboardingPageView: View {
    let page:        OnboardingPage
    let index:       Int
    let total:       Int
    @Binding var currentPage: Int
    @Binding var isFinished:  Bool

    @State private var titleOpacity:  Double  = 0
    @State private var titleOffset:   CGFloat = 24
    @State private var bodyOpacity:   Double  = 0
    @State private var btnScale:      Double  = 0.88

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Full-screen illustration ──────────────────────────────────
            Image(page.image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // ── Bottom gradient overlay for readability ───────────────────
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.030, green: 0.045, blue: 0.130).opacity(0.60),
                    Color(red: 0.020, green: 0.030, blue: 0.100).opacity(0.97),
                ],
                startPoint: .init(x: 0.5, y: 0.30),
                endPoint:   .bottom
            )
            .ignoresSafeArea()

            // ── Bottom content ─────────────────────────────────────────────
            VStack(spacing: 0) {
                // Title
                Text(page.title)
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
                    Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                        .frame(width: 40, height: 1)
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.8))
                    Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                        .frame(width: 40, height: 1)
                }
                .opacity(titleOpacity)
                .padding(.top, 16)

                // Subtitle
                Text(page.subtitle)
                    .font(.system(size: 15, weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .padding(.top, 12)
                    .opacity(bodyOpacity)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(i == index
                                  ? Color(red: 1, green: 0.85, blue: 0.3)
                                  : Color.white.opacity(0.28))
                            .frame(width: i == index ? 22 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 28)
                .opacity(bodyOpacity)

                // Action button
                Button(action: handleButton) {
                    Text(page.button)
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
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                                .shadow(color: Color(red: 1, green: 0.78, blue: 0.2).opacity(0.45),
                                        radius: 16, x: 0, y: 6)
                        )
                }
                .scaleEffect(btnScale)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 52)
                .opacity(bodyOpacity)
            }
        }
        .onAppear { animateIn() }
        .onChange(of: currentPage) { _, _ in
            guard currentPage == index else { return }
            resetAndAnimate()
        }
    }

    // MARK: Button action
    private func handleButton() {
        if index < total - 1 {
            withAnimation(.spring(duration: 0.45)) { currentPage = index + 1 }
        } else {
            // Last page — request notification permission then finish
            requestNotificationPermission {
                withAnimation(.easeInOut(duration: 0.55)) { isFinished = true }
            }
        }
    }

    // MARK: Notification permission
    private func requestNotificationPermission(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: Animations
    private func animateIn() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.15)) {
            titleOpacity = 1; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.45)) {
            bodyOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.55)) {
            btnScale = 1.0
        }
    }

    private func resetAndAnimate() {
        titleOpacity = 0; titleOffset = 24
        bodyOpacity  = 0; btnScale    = 0.88
        animateIn()
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(isFinished: .constant(false))
}
