//
//  TafseerView.swift
//  MushafImad
//
//  Sheet that displays Tafseer Al-Jalalayn for a selected verse.
//  Presented as a bottom sheet from the reading view.
//

import SwiftUI

// MARK: - TafseerView

/// A self-contained sheet that shows the tafseer for a given surah/ayah pair.
public struct TafseerView: View {

    // MARK: - Input

    public let surahId: Int
    public let ayahId: Int
    public let surahName: String

    // MARK: - State

    @State private var viewModel = TafseerViewModel()

    // MARK: - Init

    public init(surahId: Int, ayahId: Int, surahName: String) {
        self.surahId = surahId
        self.ayahId = ayahId
        self.surahName = surahName
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeader(alignment: .center) {
                VStack(spacing: 2) {
                    Text("تفسير الجلالين")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("\(surahName) • آية \(arabicNumeral(ayahId))")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 20)

            Divider()

            contentArea
        }
        .background(Color(.systemBackground))
        .task {
            await viewModel.load(surahId: surahId, ayahId: ayahId)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else if let text = viewModel.tafseerText {
            tafseerTextView(text: text)
        } else {
            emptyView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()

            if case .importing = viewModel.importState {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.importProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .padding(.horizontal, 40)

                    Text(viewModel.importStateDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)

                    Text(viewModel.importStateDescription.isEmpty
                         ? String(localized: "جاري تحميل التفسير…")
                         : viewModel.importStateDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.retry(surahId: surahId, ayahId: ayahId) }
            } label: {
                Label(String(localized: "إعادة المحاولة"), systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func tafseerTextView(text: String) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(text)
                    .font(.system(size: 18, weight: .regular))
                    .lineSpacing(10)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(String(localized: "لا يوجد تفسير لهذه الآية"))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func arabicNumeral(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Modifier for easy sheet presentation

/// Convenience modifier that presents a `TafseerView` sheet when a verse is provided.
public struct TafseerSheetModifier: ViewModifier {
    @Binding var verse: Verse?

    public func body(content: Content) -> some View {
        content
            .sheet(item: $verse) { selectedVerse in
                TafseerView(
                    surahId: selectedVerse.chapterNumber,
                    ayahId: selectedVerse.number,
                    surahName: selectedVerse.chapter?.arabicTitle ?? ""
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

public extension View {
    /// Attaches a Tafseer sheet that presents when `verse` is non-nil.
    func tafseerSheet(verse: Binding<Verse?>) -> some View {
        modifier(TafseerSheetModifier(verse: verse))
    }
}
