//
//  ContentView_macOS.swift
//  Example
//
//  macOS-specific implementation
//

#if os(macOS)
import SwiftUI
import AppKit
import MushafImad

struct ContentView_macOS: View {
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var reciterService: ReciterService
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                List {
                    Section("Quick Start") {
                        NavigationLink("Suras List") {
                            SuraList()
                                .environmentObject(reciterService)
                                .environmentObject(toastManager)
                        }
                        NavigationLink("Read the Mushaf") {
                            MushafReaderDemo()
                                .environmentObject(reciterService)
                                .environmentObject(toastManager)
                        }
                    }
                    
                    Section("Customization") {
                        NavigationLink("Override Colors & Images") {
                            CustomBrandingDemo()
                                .environmentObject(reciterService)
                                .environmentObject(toastManager)
                        }
                        NavigationLink("Inject Your Own Toasts") {
                            ToastDemo()
                                .environmentObject(toastManager)
                        }
                    }
                    
                    Section("Audio") {
                        NavigationLink("Audio Player UI") {
                            AudioPlayerDemo()
                                .environmentObject(reciterService)
                                .environmentObject(toastManager)
                        }
                        NavigationLink("Verse by Verse Playback") {
                            VerseByVerseDemo()
                                .environmentObject(reciterService)
                                .environmentObject(toastManager)
                        }
                    }
                    
                    Section("Helpful Links") {
                        Link("View README", destination: URL(string: "https://github.com/ibo2001/MushafImad")!)
                    }
                }
                .navigationTitle("MushafImad Examples")
                .listStyle(.sidebar)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            toastManager.show(
                                .success(message: "Triggered from the toolbar.")
                            )
                        } label: {
                            Label("Show Toast", systemImage: "sparkles")
                        }
                    }
                }
            } detail: {
                Text("Select an example from the sidebar")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        
            ToastOverlayView()
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

private struct SuraList: View {
    @State private var suras:[Chapter] = .init()
    @State private var navbarHidden:Bool = true
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Sura List")
                    .font(.title)
                    .padding()
                List(suras){sura in
                    NavigationLink {
                        MushafView(initialPage: sura.startPage, onPageTap: {
                            withAnimation {
                                navbarHidden.toggle()
                            }
                        })
                    } label: {
                        HStack {
                            Text("\(sura.number) - \(sura.displayTitle)")
                            Spacer()
                            Text("page (\(sura.startPage))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .task {
                if let result = RealmService.shared.getAllChapters() {
                    suras = Array(result)
                }
            }
        }
    }
}

private struct MushafReaderDemo: View {
    var body: some View {
        MushafView(initialPage: 1)
            .navigationTitle("Reader")
    }
}

private struct CustomBrandingDemo: View {
    @State private var useCustomBranding = true
    
    var body: some View {
        MushafView(initialPage: 2)
            .navigationTitle("Brand Overrides")
            .task {
                applyOverrides()
            }
            .onDisappear {
                MushafAssets.reset()
            }
            .onChange(of: useCustomBranding) {
                applyOverrides()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Toggle("Custom Branding", isOn: $useCustomBranding)
                        .toggleStyle(.switch)
                }
            }
    }
    
    private func applyOverrides() {
        guard useCustomBranding else {
            MushafAssets.reset()
            return
        }
        
        MushafAssets.configuration = MushafAssetConfiguration(
            colorProvider: { name in
                switch name {
                case "Brand 900": return Color.purple
                case "Brand 500": return Color.pink
                case "Brand 100": return Color.pink.opacity(0.25)
                case "Accent 500": return Color.teal
                case "Accent 100": return Color.teal.opacity(0.15)
                default: return nil
                }
            },
            imageProvider: { name in
                switch name {
                case "fasel":
                    return Image(systemName: "seal.fill")
                case "pagenumb":
                    return Image(systemName: "diamond.fill")
                case "suraNameBar":
                    return Image(systemName: "capsule.inset.filled")
                default:
                    return nil
                }
            }
        )
    }
}

private struct ToastDemo: View {
    @EnvironmentObject private var toastManager: ToastManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Use `ToastManager` anywhere in your app to show contextual feedback. The example app installs `ToastOverlayView` at the window level so toasts float above content.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Show Success Toast") {
                toastManager.show(
                    .success(message: "Verse bookmarked successfully!")
                )
            }
            .buttonStyle(.borderedProminent)
            
            Button("Show Warning Toast") {
                toastManager.show(
                    .warning(
                        message: "Network is offline. We'll retry downloads soon.",
                        action: .init(
                            title: "Retry Now",
                            icon: "arrow.triangle.2.circlepath",
                            handler: {}
                        )
                    )
                )
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
        .navigationTitle("Toast Overlay")
        .overlay(ToastOverlayView())
    }
}

