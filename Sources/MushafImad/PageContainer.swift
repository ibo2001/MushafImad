//
//  PageContainer.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import SwiftUI

/// Thin wrapper that loads a `Page` model, then renders it via `QuranPageView`.
public struct PageContainer: View {
    public let pageNumber: Int
    public let mushafType: MushafType
    public let highlightedVerse: Verse?
    @Binding public var selectedVerse: Verse?
    public let onVerseLongPress: (Verse) -> Void
    public let onTap: () -> Void

    @State private var pageData: Page?

    // Static cache to persist page data across view recreations
    private static var pageCache: [Int: Page] = [:]

    public init(
        pageNumber: Int,
        mushafType: MushafType = .hafs1441,
        highlightedVerse: Verse?,
        selectedVerse: Binding<Verse?>,
        onVerseLongPress: @escaping (Verse) -> Void,
        onTap: @escaping () -> Void
    ) {
        self.pageNumber = pageNumber
        self.mushafType = mushafType
        self.highlightedVerse = highlightedVerse
        self._selectedVerse = selectedVerse
        self.onVerseLongPress = onVerseLongPress
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let pageData = pageData {
                    QuranPageView(
                        pageNumber: pageNumber,
                        page: pageData,
                        mushafType: mushafType,
                        initialHighlightedVerse: highlightedVerse?.page(for: mushafType)?.number == pageNumber ? highlightedVerse : nil,
                        selectedVerse: $selectedVerse,
                        onVerseLongPress: onVerseLongPress,
                        header: {
                            PageHeaderView(page: pageData, mushafType: mushafType)
                        },
                        footer: {
                            PageFooterView(pageNumber: pageData.number, isRight: pageData.isRight)
                        }
                    )
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture().onEnded { _ in}
            )
            .highPriorityGesture(
                TapGesture().onEnded {
                    onTap()
                }
            )
        }
        .task {
            // Check cache first to avoid repeated Realm queries
            if pageData == nil {
                if let cached = Self.pageCache[pageNumber] {
                    pageData = cached
                } else {
                    if let data = await RealmService.shared.fetchPageAsync(number: pageNumber) {
                        pageData = data
                        Self.pageCache[pageNumber] = data
                    }
                }
            }
        }
    }
}
