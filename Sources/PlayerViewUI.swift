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
        if !reciterService.isLoading,
           let reciter = reciterService.selectedReciter,
           let baseURL = reciter.audioBaseURL {
            QuranPlayer(
                viewModel: playerViewModel,
                onPreviousVerse: {
                    let moved = playerViewModel.seekToPreviousVerse()
                    if !moved {
                        guard let target = viewModel.previousChapter(from: playerViewModel.chapterNumber) else { return }
                        let wasPlaying = playerViewModel.isPlaying
                        withAnimation {
                            viewModel.navigateToChapterAndPrepareScroll(target)
                        }
                        playerViewModel.configureIfNeeded(
                            baseURL: baseURL,
                            chapterNumber: target.number,
                            chapterName: target.title,
                            reciterName: reciter.displayName,
                            reciterId: reciter.id
                        )
                        playerViewModel.startIfNeeded(autoPlay: wasPlaying)
                        if !wasPlaying {
                            let lastVerse = max(1, target.versesCount)
                            playerViewModel.setPreviewVerse(lastVerse)
                        }
                    }
                },
                onNextVerse: {
                    let moved = playerViewModel.seekToNextVerse()
                    if !moved {
                        guard let target = viewModel.nextChapter(from: playerViewModel.chapterNumber) else { return }
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
                            playerViewModel.setPreviewVerse(1)
                        }
                    }
                },
                onPreviousChapter: {
                    guard let target = viewModel.previousChapter(from: playerViewModel.chapterNumber) else { return }
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
                },
                onNextChapter: {
                    guard let target = viewModel.nextChapter(from: playerViewModel.chapterNumber) else { return }
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
                        playerViewModel.setPreviewVerse(1)
                    }
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
}
