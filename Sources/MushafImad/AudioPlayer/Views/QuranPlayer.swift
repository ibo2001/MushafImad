//
//  QuranPlayer.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 02/11/2025.
//

import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct QuranPlayer: View {
    @ObservedObject public var viewModel: QuranPlayerViewModel
    @EnvironmentObject private var reciterService: ReciterService
    @State private var showReciterPicker = false

    private let onPreviousVerse: (() -> Void)?
    private let onNextVerse:   (() -> Void)?
    private let onPreviousChapter: (() -> Void)?
    private let onNextChapter: (() -> Void)?
    private let accentColor = Color(hex: "#2D7F6E")
    private let autoStart: Bool

    public init(
        viewModel: QuranPlayerViewModel,
        autoStart: Bool = true,
        onPreviousVerse:   (() -> Void)? = nil,
        onNextVerse:       (() -> Void)? = nil,
        onPreviousChapter: (() -> Void)? = nil,
        onNextChapter:     (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.autoStart = autoStart
        self.onPreviousVerse = onPreviousVerse
        self.onNextVerse = onNextVerse
        self.onPreviousChapter = onPreviousChapter
        self.onNextChapter = onNextChapter
    }

    public var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header

                VStack(spacing: 0) {
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                            .padding(.bottom, 12)
                    }

                    Group {
                        progressSection
                            .frame(height:32)
                            .padding(.vertical, 20)

                        controlButtons
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    AirPlayRoutePickerView()
                        .frame(height: 50)
                        .padding(.top, 20)
                }
            }
            .padding(20)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task {
            viewModel.startIfNeeded(autoPlay: autoStart)
        }
        .onAppear {
            // Sync with the current selected reciter on appear
            if let reciter = reciterService.selectedReciter,
               let baseURL = reciter.audioBaseURL {
                viewModel.updateReciter(
                    baseURL: baseURL,
                    reciterName: reciter.displayName,
                    reciterId: reciter.id,
                    timingSource: reciter.timingSource
                )
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        SheetHeader(alignment: .top, content: {
            reciterName
                .overlay(alignment: .bottomLeading) {
                    surahName
                        .frame(maxWidth:.infinity,alignment: .leading)
                        .offset(y:25)
                        .overlay(alignment: .bottomLeading) {
                            playbackStateView
                                .offset(y:40)
                        }
                }
        })
        .frame(height:60)
    }

    private var reciterName: some View {
        Button {
            showReciterPicker.toggle()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(reciterService.selectedReciter?.displayName ?? viewModel.reciterName)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(height: 29)
                    .foregroundStyle(.primary)

                Image(systemName: showReciterPicker ? "chevron.down" : "chevron.forward")
                    .font(.system(size: 16))
                    .foregroundStyle(.naturalGray)
                    .animation(.easeInOut(duration: 0.2), value: showReciterPicker)
            }
            .frame(height: 30)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showReciterPicker) {
            ReciterPickerView(
                reciters: reciterService.availableReciters,
                selectedReciter: reciterService.selectedReciter,
                onSelect: { reciter in
                    reciterService.selectReciter(reciter)
                    if let baseURL = reciter.audioBaseURL {
                        viewModel.updateReciter(
                            baseURL: baseURL,
                            reciterName: reciter.displayName,
                            reciterId: reciter.id,
                            timingSource: reciter.timingSource
                        )
                    }
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
        }
    }
    
    private var surahName: some View {
        HStack(spacing: 2) {
            Text(viewModel.chapterName)
            if let verseN = viewModel.currentVerseNumber, verseN > 0 {
                Text(":")
                    .environment(\.layoutDirection, .leftToRight) // force colon direction
                Text("\(verseN)")
            }
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(.secondary)
        .frame(height: 30)
    }

    private var progressSection: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor)
                        .frame(width: geometry.size.width * CGFloat(viewModel.progress), height: 6)
                }
                .contentShape(Rectangle())
                .gesture(progressGesture(in: geometry.size.width))
                .allowsHitTesting(progressGestureEnabled)
            }
            .frame(height: 6)


            HStack {
                Text(viewModel.currentTime.formatTime)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(accentColor)

                Spacer()

                Text("-\(viewModel.remainingTime.formatTime)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(accentColor)
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 40) {
            Button(action: viewModel.toggleRepeat) {
                Image(systemName: viewModel.isRepeatEnabled ? "repeat.circle.fill" : "repeat")
            }
            .symbolRenderingMode(viewModel.isRepeatEnabled ? .multicolor : .hierarchical)
            .foregroundColor(viewModel.isRepeatEnabled ? accentColor : .brand900)
            
            Button(action: { onPreviousVerse?() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 25))
                    .opacity(onPreviousVerse == nil ? 0.35 : 1)
            }
            .disabled(onPreviousVerse == nil || viewModel.isLoading)
            
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 42))
            }
            .disabled(viewModel.isLoading && !viewModel.isPlaying)
            
            Button(action: { onNextVerse?() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 25))
                    .opacity(onNextVerse == nil ? 0.35 : 1)
            }
            .disabled(onNextVerse == nil || viewModel.isLoading)
            
            
            Button(action: viewModel.cyclePlaybackRate) {
                Image(systemName: "gauge.with.dots.needle.50percent")
            }
            .disabled(viewModel.isLoading)
        }
        .font(.system(size: 22))
        .bold()
        .foregroundStyle(.brand900)
        .opacity(viewModel.isLoading ? 0.7 : 1)
        .frame(height:55)
    }

    // MARK: - Helpers

    private func progressGesture(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard progressGestureEnabled else { return }
                if !viewModel.isScrubbing {
                    viewModel.beginScrubbing()
                }
                let ratio = progressRatio(at: value.location.x, width: width)
                viewModel.updateScrubbing(progress: ratio)
            }
            .onEnded { value in
                guard progressGestureEnabled else { return }
                let ratio = progressRatio(at: value.location.x, width: width)
                viewModel.endScrubbing(progress: ratio)
            }
    }

    private var progressGestureEnabled: Bool {
        viewModel.duration > 0 && !viewModel.isLoading
    }

    private func progressRatio(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let clamped = min(max(x, 0), width)
        return Double(clamped / width)
    }

    @ViewBuilder
    private var playbackStateView: some View {
        if viewModel.isLoading {
            stateRow(label: String(localized: "Loading audio…"), showsSpinner: true)
        } else if viewModel.isBuffering {
            stateRow(label: String(localized: "Buffering…"), showsSpinner: true)
        } else {
            switch viewModel.playbackState {
            case .paused:
                stateRow(label: String(localized: "Paused"), systemImage: "pause.fill")
            case .finished:
                stateRow(label: String(localized: "Playback completed"), systemImage: "checkmark.circle.fill")
            case .ready:
                stateRow(label: String(localized: "Ready to play"), systemImage: "play.circle")
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func stateRow(label: String, showsSpinner: Bool = false, systemImage: String? = nil) -> some View {
        HStack(spacing: 8) {
            if showsSpinner {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    

    private func playbackRateLabel(for rate: Float) -> String {
        let value = Double(rate)
        if value.rounded() == value {
            return "\(Int(value))x"
        }

        if (value * 10).rounded() == value * 10 {
            return String(format: "%.1fx", value)
        }

        return String(format: "%.2fx", value)
    }
}

#Preview {
    ZStack {
        Color.gray
            .ignoresSafeArea()

        QuranPlayer(
            viewModel: QuranPlayerViewModel(
                baseURL: URL(string: "https://audio.example.com"),
                chapterNumber: 3,
                chapterName: "آل عمران"
            )
        )
        .background(.naturalWhite)
        .padding(5)
        .environmentObject(ReciterService.shared)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, .init(identifier: "ar_SA"))
}

#if os(iOS)
public struct AirPlayRoutePickerView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = UIColor.brand900
        routePickerView.activeTintColor = UIColor.brand900
        return routePickerView
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Update the view if needed
    }
}
#elseif os(macOS)
// AVRoutePickerView is not available on macOS
public struct AirPlayRoutePickerView: View {
    public init() {}
    
    public var body: some View {
        EmptyView()
    }
}
#endif
