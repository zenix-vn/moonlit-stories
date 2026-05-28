import SwiftUI
import UserNotifications

private let totalPages = 3

// MARK: - Root Container
struct OnboardingView: View {
    @Binding var isFinished: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                // Page 1 – layered assets
                Onboarding1PageView(
                    index: 0, total: totalPages,
                    currentPage: $currentPage,
                    isFinished: $isFinished
                )
                .tag(0).ignoresSafeArea()

                // Page 2 – flat design image (unchanged)
                Onboarding2PageView(
                    index: 1, total: totalPages,
                    currentPage: $currentPage,
                    isFinished: $isFinished
                )
                .tag(1).ignoresSafeArea()

                // Page 3 – layered assets
                Onboarding3PageView(
                    index: 2, total: totalPages,
                    currentPage: $currentPage,
                    isFinished: $isFinished
                )
                .tag(2).ignoresSafeArea()
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

// MARK: - Onboarding 1 — Layered illustration
struct Onboarding1PageView: View {
    let index:       Int
    let total:       Int
    @Binding var currentPage: Int
    @Binding var isFinished:  Bool

    // Entry states
    @State private var cloudLeftX:     CGFloat = -0.28
    @State private var cloudRightX:    CGFloat =  1.28
    @State private var cloudsOpacity:  Double  = 0
    @State private var starsOpacity:   Double  = 0
    @State private var moonOpacity:    Double  = 0
    @State private var moonY:          CGFloat = -36
    @State private var bookScale:      Double  = 0.74
    @State private var bookOpacity:    Double  = 0
    @State private var textOpacity:    Double  = 0
    @State private var textY:          CGFloat = 22
    @State private var subtitleOpacity: Double = 0
    @State private var bottomOpacity:  Double  = 0
    @State private var btnScale:       Double  = 0.88

    // Loop states
    @State private var moonGlow:      Double  = 0.45
    @State private var bookFloat:     CGFloat = 0
    @State private var starsTwinkle:  Double  = 0.80

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Background ────────────────────────────────────────────────
            Image("Ob3Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Stars sparkle overlay
                    Image("SplashStars")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .opacity(starsOpacity * starsTwinkle)

                    // Cloud LEFT
                    Image("SplashCloud")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.65)
                        .opacity(cloudsOpacity)
                        .position(x: w * cloudLeftX, y: h * 0.66)

                    // Cloud RIGHT (mirrored)
                    Image("SplashCloud")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.65)
                        .scaleEffect(x: -1, y: 1)
                        .opacity(cloudsOpacity)
                        .position(x: w * cloudRightX, y: h * 0.60)

