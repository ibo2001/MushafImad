//
//  MushafTextView.swift
//  MushafImad
//
//  Created for the Text Mode feature.
//

import SwiftUI

// MARK: - MushafTextView

/// A continuous chapter-by-chapter text rendering of the Quran.
/// Verses are rendered using the Uthmanic Hafs font with RTL layout.
public struct MushafTextView: View {
    let initialChapter: Int
    let highlightedVerse: Verse?
    @Binding var selectedVerse: Verse?
    let onVerseLongPress: ((Verse) -> Void)?
    let fontSize: Double

    @State private var didPerformInitialScroll = false

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .trailing, spacing: 0) {
                    ForEach(1...114, id: \.self) { number in
                        ChapterTextSection(
                            chapterNumber: number,
                            selectedVerse: $selectedVerse,
                            highlightedVerse: highlightedVerse,
                            onVerseLongPress: onVerseLongPress,
                            fontSize: fontSize,
                            // Only pass the scroll callback for the target chapter;
                            // nil for all others so the section calls it unconditionally.
                            onInitialChapterAppear: number == initialChapter ? {
                                if !didPerformInitialScroll {
                                    didPerformInitialScroll = true
                                    withAnimation(.none) {
                                        proxy.scrollTo(initialChapter, anchor: .top)
                                    }
                                }
                            } : nil
                        )
                        .id(number)
                    }
                }
                .padding(.horizontal, 16)
            }
            // Force RTL regardless of device locale so Quran text always reads right-to-left.
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - ChapterTextSection

private struct ChapterTextSection: View {
    let chapterNumber: Int
    @Binding var selectedVerse: Verse?
    let highlightedVerse: Verse?
    let onVerseLongPress: ((Verse) -> Void)?
    let fontSize: Double
    /// Non-nil only for the initial chapter; called in .onAppear to trigger the
    /// one-time scroll-to-position without needing a separate isInitialChapter flag.
    let onInitialChapterAppear: (() -> Void)?

    @State private var chapter: Chapter?

    // Verse counts for all 114 surahs in order (index 0 = surah 1).
    // Source: standard Hafs mushaf. Range: 3 (Al-Asr) – 286 (Al-Baqarah).
    private static let verseCounts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
        123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
        34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
        60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
        28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
        15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
        5, 4, 5, 6
    ]

    var body: some View {
        Group {
            if let chapter {
                VStack(alignment: .trailing, spacing: 8) {
                    chapterHeader(chapter)

                    // Basmala: not for Al-Fatiha (1, whose first verse is the Basmala)
                    // and not for At-Tawbah (9, which has no Basmala)
                    if chapter.number != 1 && chapter.number != 9 {
                        basmalaView
                    }

                    ForEach(Array(chapter.verses), id: \.verseID) { verse in
                        VerseTextRow(
                            verse: verse,
                            isSelected: selectedVerse?.verseID == verse.verseID,
                            isHighlighted: highlightedVerse?.verseID == verse.verseID,
                            fontSize: fontSize,
                            onLongPress: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedVerse?.verseID == verse.verseID {
                                        selectedVerse = nil
                                    } else {
                                        selectedVerse = verse
                                        onVerseLongPress?(verse)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.bottom, 32)

                Divider().padding(.vertical, 8)
            } else {
                // Placeholder while chapter data loads — sized to the actual
                // verse count for this surah so the scroll position stays stable.
                let estimatedVerseCount = CGFloat(Self.verseCounts[chapterNumber - 1])
                let estimatedHeight: CGFloat = 40 + (estimatedVerseCount * CGFloat(fontSize) * 1.8) + 32

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(minHeight: estimatedHeight)
                    .padding(.vertical, 8)
            }
        }
        .onAppear {
            onInitialChapterAppear?()
        }
        .task {
            chapter = RealmService.shared.getChapter(number: chapterNumber)
        }
    }

    // Matches PageHeaderView: "سورة <arabicTitle>" in the chapter-names font at size 24.
    @ViewBuilder
    private func chapterHeader(_ chapter: Chapter) -> some View {
        VStack(spacing: 4) {
            Text("سورة \(chapter.arabicTitle)")
                .font(.chapterNames(size: 24))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(chapter.englishTitle)
                .font(.kitab(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 8)
    }

    private var basmalaView: some View {
        Text("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ")
            .font(.uthmanicHafs(size: fontSize))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 4)
    }
}

// MARK: - VerseTextRow

private struct VerseTextRow: View {
    let verse: Verse
    let isSelected: Bool
    let isHighlighted: Bool
    let fontSize: Double
    let onLongPress: () -> Void

    // VerseFasel's internal base font size (14 * balance 3.69).
    // Dividing fontSize by this gives the scale that makes the fasel
    // the same visual weight as the verse text.
    private static let verseFaselBaseFontSize: CGFloat = 14 * 3.69

    private var verseText: String {
        verse.uthmanicHafsText.isEmpty ? verse.text : verse.uthmanicHafsText
    }

    // Selected (user tapped) uses accent900; audio-highlighted uses the lighter
    // accent500 so readers can distinguish "I selected this" from "audio is here".
    private var backgroundColor: Color {
        if isSelected { return .accent900 }
        if isHighlighted { return .accent500 }
        return .clear
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(verseText)
                .font(.uthmanicHafs(size: fontSize))
                .multilineTextAlignment(.leading)
                .lineSpacing(CGFloat(fontSize) * 0.4)

            VerseFasel(
                number: verse.number,
                scale: CGFloat(fontSize * 0.8) / Self.verseFaselBaseFontSize
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
    }
}
