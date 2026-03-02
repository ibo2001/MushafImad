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

/// Controls whether the reader shows image-based pages or text-based verses.
public enum DisplayMode: String, CaseIterable {
    case image
    case text
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

    @State private var viewModel = ViewModel()
    @StateObject private var playerViewModel = QuranPlayerViewModel()
    @EnvironmentObject private var reciterService: ReciterService
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var playingVerse: Verse? = nil
#if canImport(UIKit)
    @StateObject private var tiltManager = TiltScrollManager()
#endif
    @AppStorage("reading_theme") private var readingTheme: ReadingTheme = .white
    @AppStorage("scrolling_mode") private var scrollingMode: ScrollingMode = .horizontal
    @AppStorage("display_mode") private var displayMode: DisplayMode = .text
    @AppStorage("text_font_size") private var textFontSize: Double = 24.0
    @State private var textModeInitialChapter: Int = 1


    public init(initialPage: Int? = nil,
                highlightedVerse: Verse? = nil,
                onVerseLongPress: ((Verse) -> Void)? = nil,
                onPageTap: (() -> Void)? = nil
    ) {
        self.initialPage = initialPage
        self.staticHighlightedVerse = highlightedVerse
        self.highlightedVerseBinding = nil
        self.externalLongPressHandler = onVerseLongPress
        self.externalPageTapHandler = onPageTap
    }

    public init(initialPage: Int? = nil,
                highlightedVerse: Binding<Verse?>,
                onVerseLongPress: ((Verse) -> Void)? = nil,
                onPageTap: (() -> Void)? = nil
    ) {
        self.initialPage = initialPage
        self.highlightedVerseBinding = highlightedVerse
        self.staticHighlightedVerse = nil
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
        .overlay(alignment: .bottom) {
            if let verse = viewModel.selectedVerse, externalLongPressHandler == nil {
                verseActionBar(for: verse)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedVerse?.verseID)
        .sheet(isPresented: $viewModel.showTafsir) {
            if let verse = viewModel.tafsirVerse {
                TafseerView(
                    surahId: verse.chapterNumber,
                    ayahId: verse.number,
                    surahName: verse.chapter?.arabicTitle ?? ""
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
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
            if displayMode == .text {
                let page = viewModel.scrollPosition ?? initialPage ?? 1
                textModeInitialChapter = RealmService.shared.getChapterForPage(page)?.number ?? 1
            }
        }
        .onChange(of: displayMode) { _, newMode in
            if newMode == .text {
                let page = viewModel.scrollPosition ?? initialPage ?? 1
                textModeInitialChapter = RealmService.shared.getChapterForPage(page)?.number ?? 1
            }
        }
        .toolbar {
            #if os(iOS) || os(visionOS)
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarButtons
            }
            #else
            ToolbarItemGroup(placement: .automatic) {
                toolbarButtons
            }
            #endif
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
                        reciterId: reciter.id,
                        timingSource: reciter.timingSource
                    )
                    playerViewModel.startIfNeeded(autoPlay: true)
                }

            default:
                break
            }
        }
        .onAppear {
#if canImport(UIKit)
            tiltManager.activate()
#endif
        }
        .onDisappear {
#if canImport(UIKit)
            tiltManager.deactivate()
#endif
        }
    }
    // MARK: - Verse Action Bar

    @ViewBuilder
    private func verseActionBar(for verse: Verse) -> some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 12) {
                Button {
                    viewModel.tafsirVerse = verse
                    viewModel.selectedVerse = nil
                    viewModel.showTafsir = true
                } label: {
                    Label(
                        String(localized: "تفسير"),
                        systemImage: "text.book.closed.fill"
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.clearSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - View Components
    @ViewBuilder
    private var toolbarButtons: some View {
        if displayMode == .text {
            Menu {
                ForEach([16.0, 20.0, 24.0, 28.0, 32.0, 36.0], id: \.self) { size in
                    Button {
                        textFontSize = size
                    } label: {
                        if abs(textFontSize - size) < 0.5 {
                            Label("\(Int(size))pt", systemImage: "checkmark")
                        } else {
                            Text("\(Int(size))pt")
                        }
                    }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
        }
        Button {
            displayMode = (displayMode == .image) ? .text : .image
        } label: {
            Image(systemName: displayMode == .image ? "text.justify.leading" : "book.pages")
        }
    }

    @ViewBuilder
    private var pageView: some View {
        let currentHighlight = playingVerse
        ?? highlightedVerseBinding?.wrappedValue
        ?? staticHighlightedVerse
        
        Group {
            if displayMode == .text {
                MushafTextView(
                    initialChapter: textModeInitialChapter,
                    highlightedVerse: currentHighlight,
                    selectedVerse: $viewModel.selectedVerse,
                    onVerseLongPress: { verse in
                        if let handler = externalLongPressHandler {
                            viewModel.selectedVerse = nil
                            highlightedVerseBinding?.wrappedValue = nil
                            handler(verse)
                        } else {
                            viewModel.showVerseDetails(verse)
                            highlightedVerseBinding?.wrappedValue = verse
                        }
                    },
                    fontSize: textFontSize
                )
#if canImport(UIKit)
                .background(
                    ScrollViewIntrospector(axisHint: .vertical) { scrollView in
                        tiltManager.setTiltProfile(.textContinuous)
                        tiltManager.setScrollAxis(.vertical)
                        tiltManager.setScrollView(scrollView)
                    }
                )
#endif
            } else if scrollingMode == .horizontal {
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
#if canImport(UIKit)
        .background(
            ScrollViewIntrospector(axisHint: .horizontal, prefersPaging: true) { scrollView in
                tiltManager.setTiltProfile(.defaultPaged)
                tiltManager.setScrollAxis(.horizontal)
                tiltManager.setScrollView(scrollView)
            }
        )
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
#if canImport(UIKit)
                .background(
                    ScrollViewIntrospector(axisHint: .vertical) { scrollView in
                        tiltManager.setTiltProfile(.defaultPaged)
                        tiltManager.setScrollAxis(.vertical)
                        tiltManager.setScrollView(scrollView)
                    }
                )
#endif
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