                    // Moon (upper center, large)
                    Image("Ob3Moon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.58)
                        .shadow(
                            color: Color(red: 1.0, green: 0.80, blue: 0.18).opacity(moonGlow),
                            radius: 44, x: 0, y: 0)
                        .opacity(moonOpacity)
                        .offset(y: moonY)
                        .position(x: w * 0.50, y: h * 0.28)

                    // Book (center, below moon — overlaps slightly)
                    Image("SplashBook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.78)
                        .shadow(
                            color: Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.40),
                            radius: 24, x: 0, y: 8)
                        .scaleEffect(bookScale)
                        .opacity(bookOpacity)
                        .offset(y: bookFloat)
                        .position(x: w * 0.50, y: h * 0.54)
                }
            }
            .clipped()

            // ── Bottom gradient ───────────────────────────────────────────
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.030, green: 0.045, blue: 0.130).opacity(0.55),
                    Color(red: 0.015, green: 0.025, blue: 0.090).opacity(0.98),
                ],
                startPoint: .init(x: 0.5, y: 0.25),
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Bottom content ────────────────────────────────────────────
            VStack(spacing: 0) {
                // Title image: "Welcome to Moonlit Stories" + divider
                Image("Ob1Text")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 32)
                    .opacity(textOpacity)
                    .offset(y: textY)

                // Subtitle
                Text("Discover enchanting stories, cozy night reads, and magical worlds made for your quiet moments.")
                    .font(.system(size: 15, weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.70))
                    .lineSpacing(4)
                    .padding(.horizontal, 38)
                    .padding(.top, 14)
                    .opacity(subtitleOpacity)

                // Page dots
                PageDots(current: index, total: total)
                    .padding(.top, 24)
                    .opacity(bottomOpacity)

                // Continue button image
                Button(action: {
                    withAnimation(.spring(duration: 0.45)) { currentPage = 1 }
                }) {
                    Image("BtnContinue")
                        .resizable()
                        .scaledToFit()
                        .shadow(
                            color: Color(red: 1, green: 0.78, blue: 0.2).opacity(0.40),
                            radius: 16, x: 0, y: 6)
                }
                .padding(.horizontal, 28)
                .scaleEffect(btnScale)
                .padding(.top, 22)
                .padding(.bottom, 52)
                .opacity(bottomOpacity)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { animateIn() }
        .onChange(of: currentPage) { _, _ in
            guard currentPage == index else { return }
            resetAndAnimate()
        }
    }

    // MARK: Animations
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.80).delay(0.10)) {
            cloudLeftX = 0.10; cloudRightX = 0.90; cloudsOpacity = 1
        }
        withAnimation(.easeIn(duration: 0.65).delay(0.22)) { starsOpacity = 1 }
        withAnimation(.spring(response: 0.80, dampingFraction: 0.72).delay(0.42)) {
            moonOpacity = 1; moonY = 0
        }
        withAnimation(.spring(response: 0.75, dampingFraction: 0.70).delay(0.68)) {
            bookScale = 1.0; bookOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.65).delay(1.00)) {
            textOpacity = 1; textY = 0
        }
        withAnimation(.easeOut(duration: 0.55).delay(1.25)) { subtitleOpacity = 1 }
        withAnimation(.easeOut(duration: 0.50).delay(1.45)) { bottomOpacity = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.50)) { btnScale = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { startLooping() }
    }

    private func resetAndAnimate() {
        cloudLeftX = -0.28; cloudRightX = 1.28; cloudsOpacity = 0
        starsOpacity = 0; moonOpacity = 0; moonY = -36
        bookScale = 0.74; bookOpacity = 0
        textOpacity = 0; textY = 22; subtitleOpacity = 0
        bottomOpacity = 0; btnScale = 0.88
        animateIn()
    }

    private func startLooping() {
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            moonGlow = 0.88
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.5)) {
            bookFloat = -7
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(0.3)) {
            starsTwinkle = 1.0
        }
    }
}

// MARK: - Onboarding 2 — Layered illustration
struct Onboarding2PageView: View {
    let index:       Int
    let total:       Int
    @Binding var currentPage: Int
    @Binding var isFinished:  Bool

    // ── Entry states ──────────────────────────────────────────────────────
    @State private var moonOpacity:  Double  = 0
    @State private var moonY:        CGFloat = -28
    @State private var bookScale:    Double  = 0.72
    @State private var bookOpacity:  Double  = 0
    @State private var swirlOpacity: Double  = 0
    @State private var swirlScale:   Double  = 0.55

    // Cards: opacity + fly-in Y offset (starts at book, flies to final position)
    @State private var c1Op: Double = 0; @State private var c1Y: CGFloat = 70
    @State private var c2Op: Double = 0; @State private var c2Y: CGFloat = 70
    @State private var c3Op: Double = 0; @State private var c3Y: CGFloat = 70
    @State private var c4Op: Double = 0; @State private var c4Y: CGFloat = 70
    @State private var c5Op: Double = 0; @State private var c5Y: CGFloat = 70

    @State private var titleOpacity: Double  = 0
    @State private var titleOffset:  CGFloat = 24
    @State private var bodyOpacity:  Double  = 0
    @State private var btnScale:     Double  = 0.88

    // ── Loop states ───────────────────────────────────────────────────────
    @State private var moonGlow:    Double  = 0.40
    @State private var bookFloat:   CGFloat = 0
    @State private var swirlPulse:  Double  = 0.75
    @State private var f1: CGFloat = 0; @State private var f2: CGFloat = 2
    @State private var f3: CGFloat = 0; @State private var f4: CGFloat = 3
    @State private var f5: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Background ────────────────────────────────────────────────
            Image("Ob2Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // ── Swirl (golden S-curve from book) ──────────────────
                    Image("Ob2Swirl")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.52)
                        .opacity(swirlOpacity * swirlPulse)
                        .scaleEffect(swirlScale, anchor: .bottom)
                        .position(x: w * 0.52, y: h * 0.32)

