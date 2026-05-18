//
//  PageContainer.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//  Fork patch: adds direct verse tap support.
//

import SwiftUI

/// Thin wrapper that loads a `Page` model, then renders it via `QuranPageView`.
public struct PageContainer: View {
    public let pageNumber: Int
    public let highlightedVerse: Verse?
    @Binding public var selectedVerse: Verse?

    /// Fired immediately when the user taps a verse highlight area.
    public let onVerseTap: ((Verse) -> Void)?

    /// Fired when the user long-presses a verse highlight area.
    public let onVerseLongPress: (Verse) -> Void

    /// Fired when the user taps empty/page area.
    public let onTap: () -> Void

    @State private var pageData: Page?
    @State private var didHandleVerseInteraction = false

    // Static cache to persist page data across view recreations.
    private static var pageCache: [Int: Page] = [:]

    public init(
        pageNumber: Int,
        highlightedVerse: Verse?,
        selectedVerse: Binding<Verse?>,
        onVerseTap: ((Verse) -> Void)? = nil,
        onVerseLongPress: @escaping (Verse) -> Void,
        onTap: @escaping () -> Void
    ) {
        self.pageNumber = pageNumber
        self.highlightedVerse = highlightedVerse
        self._selectedVerse = selectedVerse
        self.onVerseTap = onVerseTap
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
                        initialHighlightedVerse: highlightedVerse?.page1441?.number == pageNumber ? highlightedVerse : nil,
                        selectedVerse: $selectedVerse,
                        onVerseTap: { verse in
                            didHandleVerseInteraction = true
                            onVerseTap?(verse)
                        },
                        onVerseLongPress: { verse in
                            didHandleVerseInteraction = true
                            onVerseLongPress(verse)
                        },
                        header: { PageHeaderView(page: pageData) },
                        footer: { PageFooterView(pageNumber: pageData.number, isRight: pageData.isRight) }
                    )
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    // If the tap was consumed by a verse, do not also toggle the page chrome.
                    guard !didHandleVerseInteraction else {
                        didHandleVerseInteraction = false
                        return
                    }
                    onTap()
                }
            )
        }
        .task {
            // Check cache first to avoid repeated Realm queries.
            guard pageData == nil else { return }

            if let cached = Self.pageCache[pageNumber] {
                pageData = cached
                return
            }

            if let data = await RealmService.shared.fetchPageAsync(number: pageNumber) {
                pageData = data
                Self.pageCache[pageNumber] = data
            }
        }
    }
}
