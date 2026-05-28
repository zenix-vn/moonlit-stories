import SwiftUI

private struct OnboardingPage: Identifiable {
    let id: Int
    let titleKey: String.LocalizationValue
    let subtitleKey: String.LocalizationValue
}

private let onboardingPages = [
    OnboardingPage(id: 0, titleKey: "onboarding.page1.title", subtitleKey: "onboarding.page1.subtitle"),
    OnboardingPage(id: 1, titleKey: "onboarding.page2.title", subtitleKey: "onboarding.page2.subtitle"),
    OnboardingPage(id: 2, titleKey: "onboarding.page3.title", subtitleKey: "onboarding.page3.subtitle"),
]

struct OnboardingView: View {
    @Binding var isFinished: Bool
    @State private var currentPage = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("SplashBg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.42), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.32)
                )

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.65)],
                    startPoint: UnitPoint(x: 0.5, y: 0.50),
                    endPoint: .bottom
                )

                OnboardingPageView(
                    page: onboardingPages[currentPage],
                    pageCount: onboardingPages.count,
                    currentPage: currentPage,
                    primaryActionTitle: actionTitle(for: currentPage),
                    onPrimaryAction: { advance(from: currentPage) }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .id(currentPage)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            goToNextPage()
                        } else if value.translation.width > 40 {
                            goToPreviousPage()
                        }
                    }
            )
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private func actionTitle(for index: Int) -> String {
        index == onboardingPages.indices.last
            ? String(localized: "onboarding.button.start")
            : String(localized: "onboarding.button.next")
    }

    private func advance(from index: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            if index == onboardingPages.indices.last {
                isFinished = true
            } else {
                currentPage = index + 1
            }
        }
    }

    private func goToNextPage() {
        guard currentPage < onboardingPages.count - 1 else { return }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            currentPage += 1
        }
    }

    private func goToPreviousPage() {
        guard currentPage > 0 else { return }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            currentPage -= 1
        }
    }
}

// MARK: - Page layout

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageCount: Int
    let currentPage: Int
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = MoonlitTheme.Spacing.xl
            let contentWidth = min(max(proxy.size.width - horizontalPadding * 2, 0), 360)
            let illW = contentWidth
            let illH = min(360, proxy.size.height * 0.44)

            VStack(spacing: MoonlitTheme.Spacing.xl) {
                Spacer(minLength: proxy.safeAreaInsets.top + MoonlitTheme.Spacing.xxl)

                OnboardingIllustration(
                    pageId: page.id,
                    size: CGSize(width: illW, height: illH)
                )
                .frame(width: illW, height: illH)

                VStack(spacing: MoonlitTheme.Spacing.md) {
                    Text(String(localized: page.titleKey))
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .frame(width: contentWidth, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(localized: page.subtitleKey))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .lineLimit(4)
                        .minimumScaleFactor(0.88)
                        .frame(width: contentWidth, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: contentWidth)

                Spacer(minLength: MoonlitTheme.Spacing.lg)

                VStack(spacing: MoonlitTheme.Spacing.lg) {
                    PageIndicator(count: pageCount, current: currentPage)

                    Button(action: onPrimaryAction) {
                        Text(primaryActionTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(MoonlitTheme.ColorToken.onPrimaryAction)
                            .frame(width: contentWidth, height: 56)
                            .background {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.82, blue: 0.28),
                                                Color(red: 1.0, green: 0.56, blue: 0.18)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            .overlay { Capsule().stroke(Color.white.opacity(0.26), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(primaryActionTitle))
                }
                .frame(width: contentWidth)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + MoonlitTheme.Spacing.lg, MoonlitTheme.Spacing.xxl))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
        }
    }
}

// MARK: - Illustrations

private struct OnboardingIllustration: View {
    let pageId: Int
    let size: CGSize

