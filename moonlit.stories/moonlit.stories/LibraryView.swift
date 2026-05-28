import SwiftUI
import Observation

@MainActor
@Observable
class LibraryViewModel {
    enum LibraryType: String, CaseIterable, Identifiable {
        case saved
        case history
        case completed

        var id: String { rawValue }
        var title: String {
            switch self {
            case .saved: return "Saved"
            case .history: return "History"
            case .completed: return "Completed"
            }
        }
    }

    var selectedType: LibraryType = .saved
    var isLoading = false
    var errorMessage: String? = nil
    var items: [LibraryItem] = []

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            items = try await NetworkService.shared.fetchLibrary(type: selectedType.rawValue)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func removeSaved(storyID: String) async {
        do {
            try await NetworkService.shared.removeFromLibrary(storyID: storyID, type: "saved")
            items.removeAll { $0.storyID == storyID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LibraryTabView: View {
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mlBg.ignoresSafeArea()

                VStack(spacing: 14) {
                    Picker("Library Type", selection: $viewModel.selectedType) {
                        ForEach(LibraryViewModel.LibraryType.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: viewModel.selectedType) { _, _ in
                        Task { await viewModel.load() }
                    }

                    contentView
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            Spacer()
            ProgressView().tint(Color.mlPurple)
            Spacer()
        } else if let err = viewModel.errorMessage {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.mlPink)
                Text(err)
                    .foregroundStyle(Color.mlSubtext)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await viewModel.load() } }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.mlPurple))
            }
            .padding(.horizontal, 20)
            Spacer()
        } else if viewModel.items.isEmpty {
            Spacer()
            Text("No stories in this list")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mlSubtext)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items) { item in
                        NavigationLink(
                            destination: StoryDetailView(
                                story: Story(
                                    id: item.storyID,
                                    title: item.title,
                                    slug: item.slug,
                                    description: item.description.isEmpty ? nil : item.description,
                                    hook: nil,
                                    coverUrl: item.coverURL.isEmpty ? nil : item.coverURL,
                                    freeEpisodeCount: 0,
                                    defaultCoinPrice: 0,
                                    totalEpisodes: 0,
                                    isFeatured: false,
                                    isHot: false,
                                    isEditorPick: false,
                                    genres: nil,
                                    moods: nil
                                )
                            )
                        ) {
                            LibraryStoryRow(item: item, selectedType: viewModel.selectedType)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if viewModel.selectedType == .saved {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeSaved(storyID: item.storyID) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
}

private struct LibraryStoryRow: View {
    let item: LibraryItem
    let selectedType: LibraryViewModel.LibraryType

    var body: some View {
        HStack(spacing: 12) {
            if let url = URL(string: item.coverURL), !item.coverURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color.mlCard, Color.mlPurpleDim], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .frame(width: 62, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color.mlCard, Color.mlPurpleDim], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 62, height: 84)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                        .lineLimit(2)
                }
                Text(selectedType.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mlPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.mlPurple.opacity(0.16)))
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
