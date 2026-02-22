//
//  MushafView.swift
//  Mushaf
//
//  Created by Ibrahim Qraiqe on 26/10/2025.
//

import SwiftUI
import SwiftData

/// User-selectable background palettes that match the reading mood.
public enum ReadingTheme: String, CaseIterable {
    case comfortable
    case calm
    case night
    case white
    
    public var color: Color {
        switch self {
        case .comfortable:
            return Color(hex: "#E4EFD9")
        case .calm:
            return Color(hex: "#E0F1EA")
        case .night:
            return Color(hex: "#2F352F")
        case .white:
            return Color(hex: "#FFFFFF")
        }
    }
    
    public var title: String {
        switch self {
        case .comfortable:
            String(localized: "Comfy")
        case .calm:
            String(localized: "Calm")
        case .night:
            String(localized: "Night")
        case .white:
            String(localized: "White")
        }
    }
}

/// Layout options that control how Mushaf pages are paged through.
public enum ScrollingMode: String, CaseIterable {
    case automatic
    case horizontal
    
    public var title: String {
        switch self {
        case .automatic:
            String(localized: "Automatic")
        case .horizontal:
            String(localized: "Horizontal")
        }
    }
}


/// The main Mushaf reader surface that stitches together page rendering,
/// navigation and audio playback highlights.
public struct MushafView: View {
    public let initialPage: Int?
    private let staticHighlightedVerse: Verse?
    private let highlightedVerseBinding: Binding<Verse?>?
    private let externalLongPressHandler: ((Verse) -> Void)?
    private let externalPageTapHandler: (() -> Void)?
    /// When false, the view does not auto-register its internal player with
    /// QuranPlayerCoordinator. Set to false when the embedding view manages
    /// its own player and handles coordinator registration itself (e.g. VerseByVerseDemo),
    /// to avoid transient dual-registration overwriting the outer player.
    private let registersPlayerWithCoordinator: Bool
    
    @State private var viewModel = ViewModel()
    @StateObject private var playerViewModel = QuranPlayerViewModel()
    @EnvironmentObject private var reciterService: ReciterService
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var playingVerse: Verse? = nil
    
    @AppStorage("reading_theme") private var readingTheme: ReadingTheme = .white
    @AppStorage("scrolling_mode") private var scrollingMode: ScrollingMode = .horizontal
    
    
    public init(initialPage: Int? = nil,
                highlightedVerse: Verse? = nil,
                registerPlayerWithCoordinator: Bool = true,
                onVerseLongPress: ((Verse) -> Void)? = nil,
                onPageTap: (() -> Void)? = nil
    ) {
        self.initialPage = initialPage
        self.staticHighlightedVerse = highlightedVerse
        self.highlightedVerseBinding = nil
        self.registersPlayerWithCoordinator = registerPlayerWithCoordinator
        self.externalLongPressHandler = onVerseLongPress
        self.externalPageTapHandler = onPageTap
    }

    public init(initialPage: Int? = nil,
                highlightedVerse: Binding<Verse?>,
                registerPlayerWithCoordinator: Bool = true,
                onVerseLongPress: ((Verse) -> Void)? = nil,
                onPageTap: (() -> Void)? = nil
    ) {
        self.initialPage = initialPage
        self.highlightedVerseBinding = highlightedVerse
        self.staticHighlightedVerse = nil
        self.registersPlayerWithCoordinator = registerPlayerWithCoordinator
        self.externalLongPressHandler = onVerseLongPress
        self.externalPageTapHandler = onPageTap
    }
    