    var body: some View {
        ZStack {
            switch pageId {
            case 0:  LibraryScene(size: size)
            case 1:  StoriesScene(size: size)
            default: JourneyScene(size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// Page 1 — open book + moon + feather
private struct LibraryScene: View {
    let size: CGSize

    var body: some View {
        ZStack {
            Image("SplashMoon")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.22)
                .shadow(color: Color(red: 1, green: 0.82, blue: 0.30).opacity(0.60), radius: 22)
                .offset(x: -size.width * 0.28, y: -size.height * 0.28)

            Circle()
                .fill(Color(red: 1, green: 0.82, blue: 0.25).opacity(0.22))
                .frame(width: size.width * 0.70)
                .blur(radius: 38)

            Image("SplashBook")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.76)
                .shadow(color: Color(red: 1, green: 0.82, blue: 0.25).opacity(0.45), radius: 34, y: 12)

            // Feather: offset tối đa ~28% để không chạm mép (23%/2 + 28% = 39.5% < 50%)
            Image("SplashFeather")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.23)
                .rotationEffect(.degrees(14))
                .offset(x: size.width * 0.28, y: -size.height * 0.30)
        }
    }
}

// Page 2 — two story cards fanned
// Dùng offset đối xứng ±12% để tâm thị giác nằm chính giữa.
// Card rộng 44% + xoay 10° → cạnh phải = 22%*cos10 + height*sin10 + 12% ≈ 40% < 50% ✓
private struct StoriesScene: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Back card — dragon (right)
            Image("StoryCard1")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.44)
                .rotationEffect(.degrees(10))
                .offset(x: size.width * 0.12, y: -size.height * 0.02)
                .shadow(color: .black.opacity(0.48), radius: 24, y: 12)

            // Front card — couple (left, dominant)
            Image("StoryCard2")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.50)
                .rotationEffect(.degrees(-8))
                .offset(x: -size.width * 0.12, y: size.height * 0.04)
                .shadow(color: .black.opacity(0.55), radius: 28, y: 14)
        }
    }
}

// Page 3 — castle road + lantern
private struct JourneyScene: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Golden path glow
            Circle()
                .fill(Color(red: 1, green: 0.78, blue: 0.22).opacity(0.18))
                .frame(width: size.width * 0.65)
                .blur(radius: 40)
                .offset(y: size.height * 0.08)

            Image("StoryRoad")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.80)
                .shadow(color: Color(red: 1, green: 0.78, blue: 0.22).opacity(0.40), radius: 30, y: 10)

            // Lantern: -32% offset, 18% width → cạnh trái = -32% - 9% = -41% > -50% ✓
            Image("SplashLantern")
                .resizable().scaledToFit()
                .frame(width: size.width * 0.18)
                .offset(x: -size.width * 0.32, y: size.height * 0.12)
                .shadow(color: Color(red: 1, green: 0.70, blue: 0.22).opacity(0.55), radius: 20)
        }
    }
}

// MARK: - Shared UI

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: MoonlitTheme.Spacing.sm) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? MoonlitTheme.ColorToken.gold : Color.white.opacity(0.22))
                    .frame(width: index == current ? 26 : 8, height: 8)
                    .animation(.spring(response: 0.32, dampingFraction: 0.78), value: current)
            }
        }
        .accessibilityHidden(true)
    }
}

// Shared shape — also used by SplashBackground in SplashView.swift
struct SparkleStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: c.x, y: rect.minY))
        path.addLine(to: CGPoint(x: c.x + rect.width * 0.13, y: c.y - rect.height * 0.13))
        path.addLine(to: CGPoint(x: rect.maxX, y: c.y))
        path.addLine(to: CGPoint(x: c.x + rect.width * 0.13, y: c.y + rect.height * 0.13))
        path.addLine(to: CGPoint(x: c.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: c.x - rect.width * 0.13, y: c.y + rect.height * 0.13))
        path.addLine(to: CGPoint(x: rect.minX, y: c.y))
        path.addLine(to: CGPoint(x: c.x - rect.width * 0.13, y: c.y - rect.height * 0.13))
        path.closeSubpath()
        return path
    }
}

#Preview {
    OnboardingView(isFinished: .constant(false))
}
