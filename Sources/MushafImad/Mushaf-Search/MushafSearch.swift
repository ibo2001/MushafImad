import SwiftUI

enum SearchRow: Identifiable {
    case chapter(Chapter)
    case verse(Verse)

    var id: String {
        switch self {
        case .chapter(let chapter):
            return "chapter-\(chapter.id)"
        case .verse(let verse):
            return "verse-\(verse.id)"
        }
    }
}

enum ViewState {
    case idle
    case loading
    case data([SearchRow])
}

@MainActor
class MushafSearchViewModel: ObservableObject {
    @Published var viewState: ViewState = .idle
    @Published var query: String = ""
    private var searchTask: Task<Void, Never>? = nil
    private var service: RealmService

    init(service: RealmService) {
        self.service = service
    }

    func searchChaptersAndVerses() {
        guard !query.isEmpty else {
            searchTask?.cancel()
            searchTask = nil
            viewState = .idle
            return
        }

        searchTask?.cancel()
        searchTask = nil

        searchTask = Task { [weak self] in
            guard let self = self else { return }
            guard !Task.isCancelled else { return }

            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300 millisec
            } catch {
                return // task cancelled
            }

            guard !Task.isCancelled else { return }

            viewState = .loading
            let chapters = service.searchChapters(query: query)
            let verses = service.searchVerses(query: query)
            var rows: [SearchRow] = []
            rows.append(contentsOf: chapters.map { SearchRow.chapter($0) })
            rows.append(contentsOf: verses.map { SearchRow.verse($0) })

            // Note: Prioritize chapters over verses as chapters count will always be less than verses results.
            viewState = .data(rows)
        }
    }
}

public struct MushafSearch: View {
    @StateObject private var viewModel = MushafSearchViewModel(service: RealmService.shared)

    public init() {}

    public var body: some View {
        VStack {
            switch viewModel.viewState {
            case .idle:
                Text("Start typing to search chapters and verses")
            case .data(let rows):
                if rows.isEmpty {
                    Text("No results found for \"\(viewModel.query)\"")
                } else {
                    List(rows, id: \.id) { row in
                        switch row {
                        case .chapter(let chapter): ChapterResultRow(chapter: chapter)
                        case .verse(let verse): VerseResultRow(verse: verse)
                        }
                    }
                }
            case .loading:
                ProgressView()
            }
        }
        .searchable(text: $viewModel.query, prompt: "Search Al-Baqarah, Al-Hamdu...")
        .task(id: viewModel.query) {
            viewModel.searchChaptersAndVerses()
        }
    }
}

struct VerseResultRow: View {
    let verse: Verse
    @State private var navbarHidden: Bool = true

    var body: some View {
        NavigationLink {
            MushafView(initialPage: verse.page1441?.number, highlightedVerse: verse, onPageTap: {
                withAnimation {
                    navbarHidden.toggle()
                }
            })
            #if os(iOS)
            .toolbar(navbarHidden ? .hidden : .visible, for: .navigationBar)
            #endif
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(verse.text)
                    .font(.body)
                    .lineLimit(2)
                HStack {
                    if let ch = verse.chapter?.displayTitle {
                        Text(ch)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("#\(verse.number)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ChapterResultRow: View {
    let chapter: Chapter
    @State private var navbarHidden: Bool = true

    var body: some View {
        NavigationLink {
            MushafView(initialPage: chapter.startPage, onPageTap: {
                withAnimation {
                    navbarHidden.toggle()
                }
            })
            #if os(iOS)
            .toolbar(navbarHidden ? .hidden : .visible, for: .navigationBar)
            #endif
        } label: {
            HStack {
                Text(chapter.displayTitle)
                    .font(.body)
                Spacer()
                Text("Chapter")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
