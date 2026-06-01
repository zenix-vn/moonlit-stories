import SwiftUI
import Observation

// MARK: - EpisodeReaderView ViewModel
@MainActor
@Observable
class EpisodeReaderViewModel {
    var episode: EpisodeDetail? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var readProgress: Double = 0.0

    func loadEpisode(id: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            episode = try await NetworkService.shared.fetchEpisodeDetail(episodeId: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ObservationIgnored var isInsufficientCoins = false

    func unlockWithCoins(id: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        isInsufficientCoins = false
        var success = false
        do {
            let res = try await NetworkService.shared.unlockEpisodeWithCoins(episodeId: id)
            if res.status == "unlocked" || res.status == "already_unlocked" {
                NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
                episode = try await NetworkService.shared.fetchEpisodeDetail(episodeId: id)
                success = true
            }
        } catch {
            let errMsg = error.localizedDescription
            errorMessage = errMsg
            if errMsg.localizedCaseInsensitiveContains("insufficient") {
                isInsufficientCoins = true
            }
        }
        isLoading = false
        return success
    }

    func unlockWithAd(id: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let res = try await NetworkService.shared.unlockEpisodeWithAd(episodeId: id)
            if res.status == "unlocked" || res.status == "already_unlocked" {
                NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
                episode = try await NetworkService.shared.fetchEpisodeDetail(episodeId: id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Reading Settings
struct ReaderSettings {
    var fontSize: CGFloat = 17
    var lineSpacing: CGFloat = 9
    var isSerifFont: Bool = true
    var isDarkMode: Bool = true
}

// MARK: - EpisodeReaderView
struct EpisodeReaderView: View {
    let episodeId: String
    let story: Story
    let episodes: [EpisodeMeta]

    @State private var viewModel = EpisodeReaderViewModel()
    @State private var settings = ReaderSettings()
    @State private var audioPlayer = AudioPlayerManager()
    @State private var showTopBar = true
    @State private var showSettings = false
    @State private var readerScrollRef = ReaderScrollRef()
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var nextEpisode: EpisodeMeta? = nil
    @State private var prevEpisode: EpisodeMeta? = nil
    @State private var selectedNewEpisodeId: String? = nil
    @State private var readingSessionID: String? = nil
    @State private var readingSessionStartedAt: Date? = nil
    @State private var readingProgressStart: Double = 0
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoUnlockEpisodes") private var autoUnlockEpisodes = false
    @State private var showingShopSheet = false

    // Floating audio bubble
    @State private var bubblePos: CGPoint = .zero          // set on appear
    @State private var bubbleDragStart: CGPoint = .zero
    @State private var bubbleExpanded: Bool = false
    private var bgColor: Color {
        settings.isDarkMode ? Color(red: 0.06, green: 0.04, blue: 0.10) : Color(red: 0.97, green: 0.94, blue: 0.88)
    }
    private var textColor: Color {
        settings.isDarkMode ? Color(red: 0.90, green: 0.87, blue: 0.82) : Color(red: 0.15, green: 0.12, blue: 0.10)
    }
    private var subtextColor: Color {
        settings.isDarkMode ? Color(red: 0.55, green: 0.50, blue: 0.45) : Color(red: 0.50, green: 0.44, blue: 0.38)
    }
    private var cardBg: Color {
        settings.isDarkMode ? Color(red: 0.10, green: 0.07, blue: 0.16) : Color(red: 0.93, green: 0.89, blue: 0.83)
    }
    private var activeEpisodeId: String {
        selectedNewEpisodeId ?? episodeId
    }

    var body: some View {
        ZStack(alignment: .top) {
            bgColor.ignoresSafeArea()

            // Main reading scroll
            GeometryReader { outer in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .top) {
                        GeometryReader { inner in
                            Color.clear
                                .preference(key: ScrollOffsetKey.self, value: inner.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)

                        VStack(alignment: .leading, spacing: 0) {
                            if viewModel.isLoading {
                                readerSkeleton
                            } else if let ep = viewModel.episode {
                                readerContent(ep: ep)
                            } else if let err = viewModel.errorMessage {
                                errorView(message: err)
                            }

                            // Bottom nav
                            bottomNav
                                .padding(.top, 40)

                            Color.clear.frame(height: 50)
                        }
                        .padding(.top, 16)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { contentHeight = geo.size.height }
                                    .onChange(of: geo.size.height) { _, newHeight in
                                        contentHeight = newHeight
                                    }
                            }
                        )
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { val in
                    // Direction-based: dùng ref class tránh vấn đề @State capture
                    let delta = val - readerScrollRef.offset
                    readerScrollRef.offset = val
                    if val > -40 {
                        if !showTopBar { withAnimation(.easeInOut(duration: 0.25)) { showTopBar = true } }
                    } else if abs(delta) > 6 {
                        let shouldShow = delta > 0
                        if shouldShow != showTopBar {
                            withAnimation(.easeInOut(duration: 0.25)) { showTopBar = shouldShow }
                        }
                    }
                    let scrolled = -val
                    let total = max(1, contentHeight - outer.size.height)
                    viewModel.readProgress = min(1.0, max(0, scrolled / total))
                }
                .onAppear { viewportHeight = outer.size.height }
            }

            // Reading progress bar
            progressBar

            // Settings panel
            if showSettings {
                settingsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
        .overlay {
            if let ep = viewModel.episode, ep.hasAccess {
                GeometryReader { geo in
                    // Backdrop — captures taps outside the bubble to collapse it
                    if bubbleExpanded {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                                    bubbleExpanded = false
                                }
                            }
                    }

                    // Bubble — drawn on top of backdrop
                    floatingAudioBubble
                        .position(effectiveBubblePos(in: geo.size))
                        .gesture(bubbleDragGesture(in: geo.size))
                        .onAppear {
                            if bubblePos == .zero {
                                bubblePos = CGPoint(x: geo.size.width - 46, y: geo.size.height - 170)
                            }
                        }
                }
                .allowsHitTesting(true)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // ZStack keeps constant height so safe area never changes (avoids scroll-jump bug)
            ZStack {
                readerTopBar
                    .opacity(showTopBar ? 1 : 0)
                    .allowsHitTesting(showTopBar)
                readerCompactTopBar
                    .opacity(showTopBar ? 0 : 1)
                    .allowsHitTesting(!showTopBar)
            }
            .animation(.easeInOut(duration: 0.25), value: showTopBar)
        }
        .task {
            await loadAndSyncEpisode(id: activeEpisodeId)
        }
        .onChange(of: episodeId) { _, newId in
            selectedNewEpisodeId = nil
            Task { await loadAndSyncEpisode(id: newId) }
        }
        .onChange(of: selectedNewEpisodeId) { _, newId in
            guard let newId else { return }
            Task { await loadAndSyncEpisode(id: newId) }
        }
        .onChange(of: viewModel.episode?.hasAccess) { oldHasAccess, newHasAccess in
            if newHasAccess == true, oldHasAccess != true {
                if let ep = viewModel.episode {
                    if let url = ep.audioUrl, !url.isEmpty {
                        audioPlayer.load(
                            urlString: url,
                            episodeTitle: "Ep \(ep.episodeNumber) · \(ep.title)",
                            storyTitle: story.title
                        )
                    } else if let content = ep.contentText, !content.isEmpty {
                        audioPlayer.loadTTS(
                            text: cleanHTMLTags(content),
                            episodeTitle: "Ep \(ep.episodeNumber) · \(ep.title)",
                            storyTitle: story.title
                        )
                    }
                }
            }
        }
        .onDisappear {
            Task {
                await finalizeReadingSession()
                NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
            }
            audioPlayer.stop()
        }
        .sheet(isPresented: $showingShopSheet) {
            NavigationStack {
                CoinShopView()
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Components

    private var progressBar: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.mlPurple, Color.mlPink],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: geo.size.width * viewModel.readProgress, height: 2)
        }
        .frame(height: 2)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var readerTopBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(settings.isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(textColor)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(story.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(subtextColor)
                    .lineLimit(1)
                if let ep = viewModel.episode {
                    Text("Ep \(ep.episodeNumber) · \(ep.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(Int(viewModel.readProgress * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.mlPurple)

            Button(action: { withAnimation { showSettings.toggle() } }) {
                ZStack {
                    Circle()
                        .fill(settings.isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14))
                        .foregroundStyle(textColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background {
            Rectangle()
                .fill(settings.isDarkMode ? .ultraThinMaterial : .regularMaterial)
                .environment(\.colorScheme, settings.isDarkMode ? .dark : .light)
        }
    }

    private var readerCompactTopBar: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showTopBar = true }
            } label: {
                HStack(spacing: 6) {
                    if let ep = viewModel.episode {
                        Text("Ep \(ep.episodeNumber)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mlPurple)
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(subtextColor)
                        Text(ep.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "book.pages")
                            .font(.system(size: 13))
                            .foregroundStyle(subtextColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(settings.isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.07))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(settings.isDarkMode ? .ultraThinMaterial : .regularMaterial)
                .environment(\.colorScheme, settings.isDarkMode ? .dark : .light)
        }
    }

    private func readerContent(ep: EpisodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chapter heading
            VStack(alignment: .leading, spacing: 8) {
                Text("Episode \(ep.episodeNumber)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mlPurple)
                    .tracking(1.5)
                    .textCase(.uppercase)

                Text(ep.title)
                    .font(.system(size: 24, weight: .bold, design: settings.isSerifFont ? .serif : .default))
                    .foregroundStyle(textColor)
                    .lineLimit(4)

                HStack(spacing: 12) {
                    if ep.wordCount > 0 {
                        Label("\(ep.wordCount.formatted()) words", systemImage: "doc.text")
                            .font(.system(size: 11))
                            .foregroundStyle(subtextColor)
                    }
                    if ep.estimatedReadingTime > 0 {
                        Label("\(ep.estimatedReadingTime) min read", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(subtextColor)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            Divider()
                .background(settings.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.1))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            // Episode body text
            if ep.hasAccess, let content = ep.contentText, !content.isEmpty {
                Text(cleanHTMLTags(content))
                    .font(.system(size: settings.fontSize, design: settings.isSerifFont ? .serif : .default))
                    .foregroundStyle(textColor)
                    .lineSpacing(settings.lineSpacing)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let preview = ep.previewText, !preview.isEmpty {
                // Locked episode — show preview + blur fade
                VStack(alignment: .leading, spacing: 0) {
                    Text(cleanHTMLTags(preview))
                        .font(.system(size: settings.fontSize, design: settings.isSerifFont ? .serif : .default))
                        .foregroundStyle(textColor)
                        .lineSpacing(settings.lineSpacing)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                        .mask(
                            LinearGradient(
                                colors: [.black, .black, .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                    // Locked CTA
                    lockedCTA(ep: ep)
                }
            } else {
                lockedCTA(ep: ep)
            }
        }
    }

    private func lockedCTA(ep: EpisodeDetail) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.mlPurple.opacity(0.3), Color.mlPink.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.mlPurple)
            }

            VStack(spacing: 6) {
                Text("Episode Locked")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textColor)
                Text("Unlock to continue reading")
                    .font(.system(size: 13))
                    .foregroundStyle(subtextColor)
            }

            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        let success = await viewModel.unlockWithCoins(id: ep.id)
                        if !success && viewModel.isInsufficientCoins {
                            showingShopSheet = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.mlGold)
                        Text("Use \(ep.coinPrice) Coins")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [Color.mlPurple, Color.mlPurpleDim],
                            startPoint: .leading, endPoint: .trailing
                        ))
                    )
                }

                Button(action: {
                    Task {
                        await viewModel.unlockWithAd(id: ep.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 13))
                        Text("Watch Ad")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.mlPurple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.mlPurple.opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color.mlPurple.opacity(0.25), lineWidth: 1))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }

    private var readerSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(settings.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                    .frame(height: 14)
                    .frame(maxWidth: i % 3 == 2 ? 200 : .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .shimmering(active: true)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.mlPink)
            Text("Couldn't load episode")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(textColor)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(subtextColor)
                .multilineTextAlignment(.center)
            Button(action: { Task { await loadAndSyncEpisode(id: activeEpisodeId) } }) {
                Text("Retry")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 28).padding(.vertical, 10)
                    .background(Capsule().fill(Color.mlPurple))
            }
        }
        .padding(40)
    }

    private var bottomNav: some View {
        HStack(spacing: 12) {
            // Previous
            Button(action: {
                if let prev = prevEpisode {
                    selectedNewEpisodeId = prev.id
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Prev")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(prevEpisode != nil ? Color.mlPurple : subtextColor)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                            prevEpisode != nil ? Color.mlPurple.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1))
                )
            }
            .disabled(prevEpisode == nil)

            Spacer()

            // Chapter info
            VStack(spacing: 2) {
                if let ep = viewModel.episode {
                    Text("Ep \(ep.episodeNumber)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(textColor)
                    Text("of \(episodes.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(subtextColor)
                }
            }

            Spacer()

            // Next
            Button(action: {
                if let next = nextEpisode {
                    selectedNewEpisodeId = next.id
                }
            }) {
                HStack(spacing: 6) {
                    Text("Next")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(nextEpisode != nil ? Color.white : subtextColor)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(nextEpisode != nil ?
                              LinearGradient(colors: [Color.mlPurple, Color.mlPurpleDim], startPoint: .leading, endPoint: .trailing) :
                              LinearGradient(colors: [cardBg, cardBg], startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                            nextEpisode != nil ? Color.clear : Color.white.opacity(0.07), lineWidth: 1))
                )
            }
            .disabled(nextEpisode == nil)
        }
        .padding(.horizontal, 24)
    }

    private var settingsPanel: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            VStack(spacing: 20) {
                // Font size
                HStack {
                    Text("A")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(subtextColor)
                    Slider(value: $settings.fontSize, in: 13...22, step: 1)
                        .tint(Color.mlPurple)
                    Text("A")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(textColor)
                }
                .padding(.horizontal, 20)

                Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)

                // Font style toggle
                HStack(spacing: 12) {
                    readerOptionBtn(label: "Serif", isSelected: settings.isSerifFont) {
                        settings.isSerifFont = true
                    }
                    readerOptionBtn(label: "Sans", isSelected: !settings.isSerifFont) {
                        settings.isSerifFont = false
                    }
                    readerOptionBtn(label: "☀️ Light", isSelected: !settings.isDarkMode) {
                        withAnimation { settings.isDarkMode = false }
                    }
                    readerOptionBtn(label: "🌙 Dark", isSelected: settings.isDarkMode) {
                        withAnimation { settings.isDarkMode = true }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 28)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(settings.isDarkMode ? Color(red: 0.10, green: 0.08, blue: 0.18) : Color(red: 0.97, green: 0.95, blue: 0.92))
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: -8)
        )
    }

    private func readerOptionBtn(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : subtextColor)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.mlPurple : (settings.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.07)))
                )
        }
    }

    // MARK: - Floating Audio Bubble

    private let bubbleD: CGFloat = 62      // collapsed diameter
    private let bubbleExpandW: CGFloat = 258  // expanded width

    private func effectiveBubblePos(in size: CGSize) -> CGPoint {
        let hw = (bubbleExpanded ? bubbleExpandW : bubbleD) / 2 + 8
        return CGPoint(
            x: min(max(bubblePos.x, hw), size.width - hw),
            y: min(max(bubblePos.y, 56), size.height - 80)
        )
    }

    private func bubbleDragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                if bubbleDragStart == .zero {
                    bubbleDragStart = bubblePos
                }
                bubblePos = CGPoint(
                    x: bubbleDragStart.x + v.translation.width,
                    y: bubbleDragStart.y + v.translation.height
                )
            }
            .onEnded { v in
                let hw = (bubbleExpanded ? bubbleExpandW : bubbleD) / 2 + 8
                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                    bubblePos.x = min(max(bubbleDragStart.x + v.translation.width, hw), size.width - hw)
                    bubblePos.y = min(max(bubbleDragStart.y + v.translation.height, 56), size.height - 80)
                }
                bubbleDragStart = .zero
            }
    }

    @ViewBuilder
    private var floatingAudioBubble: some View {
        ZStack {
            // ── Liquid Glass background ──
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            // Purple-pink tint layer
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.mlPurple.opacity(0.38), Color.mlPink.opacity(0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            // Glass border
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), Color.white.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )

            if bubbleExpanded {
                // ── EXPANDED: compact controls pill ──
                HStack(spacing: 2) {
                    // Skip -15
                    Button(action: { audioPlayer.skipBackward() }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(width: 42, height: 42)
                    }

                    // Play / Pause
                    Button(action: { audioPlayer.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.16))
                                .frame(width: 46, height: 46)
                            if audioPlayer.isLoading {
                                ProgressView().tint(.white).scaleEffect(0.65)
                            } else {
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: audioPlayer.isPlaying ? 0 : 2)
                            }
                        }
                    }

                    // Skip +15
                    Button(action: { audioPlayer.skipForward() }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(width: 42, height: 42)
                    }

                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 1, height: 28)
                        .padding(.horizontal, 2)