                    // ── Moon (upper-left) ─────────────────────────────────
                    Image("Ob2Moon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.22)
                        .shadow(color: Color(red: 1, green: 0.80, blue: 0.18).opacity(moonGlow),
                                radius: 32, x: 0, y: 0)
                        .opacity(moonOpacity)
                        .offset(y: moonY)
                        .position(x: w * 0.18, y: h * 0.13)

                    // ── Book (bottom-center) ──────────────────────────────
                    Image("Ob2Book")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.74)
                        .shadow(color: Color(red: 1, green: 0.82, blue: 0.25).opacity(0.40),
                                radius: 22, x: 0, y: 6)
                        .scaleEffect(bookScale)
                        .opacity(bookOpacity)
                        .offset(y: bookFloat)
                        .position(x: w * 0.50, y: h * 0.57)

                    // ── Book cards (fly out from book) ────────────────────

                    // img3 — ship (upper-left)
                    Image("Ob2Img3")
                        .resizable().scaledToFit().frame(width: w * 0.28)
                        .rotationEffect(.degrees(14))
                        .opacity(c3Op).offset(y: c3Y + f3)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 1, y: 3)
                        .position(x: w * 0.18, y: h * 0.22)

                    // img4 — dragon (upper-center)
                    Image("Ob2Img4")
                        .resizable().scaledToFit().frame(width: w * 0.27)
                        .rotationEffect(.degrees(-7))
                        .opacity(c4Op).offset(y: c4Y + f4)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: -1, y: 3)
                        .position(x: w * 0.50, y: h * 0.14)

                    // img1 — balloon (upper-right)
                    Image("Ob2Img1")
                        .resizable().scaledToFit().frame(width: w * 0.28)
                        .rotationEffect(.degrees(10))
                        .opacity(c1Op).offset(y: c1Y + f1)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 1, y: 3)
                        .position(x: w * 0.82, y: h * 0.22)

                    // img2 — forest girl (mid-left)
                    Image("Ob2Img2")
                        .resizable().scaledToFit().frame(width: w * 0.27)
                        .rotationEffect(.degrees(-13))
                        .opacity(c2Op).offset(y: c2Y + f2)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 1, y: 3)
                        .position(x: w * 0.20, y: h * 0.38)

                    // img5 — castle (mid-right)
                    Image("Ob2Img5")
                        .resizable().scaledToFit().frame(width: w * 0.28)
                        .rotationEffect(.degrees(13))
                        .opacity(c5Op).offset(y: c5Y + f5)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: -1, y: 3)
                        .position(x: w * 0.80, y: h * 0.38)
                }
            }
            .clipped()

            // ── Bottom gradient ───────────────────────────────────────────
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.025, green: 0.038, blue: 0.115).opacity(0.55),
                    Color(red: 0.015, green: 0.025, blue: 0.085).opacity(0.98),
                ],
                startPoint: .init(x: 0.5, y: 0.26),
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Bottom content ────────────────────────────────────────────
            VStack(spacing: 0) {
                Text("Discover Your\nNext Favorite Story")
                    .font(.custom("Georgia-BoldItalic", size: 38))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient(
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

                HStack(spacing: 6) {
                    Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                        .frame(width: 40, height: 1)
                    Image(systemName: "sparkle").font(.system(size: 12))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.8))
                    Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                        .frame(width: 40, height: 1)
                }
                .opacity(titleOpacity)
                .padding(.top, 14)

                Text("Browse cozy bedtime tales, magical adventures, and enchanting reads curated for every mood.")
                    .font(.system(size: 15, weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .padding(.top, 10)
                    .opacity(bodyOpacity)

                PageDots(current: index, total: total)
                    .padding(.top, 24)
                    .opacity(bodyOpacity)

                // Continue button (Ob2Button image + text overlay)
                Button(action: {
                    withAnimation(.spring(duration: 0.45)) { currentPage = 2 }
                }) {
                    ZStack {
                        Image("Ob2Button")
                            .resizable()
                            .scaledToFit()
                        Text("Continue")
                            .font(.custom("Georgia-Bold", size: 19))
                            .foregroundStyle(Color(red: 0.10, green: 0.05, blue: 0.01))
                    }
                    .shadow(color: Color(red: 1, green: 0.78, blue: 0.2).opacity(0.40),
                            radius: 16, x: 0, y: 6)
                }
                .padding(.horizontal, 28)
                .scaleEffect(btnScale)
                .padding(.top, 22)
                .padding(.bottom, 52)
                .opacity(bodyOpacity)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { animateIn(); startLooping() }
        .onChange(of: currentPage) { _, _ in
            guard currentPage == index else { return }
            resetAndAnimate()
        }
    }

    // MARK: Entry
    private func animateIn() {
        // Moon descends
        withAnimation(.spring(response: 0.75, dampingFraction: 0.72).delay(0.18)) {
            moonOpacity = 1; moonY = 0
        }
        // Book scales in
        withAnimation(.spring(response: 0.70, dampingFraction: 0.70).delay(0.38)) {
            bookScale = 1; bookOpacity = 1
        }
        // Swirl grows from book bottom
        withAnimation(.spring(response: 0.80, dampingFraction: 0.75).delay(0.55)) {
            swirlOpacity = 1; swirlScale = 1
        }
        // Cards fly out one by one (staggered)
        let delays: [Double] = [0.72, 0.87, 0.65, 1.02, 1.00]
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(delays[0])) { c1Op = 1; c1Y = 0 }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(delays[1])) { c2Op = 1; c2Y = 0 }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(delays[2])) { c3Op = 1; c3Y = 0 }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(delays[3])) { c4Op = 1; c4Y = 0 }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(delays[4])) { c5Op = 1; c5Y = 0 }
        // Text
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(1.20)) {
            titleOpacity = 1; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.55).delay(1.48)) { bodyOpacity  = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.55)) { btnScale = 1 }
    }

    private func resetAndAnimate() {
        moonOpacity = 0; moonY = -28
        bookScale = 0.72; bookOpacity = 0
        swirlOpacity = 0; swirlScale = 0.55
        c1Op = 0; c1Y = 70; c2Op = 0; c2Y = 70
        c3Op = 0; c3Y = 70; c4Op = 0; c4Y = 70; c5Op = 0; c5Y = 70
        titleOpacity = 0; titleOffset = 24; bodyOpacity = 0; btnScale = 0.88
        animateIn()
    }

    // MARK: Loop
    private func startLooping() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { moonGlow = 0.85 }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.4)) { bookFloat = -6 }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.2)) { swirlPulse = 1.0 }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.0)) { f1 = -5 }
        withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true).delay(0.5)) { f2 = -4 }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.9)) { f3 = -6 }
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true).delay(0.3)) { f4 = -5 }
        withAnimation(.easeInOut(duration: 2.9).repeatForever(autoreverses: true).delay(0.7)) { f5 = -4 }
    }
}