private struct AudioPlayerDemo: View {
    @EnvironmentObject private var reciterService: ReciterService
    @EnvironmentObject private var toastManager: ToastManager
    @State private var cachedChapter: Chapter?
    @State private var readerViewModel = MushafView.ViewModel()
    
    var body: some View {
        Group {
            if let chapter = cachedChapter {
                PlayerViewUI(chapter: chapter, viewModel: readerViewModel)
                    .navigationTitle("Audio Player")
                    .environmentObject(reciterService)
                    .environmentObject(toastManager)
                    .task {
                        await readerViewModel.initializePageView(initialPage: chapter.startPage)
                    }
            } else {
                ProgressView("Loading chapter data...")
            }
        }
        .task {
            await readerViewModel.loadData()
            if cachedChapter == nil {
                cachedChapter = readerViewModel.chapters.first
            }
        }
    }
}

private struct VerseByVerseDemo: View {
    @EnvironmentObject private var reciterService: ReciterService
    @EnvironmentObject private var toastManager: ToastManager
    @State private var highlightedVerse: Verse?
    @State private var showPlayerSheet = false
    @StateObject private var playerViewModel = QuranPlayerViewModel()
    @State private var currentChapterNumber: Int?
    
    var body: some View {
        MushafView(
            initialPage: highlightedVerse?.page1441?.number ?? 1,
            highlightedVerse: $highlightedVerse,
            onVerseLongPress: handleLongPress(_:))
        .navigationTitle("Verse by Verse")
        .sheet(isPresented: $showPlayerSheet) {
            VersePlaybackSheet(playerViewModel: playerViewModel, highlightedVerse: $highlightedVerse)
                .environmentObject(reciterService)
                .frame(minWidth: 600, minHeight: 500)
        }
        .onChange(of: playerViewModel.currentVerseNumber) { _, newValue in
            guard let verseNumber = newValue else { return }
            let chapterNumber = currentChapterNumber ?? playerViewModel.chapterNumber
            guard chapterNumber > 0 else { return }
            if let verse = RealmService.shared.getVerse(chapterNumber: chapterNumber, verseNumber: verseNumber) {
                highlightedVerse = verse
            }
        }
    }
    
    private func handleLongPress(_ verse: Verse) {
        guard !reciterService.isLoading,
              let reciter = reciterService.selectedReciter,
              let baseURL = reciter.audioBaseURL,
              let chapter = verse.chapter ?? RealmService.shared.getChapter(number: verse.chapterNumber) else {
            toastManager.show(
                .warning(message: "Audio playback is not ready yet. Please wait for reciters to load.")
            )
            return
        }
        
        highlightedVerse = verse
        currentChapterNumber = chapter.number
        
        playerViewModel.configureIfNeeded(
            baseURL: baseURL,
            chapterNumber: chapter.number,
            chapterName: chapter.displayTitle,
            reciterName: reciter.displayName,
            reciterId: reciter.id
        )
        playerViewModel.startIfNeeded(autoPlay: false)
        playerViewModel.setPreviewVerse(verse.number)
        _ = playerViewModel.seekToVerse(verse.number)
        showPlayerSheet = true
    }
}

private struct VersePlaybackSheet: View {
    @ObservedObject var playerViewModel: QuranPlayerViewModel
    @Binding var highlightedVerse: Verse?
    
    var body: some View {
        VStack(spacing: 16) {
            if let verse = highlightedVerse,
               let chapter = verse.chapter ?? RealmService.shared.getChapter(number: verse.chapterNumber) {
                VStack(spacing: 8) {
                    Text("\(chapter.displayTitle) • Ayah \(verse.number)")
                        .font(.headline)
                    Text(verse.text)
                        .font(.system(size: 20))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.brand100.opacity(0.35))
                        )
                }
                .padding(.top)
            }
            
            QuranPlayer(
                viewModel: playerViewModel,
                autoStart: false,
                onPreviousVerse: {
                    _ = playerViewModel.seekToPreviousVerse()
                },
                onNextVerse: {
                    _ = playerViewModel.seekToNextVerse()
                }
            )
            .environment(\.layoutDirection, .rightToLeft)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle("Verse Player")
    }
}
#endif