    public var body: some View {
        ZStack {
            readingTheme.color.ignoresSafeArea()
            if viewModel.isLoading || !viewModel.isInitialPageReady {
                LoadingView(message: viewModel.isLoading ? String(localized: "Loading Quran data...") : String(localized: "Preparing page..."))
            } else {
                pageView
                    .foregroundStyle(.naturalBlack)
                
            }
        }
        .environment(\.colorScheme, readingTheme == .night ? .dark : .light)
        .opacity(viewModel.contentOpacity)
        .onChange(of: viewModel.scrollPosition) { oldPage, newPage in
            guard let newPage = newPage else { return }
            
            Task {
                await viewModel.handlePageChange(from: oldPage, to: newPage)
            }
        }
        .task {
            await viewModel.initializePageView(initialPage: initialPage)
        }
        .onAppear {
            if registersPlayerWithCoordinator {
                QuranPlayerCoordinator.shared.registerActivePlayer(playerViewModel)
            }
        }
        .onDisappear {
            if registersPlayerWithCoordinator {
                QuranPlayerCoordinator.shared.unregisterActivePlayer(playerViewModel)
            }
        }
        .onChange(of: playerViewModel.playbackState) { oldState, newState in
            // Clear highlighting when playback stops
            switch newState {
            case .idle:
                playingVerse = nil
            case .finished:
                if !reciterService.isLoading,
                   let reciter = reciterService.selectedReciter,
                   let baseURL = reciter.audioBaseURL,
                   let target = viewModel.nextChapter(from: playerViewModel.chapterNumber) {
                    withAnimation {
                        viewModel.navigateToChapterAndPrepareScroll(target)
                    }
                    playerViewModel.configureIfNeeded(
                        baseURL: baseURL,
                        chapterNumber: target.number,
                        chapterName: target.displayTitle,
                        reciterName: reciter.displayName,
                        reciterId: reciter.id
                    )
                    playerViewModel.startIfNeeded(autoPlay: true)
                }
                
            default:
                break
            }
        }
    }

    // MARK: - View Components
    @ViewBuilder
    private var pageView: some View {
        let currentHighlight = playingVerse
            ?? highlightedVerseBinding?.wrappedValue
            ?? staticHighlightedVerse
        
        Group {
            if scrollingMode == .horizontal {
                horizontalPageView(currentHighlight: currentHighlight)
            } else {
                verticalPageView(currentHighlight: currentHighlight)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    public func horizontalPageView(currentHighlight: Verse?) -> some View {
        TabView(selection: $viewModel.scrollPosition) {
            ForEach(1...604, id: \.self) { pageNumber in
                pageContent(for: pageNumber, highlight: currentHighlight)
                    .tag(pageNumber)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        #endif
    }
    
    public func verticalPageView(currentHighlight: Verse?) -> some View {
        GeometryReader { geometry in
            let scrollBinding = Binding(
                get: { viewModel.scrollPosition },
                set: { newValue in
                    guard viewModel.scrollPosition != newValue else { return }
                    viewModel.scrollPosition = newValue
                }
            )
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(1...604, id: \.self) { pageNumber in
                        pageContent(for: pageNumber, highlight: currentHighlight)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .padding(.top,geometry.safeAreaInsets.top)
                            .padding(.bottom,geometry.safeAreaInsets.bottom)
                            .id(pageNumber)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: scrollBinding, anchor: .center)
            .ignoresSafeArea(.container, edges: [.top, .bottom])
        }
    }
    
    public func pageContent(for pageNumber: Int, highlight: Verse?) -> some View {
        PageContainer(
            pageNumber: pageNumber,
            highlightedVerse: highlight,
            selectedVerse: $viewModel.selectedVerse,
            onVerseLongPress: { verse in
                viewModel.selectedVerse = nil

                if let handler = externalLongPressHandler {
                    highlightedVerseBinding?.wrappedValue = nil
                    handler(verse)
                } else {
                    viewModel.showVerseDetails(verse)
                    highlightedVerseBinding?.wrappedValue = verse
                }
            },
            onTap: {
                if let action = externalPageTapHandler {
                    action()
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MushafView(initialPage: 2, highlightedVerse: nil)
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    .environmentObject(ReciterService.shared)
    .environmentObject(ToastManager())
    .environment(\.layoutDirection, .leftToRight)
    //.environment(\.locale, Locale(identifier: "ar_SA"))
}

