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
    @ObservedObject private var playerCoordinator = QuranPlayerCoordinator.shared
    @StateObject private var eyeTrackingCoordinator = EyeTrackingCoordinator()
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var playingVerse: Verse? = nil
    @State private var pageContentFrame: CGRect = .zero
#if canImport(UIKit)
    @StateObject private var tiltManager = TiltScrollManager()
#endif
    @AppStorage("reading_theme") private var readingTheme: ReadingTheme = .white
    @AppStorage("scrolling_mode") private var scrollingMode: ScrollingMode = .horizontal
    @AppStorage("display_mode") private var displayMode: DisplayMode = .text
    @AppStorage("text_font_size") private var textFontSize: Double = 24.0
    @State private var textModeInitialChapter: Int = 1
    @State private var showEyeTrackingSettings: Bool = false


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
            
            // Eye tracking overlay (experimental)
            if eyeTrackingCoordinator.isEnabled && eyeTrackingCoordinator.showOverlay {
                EyeTrackingOverlayView(
                    tracker: eyeTrackingCoordinator.progressTracker,
                    currentGaze: eyeTrackingCoordinator.currentGaze,
                    showDebugInfo: eyeTrackingCoordinator.showDebugInfo,
                    trackingState: eyeTrackingCoordinator.trackingState
                )
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
                eyeTrackingCoordinator.deactivate(context: modelContext)
                pageContentFrame = .zero
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
        .onAppear {
#if canImport(UIKit)
            tiltManager.activate()
#endif
        }
        .onDisappear {
#if canImport(UIKit)
            tiltManager.deactivate()
#endif
            eyeTrackingCoordinator.deactivate(context: modelContext)
        }
        .sheet(isPresented: $showEyeTrackingSettings) {
            EyeTrackingSettingsView(coordinator: eyeTrackingCoordinator)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showEyeTrackingSettings) { _, isShowing in
            if isShowing {
                eyeTrackingCoordinator.pause()
            } else if eyeTrackingCoordinator.isEnabled {
                eyeTrackingCoordinator.resume()
            }
        }
        // Only follow playback when the host has not taken ownership of the highlight;
        // a host-supplied binding or a static highlight stays authoritative exactly as before.
        .onChange(of: playerCoordinator.nowPlaying) { _, nowPlaying in
            followNowPlaying(nowPlaying)
        }
        .onAppear {
            followNowPlaying(playerCoordinator.nowPlaying)
        }
        // A host that drives playback owns its own player and highlights through this binding,
        // so this is the path that carries recitation into the reader.
        .onChange(of: highlightedVerseBinding?.wrappedValue?.page1441?.number) { _, _ in
            withAnimation { viewModel.followVerse(highlightedVerseBinding?.wrappedValue) }
        }
    }

    // MARK: - Playback Following

    /// Follow the coordinator's now-playing verse, unless the host owns the highlight
    /// (via a binding or a static verse passed to the initializer). Shared by the
    /// `.onChange` transition handler and the `.onAppear` seed so they can't drift apart.
    private func followNowPlaying(_ nowPlaying: QuranPlayerCoordinator.NowPlaying?) {
        guard highlightedVerseBinding == nil, staticHighlightedVerse == nil else { return }
        guard let nowPlaying else { playingVerse = nil; return }
        let isOpeningBasmala = nowPlaying.verseNumber < 1
        guard let verse = RealmService.shared.getVerse(
            chapterNumber: nowPlaying.chapterNumber,
            verseNumber: max(nowPlaying.verseNumber, 1)
        ) else { return }
        playingVerse = isOpeningBasmala ? nil : verse
        withAnimation { viewModel.followVerse(verse) }
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
        // Eye tracking settings button (experimental)
        Button {
            showEyeTrackingSettings = true
        } label: {
            Image(systemName: "eye")
                .symbolEffect(.pulse, isActive: eyeTrackingCoordinator.isEnabled)
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
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                        pageContentFrame = frame
                        // Only activate if this is the currently-visible page
                        if eyeTrackingCoordinator.isEnabled && viewModel.scrollPosition == pageNumber {
                            activateTracking(for: pageNumber, frame: frame)
                        }
                    }
                    .onChange(of: eyeTrackingCoordinator.isEnabled) { _, enabled in
                        // Re-activate when the user enables tracking while this page is visible
                        if enabled {
                            if viewModel.scrollPosition == pageNumber {
                                activateTracking(for: pageNumber, frame: geo.frame(in: .global))
                            }
                        } else {
                            eyeTrackingCoordinator.deactivate(context: modelContext)
                        }
                    }
                    .onChange(of: viewModel.scrollPosition) { _, newPage in
                        // Activate when this page becomes the active scroll position
                        if eyeTrackingCoordinator.isEnabled && newPage == pageNumber {
                            activateTracking(for: pageNumber, frame: geo.frame(in: .global))
                        }
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        pageContentFrame = newFrame
                        // Only update geometry for the current page to avoid stale overrides
                        if eyeTrackingCoordinator.isEnabled && viewModel.scrollPosition == pageNumber {
                            eyeTrackingCoordinator.updateGeometry(frame: newFrame)
                        }
                    }
            }
        )
    }

    private func activateTracking(for pageNumber: Int, frame: CGRect) {
        let verses = RealmService.shared.getVersesForPage(pageNumber)
        eyeTrackingCoordinator.activate(
            pageNumber: pageNumber,
            verses: verses,
            pageFrame: frame,
            onPageCompleted: {
                if pageNumber < 604 {
                    withAnimation {
                        viewModel.scrollPosition = pageNumber + 1
                    }
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
