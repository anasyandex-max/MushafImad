import SwiftUI

/// Controls where the Quran page number is rendered.
public enum QuranPageNumberPosition: Equatable {
    /// Render the page number inline in the existing header, beside the Juz text.
    /// The original footer space is kept invisible so the Mushaf layout does not move.
    case top

    /// Render the page number in the original footer position.
    case bottom

    /// Do not render the page number and do not reserve the footer number space.
    case hidden
}

/// Thin wrapper that loads a `Page` model, then renders it via `QuranPageView`.
public struct PageContainer: View {
    public let pageNumber: Int
    public let highlightedVerse: Verse?
    @Binding public var selectedVerse: Verse?
    public let pageNumberPosition: QuranPageNumberPosition

    /// Fired when the user short-long-presses a verse highlight area.
    public let onVerseLongPress: (Verse) -> Void

    /// Fired when the user taps the page. This is intended for showing/hiding reader chrome.
    public let onTap: () -> Void

    @State private var pageData: Page?

    // Static cache to persist page data across view recreations.
    private static var pageCache: [Int: Page] = [:]

    public init(
        pageNumber: Int,
        highlightedVerse: Verse?,
        selectedVerse: Binding<Verse?>,
        pageNumberPosition: QuranPageNumberPosition = .bottom,
        onVerseLongPress: @escaping (Verse) -> Void,
        onTap: @escaping () -> Void
    ) {
        self.pageNumber = pageNumber
        self.highlightedVerse = highlightedVerse
        self._selectedVerse = selectedVerse
        self.pageNumberPosition = pageNumberPosition
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
                        onVerseLongPress: onVerseLongPress,
                        header: {
                            PageHeaderView(
                                page: pageData,
                                showsPageNumber: pageNumberPosition == .top
                            )
                        },
                        footer: {
                            pageFooter(for: pageData)
                        }
                    )
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    onTap()
                }
            )
        }
        .task {
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

    @ViewBuilder
    private func pageFooter(for pageData: Page) -> some View {
        switch pageNumberPosition {
        case .bottom:
            PageFooterView(pageNumber: pageData.number, isRight: pageData.isRight)

        case .top:
            // Keep the original footer badge in the layout but make it invisible.
            // This preserves the old Mushaf vertical geometry exactly; only the visible
            // number moves beside the Juz text.
            PageFooterView(pageNumber: pageData.number, isRight: pageData.isRight)
                .opacity(0)
                .accessibilityHidden(true)

        case .hidden:
            EmptyView()
        }
    }
}