// MARK: - Onboarding 3 — Layered illustration
struct Onboarding3PageView: View {
    let index:       Int
    let total:       Int
    @Binding var currentPage: Int
    @Binding var isFinished:  Bool

    @State private var illustrationOpacity: Double  = 0
    @State private var titleOpacity:        Double  = 0
    @State private var titleOffset:         CGFloat = 24
    @State private var bodyOpacity:         Double  = 0
    @State private var btnScale:            Double  = 0.88

    @State private var lanternAngle:  Double  = -4
    @State private var featherOffset: CGFloat = 0
    @State private var card1Offset:   CGFloat = 0
    @State private var card2Offset:   CGFloat = 4
    @State private var moonGlow:      Double  = 0.5

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("Ob3Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    Image("Ob3Road")
                        .resizable().scaledToFit().frame(width: w * 0.70)
                        .position(x: w * 0.50, y: h * 0.33)

                    Image("Ob3Book")
                        .resizable().scaledToFit().frame(width: w * 0.72)
                        .position(x: w * 0.48, y: h * 0.58)

                    Image("Ob3Moon")
                        .resizable().scaledToFit().frame(width: w * 0.24)
                        .shadow(color: Color(red: 1, green: 0.8, blue: 0.2).opacity(moonGlow),
                                radius: 28, x: 0, y: 0)
                        .rotationEffect(.degrees(8))
                        .position(x: w * 0.20, y: h * 0.16)

                    Image("Ob3Light")
                        .resizable().scaledToFit().frame(width: w * 0.17)
                        .rotationEffect(.degrees(lanternAngle), anchor: .top)
                        .shadow(color: Color(red: 1, green: 0.75, blue: 0.1).opacity(0.50),
                                radius: 14, x: 0, y: 4)
                        .position(x: w * 0.14, y: h * 0.43)

                    Image("Ob3Feather")
                        .resizable().scaledToFit().frame(width: w * 0.22)
                        .rotationEffect(.degrees(-12))
                        .offset(y: featherOffset)
                        .position(x: w * 0.21, y: h * 0.56)

                    Image("Ob3Img1")
                        .resizable().scaledToFit().frame(width: w * 0.32)
                        .rotationEffect(.degrees(11))
                        .offset(y: card1Offset)
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 2, y: 4)
                        .position(x: w * 0.80, y: h * 0.26)

