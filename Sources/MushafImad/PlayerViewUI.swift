//
//  SwiftUIView.swift
//  MushafImadSPM
//
//  Created by Ibrahim Qraiqe on 12/11/2025.
//

import SwiftUI

public struct PlayerViewUI: View {
    @EnvironmentObject private var reciterService: ReciterService
    @StateObject private var playerViewModel = QuranPlayerViewModel()

    public let chapter: Chapter
    public let viewModel: MushafView.ViewModel

    public init(chapter: Chapter, viewModel: MushafView.ViewModel = MushafView.ViewModel()) {
        self.chapter = chapter
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if !reciterService.isLoading,
               let reciter = reciterService.selectedReciter,
               let baseURL = reciter.audioBaseURL {
                QuranPlayer(
                    viewModel: playerViewModel,
                    onPreviousVerse: {
                        if !playerViewModel.seekToPreviousVerse() {
                            guard let target = viewModel.previousChapter(from: playerViewModel.chapterNumber) else { return }
                            navigateToChapter(target, baseURL: baseURL, reciter: reciter, previewVerse: max(1, target.versesCount))
                        }
                    },
                    onNextVerse: {
                        if !playerViewModel.seekToNextVerse() {
                            guard let target = viewModel.nextChapter(from: playerViewModel.chapterNumber) else { return }
                            navigateToChapter(target, baseURL: baseURL, reciter: reciter, previewVerse: 1)
                        }
                    },
                    onPreviousChapter: {
                        guard let target = viewModel.previousChapter(from: playerViewModel.chapterNumber) else { return }
                        navigateToChapter(target, baseURL: baseURL, reciter: reciter, previewVerse: max(1, target.versesCount))
                    },
                    onNextChapter: {
                        guard let target = viewModel.nextChapter(from: playerViewModel.chapterNumber) else { return }
                        navigateToChapter(target, baseURL: baseURL, reciter: reciter, previewVerse: 1)
                    }
                )
                .id(chapter.number)
                .onAppear {
                    // Configure the player with the current reciter and chapter
                    playerViewModel.configureIfNeeded(
                        baseURL: baseURL,
                        chapterNumber: chapter.number,
                        chapterName: chapter.displayTitle,
                        reciterName: reciter.displayName,
                        reciterId: reciter.id,
                        timingSource: reciter.timingSource
                    )
                }
            } else {
                // Loading state while ReciterService initializes
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading reciters...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .onAppear {
            QuranPlayerCoordinator.shared.registerActivePlayer(playerViewModel)
        }
        .onDisappear {
            QuranPlayerCoordinator.shared.unregisterActivePlayer(playerViewModel)
        }
    }

    // MARK: - Private Helpers

    private func navigateToChapter(
        _ target: Chapter,
        baseURL: URL,
        reciter: ReciterService.ReciterInfo,
        previewVerse: Int
    ) {
        let wasPlaying = playerViewModel.isPlaying
        withAnimation { viewModel.navigateToChapterAndPrepareScroll(target) }
        playerViewModel.configureIfNeeded(
            baseURL: baseURL,
            chapterNumber: target.number,
            chapterName: target.displayTitle,
            reciterName: reciter.displayName,
            reciterId: reciter.id,
            timingSource: reciter.timingSource
        )
        playerViewModel.startIfNeeded(autoPlay: wasPlaying)
        if !wasPlaying {
            playerViewModel.setPreviewVerse(previewVerse)
        }
    }
}
