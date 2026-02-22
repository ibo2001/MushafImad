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
                            fontSize: fontSize
                        )
                        .id(number)
                    }
                }
                .padding(.horizontal, 16)
            }
            .task {
                // Small delay so LazyVStack lays out before scrolling
                try? await Task.sleep(nanoseconds: 50_000_000)
                proxy.scrollTo(initialChapter, anchor: .top)
            }
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

    @State private var chapter: Chapter?

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
                // Placeholder while chapter data loads
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 200)
                    .padding(.vertical, 8)
            }
        }
        .task {
            chapter = RealmService.shared.getChapter(number: chapterNumber)
        }
    }

    @ViewBuilder
    private func chapterHeader(_ chapter: Chapter) -> some View {
        VStack(spacing: 2) {
            if chapter.titleCodePoint.isEmpty {
                Text(chapter.arabicTitle)
                    .font(.kitabBold(size: 22))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(chapter.titleCodePoint)
                    .font(.chapterNames(size: 40))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
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

    private var displayText: String {
        let base = verse.uthmanicHafsText.isEmpty ? verse.text : verse.uthmanicHafsText
        return base + " \u{FD3E}\(verse.number.toArabic)\u{FD3F}"
    }

    var body: some View {
        Text(displayText)
            .font(.uthmanicHafs(size: fontSize))
            .multilineTextAlignment(.trailing)
            .lineSpacing(CGFloat(fontSize) * 0.4)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill((isSelected || isHighlighted)
                          ? Color.accent900
                          : Color.clear)
            )
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
    }
}
