import SwiftUI
import Observation

@MainActor
@Observable
class SearchViewModel {
    enum SortMode: String, CaseIterable, Identifiable {
        case hot
        case featured
        case newest

        var id: String { rawValue }
        var title: String {
            switch self {
            case .hot: return "Hot"
            case .featured: return "Featured"
            case .newest: return "New"
            }
        }
    }

    var query: String = ""
    var selectedGenreSlug: String? = nil
    var selectedSort: SortMode = .newest
    var onlyHot = false
    var onlyFeatured = false
    var isLoading = false
    var errorMessage: String? = nil
    var genres: [Genre] = []
    var stories: [Story] = []
    var storyLibraryStatuses: [String: Set<String>] = [:]

    func loadInitial() async {
        async let genresTask = loadGenres()
        async let libraryTask = loadLibraryStatuses()
        _ = await (genresTask, libraryTask)
        await search()
    }

    func loadGenres() async {
        do {
            genres = try await NetworkService.shared.fetchGenres().filter { $0.active }
        } catch {
            // Keep Search usable even if genres fail
            genres = []
        }
    }

    func search() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await NetworkService.shared.fetchDiscoverStories(
                search: query.isEmpty ? nil : query,
                genre: selectedGenreSlug
            )
            stories = applyAdvancedFiltersAndSort(on: fetched)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func applyQueryAndSearch(_ newQuery: String) async {
        query = newQuery
        await search()
    }

    private func loadLibraryStatuses() async {
        do {
            storyLibraryStatuses = try await NetworkService.shared.fetchLibraryStatusMap()
        } catch {
            storyLibraryStatuses = [:]
        }
    }

    private func applyAdvancedFiltersAndSort(on list: [Story]) -> [Story] {
        var output = list
        if onlyHot {
            output = output.filter { $0.isHot }
        }
        if onlyFeatured {
            output = output.filter { $0.isFeatured }
        }
        switch selectedSort {
        case .hot:
            output.sort {
                if $0.isHot != $1.isHot { return $0.isHot && !$1.isHot }
                if $0.isFeatured != $1.isFeatured { return $0.isFeatured && !$1.isFeatured }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .featured:
            output.sort {
                if $0.isFeatured != $1.isFeatured { return $0.isFeatured && !$1.isFeatured }
                if $0.isHot != $1.isHot { return $0.isHot && !$1.isHot }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .newest:
            break
        }
        return output
    }
}

struct SearchTabView: View {
    @State private var viewModel = SearchViewModel()
    @State private var inputQuery = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mlBg.ignoresSafeArea()

                VStack(spacing: 14) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.mlSubtext)
                            TextField("Search stories...", text: $inputQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .foregroundStyle(Color.white)
                                .submitLabel(.search)
                                .focused($isSearchFieldFocused)
                            if !inputQuery.isEmpty {
                                Button {
                                    inputQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.mlSubtext)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.mlCard)
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(title: "All", isSelected: viewModel.selectedGenreSlug == nil) {
                                    viewModel.selectedGenreSlug = nil
                                    Task { await viewModel.search() }
                                }
                                ForEach(viewModel.genres) { genre in
                                    filterChip(title: genre.name, isSelected: viewModel.selectedGenreSlug == genre.slug) {
                                        viewModel.selectedGenreSlug = genre.slug
                                        Task { await viewModel.search() }
                                    }
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SearchViewModel.SortMode.allCases) { mode in
                                    filterChip(title: mode.title, isSelected: viewModel.selectedSort == mode) {
                                        viewModel.selectedSort = mode
                                        Task { await viewModel.search() }
                                    }
                                }
                                filterChip(title: "Only Hot", isSelected: viewModel.onlyHot) {
                                    viewModel.onlyHot.toggle()
                                    Task { await viewModel.search() }
                                }
                                filterChip(title: "Only Featured", isSelected: viewModel.onlyFeatured) {
                                    viewModel.onlyFeatured.toggle()
                                    Task { await viewModel.search() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    contentView
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadInitial()
                inputQuery = viewModel.query
            }
            .task(id: inputQuery) {
                // 400ms debounce — skip search if query unchanged from current
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, inputQuery != viewModel.query else { return }
                await viewModel.applyQueryAndSearch(inputQuery)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.stories.isEmpty {
            Spacer()
            ProgressView().tint(Color.mlPurple)
            Spacer()
        } else if let err = viewModel.errorMessage {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(Color.mlPink).font(.system(size: 28))
                Text(err).foregroundStyle(Color.mlSubtext).font(.system(size: 13)).multilineTextAlignment(.center)
                Button("Retry") { Task { await viewModel.search() } }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.mlPurple))
            }
            .padding(.horizontal, 20)
            Spacer()
        } else if viewModel.stories.isEmpty {
            Spacer()
            Text("No stories found")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mlSubtext)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.stories) { story in
                        NavigationLink(destination: StoryDetailView(story: story)) {
                            SearchStoryRow(
                                story: story,
                                statuses: viewModel.storyLibraryStatuses[story.id] ?? []
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { _ in
                        isSearchFieldFocused = false
                    }
            )
            .simultaneousGesture(TapGesture().onEnded {
                isSearchFieldFocused = false
            })
            .refreshable {
                await viewModel.search()
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.mlSubtext)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.mlPurple : Color.mlCard)
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
                )
        }
    }
}

private struct SearchStoryRow: View {
    let story: Story
    let statuses: Set<String>

    var body: some View {
        HStack(spacing: 12) {
            StoryCoverView(
                coverUrl: story.coverUrl,
                title: story.title,
                cornerRadius: 10,
                width: 62,
                height: 84
            )

            VStack(alignment: .leading, spacing: 6) {
                SearchLibraryStatusBadges(statuses: statuses)
                Text(story.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                if let desc = story.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text("\(story.totalEpisodes) eps")
                    Text("Free \(story.freeEpisodeCount)")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.mlSubtext.opacity(0.85))
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.mlCard)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

private struct SearchLibraryStatusBadges: View {
    let statuses: Set<String>

    private var orderedStatuses: [String] {
        ["saved", "history", "completed"].filter { statuses.contains($0) }
    }

    private func style(for status: String) -> (label: String, color: Color) {
        switch status {
        case "saved":
            return ("Saved", Color.mlPurple)
        case "history":
            return ("History", Color.mlSubtext)
        case "completed":
            return ("Completed", Color(red: 0.25, green: 0.85, blue: 0.55))
        default:
            return (status.capitalized, Color.mlSubtext)
        }
    }

    var body: some View {
        if orderedStatuses.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(orderedStatuses, id: \.self) { status in
                    let item = style(for: status)
                    Text(item.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(item.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(item.color.opacity(0.16)))
                        .overlay(Capsule().strokeBorder(item.color.opacity(0.28), lineWidth: 1))
                }
            }
        }
    }
}