                    // Time remaining
                    Text(audioPlayer.formattedRemaining)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44)

                    // Speed menu
                    Menu {
                        ForEach(AudioPlayerManager.rateOptions, id: \.self) { rate in
                            Button(action: { audioPlayer.setRate(rate) }) {
                                Label(rateLabel(rate), systemImage: audioPlayer.playbackRate == rate ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Text(rateLabel(audioPlayer.playbackRate))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.14)))
                    }
                    .padding(.trailing, 10)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))

            } else {
                // ── COLLAPSED: bubble with progress ring ──
                ZStack {
                    // Outer progress ring
                    Circle()
                        .trim(from: 0, to: min(CGFloat(audioPlayer.progress), 1))
                        .stroke(
                            LinearGradient(
                                colors: [.white, Color.mlPink.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: bubbleD - 8, height: bubbleD - 8)

                    // Track ring background
                    Circle()
                        .stroke(.white.opacity(0.10), lineWidth: 2.5)
                        .frame(width: bubbleD - 8, height: bubbleD - 8)

                    // Icon
                    if audioPlayer.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: audioPlayer.isPlaying ? 0 : 2)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08, anchor: .center)))
            }
        }
        .frame(width: bubbleExpanded ? bubbleExpandW : bubbleD,
               height: bubbleD)
        .clipShape(Capsule())
        .shadow(color: Color.mlPurple.opacity(audioPlayer.isPlaying ? 0.55 : 0.28),
                radius: audioPlayer.isPlaying ? 18 : 10, x: 0, y: 4)
        .animation(.spring(response: 0.36, dampingFraction: 0.74), value: bubbleExpanded)
        .animation(.easeInOut(duration: 0.15), value: audioPlayer.isPlaying)
        .onTapGesture {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                bubbleExpanded.toggle()
            }
        }
    }

    private func rateLabel(_ rate: Float) -> String {
        rate == 1.0 ? "1x" : String(format: "%.4g", rate) + "x"
    }

    private func loadAndSyncEpisode(id: String) async {
        await finalizeReadingSession()
        audioPlayer.stop()
        await viewModel.loadEpisode(id: id)
        
        // Auto-unlock check
        if let ep = viewModel.episode, !ep.hasAccess, !ep.isFree, autoUnlockEpisodes {
            await viewModel.unlockWithCoins(id: ep.id)
        }
        
        updateNavEpisodes()
        await beginReadingSessionIfPossible()
        
        // Save initial progress immediately so backend knows they are on this episode!
        if let ep = viewModel.episode {
            Task {
                try? await NetworkService.shared.updateReadingProgress(
                    storyID: story.id,
                    episodeID: ep.id,
                    progressPercent: 0.0,
                    currentPosition: 0
                )
            }
        }
        
        if let ep = viewModel.episode {
            if let url = ep.audioUrl, !url.isEmpty {
                audioPlayer.load(
                    urlString: url,
                    episodeTitle: "Ep \(ep.episodeNumber) · \(ep.title)",
                    storyTitle: story.title
                )
            } else if let content = ep.contentText, !content.isEmpty {
                audioPlayer.loadTTS(
                    text: cleanHTMLTags(content),
                    episodeTitle: "Ep \(ep.episodeNumber) · \(ep.title)",
                    storyTitle: story.title
                )
            }
        }
    }

    private func updateNavEpisodes() {
        guard let currentEp = viewModel.episode else { return }
        let currentNum = currentEp.episodeNumber
        prevEpisode = episodes.first(where: { $0.episodeNumber == currentNum - 1 })
        nextEpisode = episodes.first(where: { $0.episodeNumber == currentNum + 1 })
    }

    private func beginReadingSessionIfPossible() async {
        guard readingSessionID == nil, let currentEpisode = viewModel.episode else { return }
        do {
            let sessionID = try await NetworkService.shared.startReadingSession(
                storyID: story.id,
                episodeID: currentEpisode.id
            )
            readingSessionID = sessionID
            readingSessionStartedAt = Date()
            readingProgressStart = viewModel.readProgress * 100.0
        } catch {
            #if DEBUG
            print("Failed to start reading session: \(error)")
            #endif
        }
    }

    private func finalizeReadingSession() async {
        guard let sessionID = readingSessionID, let currentEpisode = viewModel.episode else { return }
        let progressEnd = min(100.0, max(0.0, viewModel.readProgress * 100.0))
        let duration = Int(Date().timeIntervalSince(readingSessionStartedAt ?? Date()))
        let completed = progressEnd >= 99.9

        do {
            try await NetworkService.shared.updateReadingProgress(
                storyID: story.id,
                episodeID: currentEpisode.id,
                progressPercent: progressEnd,
                currentPosition: Int(progressEnd)
            )
            try await NetworkService.shared.endReadingSession(
                sessionID: sessionID,
                durationSeconds: max(duration, 1),
                progressStart: readingProgressStart,
                progressEnd: progressEnd,
                completed: completed
            )
        } catch {
            #if DEBUG
            print("Failed to finalize reading session: \(error)")
            #endif
        }

        readingSessionID = nil
        readingSessionStartedAt = nil
        readingProgressStart = 0
    }
}

