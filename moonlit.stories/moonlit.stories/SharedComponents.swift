import SwiftUI

// MARK: - CachedAsyncImage
// Drop-in replacement for AsyncImage with URLCache-backed disk persistence.
// Images are cached to disk automatically by URLSession (up to 500MB).
// Configure cache capacity once at app start via CachedAsyncImage.configureCache().

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    // Convenience: URL string initializer
    init(urlString: String?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = urlString.flatMap(URL.init)
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    private func loadImage() async {
        guard let url else {
            phase = .empty
            return
        }

        // Use the shared cached session
        let session = ImageURLSession.shared

        // Check in-memory NSCache first (instant, no disk I/O)
        if let cached = ImageMemoryCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            let (data, _) = try await session.data(for: request)
            guard !Task.isCancelled else { return }
            if let uiImage = UIImage(data: data) {
                ImageMemoryCache.shared.setImage(uiImage, for: url)
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure(URLError(.cannotDecodeRawData))
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failure(error)
        }
    }

    // MARK: - Configure disk cache capacity (call once in App init)
    static func configureCache(memoryMB: Int = 50, diskMB: Int = 300) {
        ImageURLSession.configure(memoryMB: memoryMB, diskMB: diskMB)
    }
}

// MARK: - Private Helpers

private final class ImageURLSession {
    static let shared: URLSession = {
        configure()
        return _session
    }()

    private static var _session: URLSession = URLSession.shared

    static func configure(memoryMB: Int = 50, diskMB: Int = 300) {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: memoryMB * 1024 * 1024,
            diskCapacity:   diskMB  * 1024 * 1024,
            diskPath:       "moonlit_image_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 6
        _session = URLSession(configuration: config)
    }
}

private final class ImageMemoryCache {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 40 * 1024 * 1024 // 40 MB max
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4) // approx bytes
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - StoryCoverView
// Unified cover image component used across all story cards.
// Replaces the 5+ duplicated AsyncImage + gradient-fallback blocks.

struct StoryCoverView: View {
    let coverUrl: String?
    let title: String
    let cornerRadius: CGFloat
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let gradientColors = getGradientForString(title)
        let fallback = RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(colors: [gradientColors.0, gradientColors.1],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))

        if let urlString = coverUrl, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallback
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            fallback
                .frame(width: width, height: height)
        }
    }
}

// MARK: - Shimmer Modifier (unified)
// Consolidates 2 duplicate shimmer implementations (EpisodeReaderView + HomeView).

extension View {
    @ViewBuilder
    func shimmer(active: Bool) -> some View {
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

// MARK: - getGradientForString (moved from HomeView global scope)
// Stable deterministic gradient color pair based on a string hash.

func getGradientForString(_ str: String) -> (Color, Color) {
    let palettes: [(Color, Color)] = [
        (Color(red: 0.38, green: 0.12, blue: 0.60), Color(red: 0.18, green: 0.04, blue: 0.30)),
        (Color(red: 0.60, green: 0.12, blue: 0.32), Color(red: 0.28, green: 0.04, blue: 0.16)),
        (Color(red: 0.16, green: 0.22, blue: 0.60), Color(red: 0.06, green: 0.08, blue: 0.30)),
        (Color(red: 0.48, green: 0.18, blue: 0.60), Color(red: 0.22, green: 0.06, blue: 0.32)),
        (Color(red: 0.60, green: 0.30, blue: 0.12), Color(red: 0.30, green: 0.12, blue: 0.04)),
        (Color(red: 0.12, green: 0.48, blue: 0.52), Color(red: 0.04, green: 0.22, blue: 0.28)),
    ]
    let index = abs(str.hashValue) % palettes.count
    return palettes[index]
}
