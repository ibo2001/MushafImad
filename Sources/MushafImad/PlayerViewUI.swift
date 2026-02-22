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
<<<<<<< HEAD
                        let wasPlaying = playerViewModel.isPlaying
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
                        playerViewModel.startIfNeeded(autoPlay: wasPlaying)
                        if !wasPlaying {
                            let lastVerse = max(1, target.versesCount)
                            playerViewModel.setPreviewVerse(lastVerse)
                        }
=======
                        navigateToChapter(target, baseURL: baseURL, reciter: reciter, previewVerse: max(1, target.versesCount))
>>>>>>> 3953433bb2ad9c75ca63b83df5cc753e30767912
                    },
                    onNextChapter: {
                        guard let target = viewModel.nextChapter(from: playerViewModel.chapterNumber) else { return }
                        navigateToChapter(target, baseURL: baseURL, reciter: reciter, previewVerse: 1)
                    }
                )
                .id(chapter.number)
                .onAppear {
<<<<<<< HEAD
                    // Configure the player with the current reciter and chapter
=======
>>>>>>> 3953433bb2ad9c75ca63b83df5cc753e30767912
                    playerViewModel.configureIfNeeded(
                        baseURL: baseURL,
                        chapterNumber: chapter.number,
                        chapterName: chapter.displayTitle,
                        reciterName: reciter.displayName,
                        reciterId: reciter.id
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
<<<<<<< HEAD
=======
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
            reciterId: reciter.id
        )
        playerViewModel.startIfNeeded(autoPlay: wasPlaying)
        if !wasPlaying {
            playerViewModel.setPreviewVerse(previewVerse)
>>>>>>> 3953433bb2ad9c75ca63b83df5cc753e30767912
        }
    }
}