// Ref class để track scroll offset mà không trigger SwiftUI re-render
private final class ReaderScrollRef {
    var offset: CGFloat = 0
}

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Shimmer modifier (simple)
extension View {
    @ViewBuilder func shimmering(active: Bool) -> some View {
        if active {
            self.overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
            )
        } else {
            self
        }
    }
}

#Preview {
    EpisodeReaderView(
        episodeId: "preview",
        story: Story(
            id: "s1", title: "Reborn as the Villain Queen",
            slug: "reborn-as-villain-queen", description: nil, hook: nil,
            coverUrl: nil, freeEpisodeCount: 3, defaultCoinPrice: 20,
            totalEpisodes: 5, isFeatured: true, isHot: false, isEditorPick: false,
            genres: ["Fantasy"], moods: nil
        ),
        episodes: []
    )
    .preferredColorScheme(.dark)
}

private func cleanHTMLTags(_ text: String) -> String {
    var cleaned = text
    cleaned = cleaned.replacingOccurrences(of: "<p>", with: "")
    cleaned = cleaned.replacingOccurrences(of: "</p>", with: "\n\n")
    cleaned = cleaned.replacingOccurrences(of: "<br>", with: "\n")
    cleaned = cleaned.replacingOccurrences(of: "<br/>", with: "\n")
    cleaned = cleaned.replacingOccurrences(of: "<br />", with: "\n")
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}