                    Image("Ob3Img2")
                        .resizable().scaledToFit().frame(width: w * 0.29)
                        .rotationEffect(.degrees(-9))
                        .offset(y: card2Offset)
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: -2, y: 4)
                        .position(x: w * 0.82, y: h * 0.45)
                }
            }
            .clipped()
            .opacity(illustrationOpacity)

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

            Ob3BottomContent(
                index:        index,
                total:        total,
                titleOpacity: $titleOpacity,
                titleOffset:  $titleOffset,
                bodyOpacity:  $bodyOpacity,
                btnScale:     $btnScale,
                onButton:     handleGetStarted
            )
        }
        .onAppear { animateIn(); startFloating() }
        .onChange(of: currentPage) { _, _ in
            guard currentPage == index else { return }
            resetAndAnimate()
        }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { illustrationOpacity = 1 }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.25)) {
            titleOpacity = 1; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.55)) { bodyOpacity = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.65)) { btnScale = 1 }
    }
    private func resetAndAnimate() {
        illustrationOpacity = 0; titleOpacity = 0; titleOffset = 24
        bodyOpacity = 0; btnScale = 0.88
        animateIn()
    }
    private func startFloating() {
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { lanternAngle = 4 }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.3)) { featherOffset = -6 }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.1)) { card1Offset = -5 }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.8)) { card2Offset = -4 }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { moonGlow = 0.85 }
    }
    private func handleGetStarted() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.55)) { isFinished = true }
                }
            }
    }
}

// MARK: - Onboarding 3 Bottom Content
private struct Ob3BottomContent: View {
    let index:       Int
    let total:       Int
    @Binding var titleOpacity: Double
    @Binding var titleOffset:  CGFloat
    @Binding var bodyOpacity:  Double
    @Binding var btnScale:     Double
    let onButton: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Title image
            Image("Ob3Text")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 32)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            // Sparkle divider
            HStack(spacing: 6) {
                Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                    .frame(width: 40, height: 1)
                Image(systemName: "sparkle").font(.system(size: 12))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.8))
                Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4))
                    .frame(width: 40, height: 1)
            }
            .opacity(titleOpacity)
            .padding(.top, 14)

            Text("Save favorites, enjoy peaceful night reads, and step into magical worlds whenever you need a quiet escape.")
                .font(.system(size: 15, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.72))
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .padding(.top, 10)
                .opacity(bodyOpacity)

            PageDots(current: index, total: total)
                .padding(.top, 24)
                .opacity(bodyOpacity)

            // Get Started button (Ob3Button image + text overlay)
            Button(action: onButton) {
                ZStack {
                    Image("Ob3Button")
                        .resizable()
                        .scaledToFit()
                    Text("Get Started")
                        .font(.custom("Georgia-Bold", size: 19))
                        .foregroundStyle(Color(red: 0.10, green: 0.05, blue: 0.01))
                }
                .shadow(color: Color(red: 1, green: 0.78, blue: 0.2).opacity(0.42),
                        radius: 16, x: 0, y: 6)
            }
            .padding(.horizontal, 28)
            .scaleEffect(btnScale)
            .padding(.top, 22)
            .padding(.bottom, 52)
            .opacity(bodyOpacity)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared Page Dots
struct PageDots: View {
    let current: Int
    let total:   Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current
                          ? Color(red: 1, green: 0.85, blue: 0.3)
                          : Color.white.opacity(0.28))
                    .frame(width: i == current ? 22 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
    }
}

// MARK: - Previews
#Preview("Onboarding 1") {
    Onboarding1PageView(
        index: 0, total: 3,
        currentPage: .constant(0),
        isFinished: .constant(false)
    )
    .ignoresSafeArea()
}

#Preview("Onboarding 3") {
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
