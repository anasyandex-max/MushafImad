//
// PageContainer.swift
// MushafImad
//
// Created by Ibrahim Qraiqe on 31/10/2025.
// Fork patch: tap toggles page chrome, short long press opens verse actions.
// Patch: page number can be rendered beside the Juz label without changing page scale.
//

import SwiftUI

/// Controls where the Quran page number is rendered.
public enum QuranPageNumberPosition: Equatable {
    /// Render the page number beside the Juz label in the page header.
    case besideJuz

    /// Backward-compatible name from the previous patch.
    /// This now behaves like `besideJuz` instead of adding a separate row above the header.
    case top

    /// Render the page number in the original footer position.
    case bottom

    /// Do not render the page number.
    case hidden
}

/// Thin wrapper that loads a `Page` model, then renders it via `QuranPageView`.
public struct PageContainer: View {
    public let pageNumber: Int
    public let highlightedVerse: Verse?
    @Binding public var selectedVerse: Verse?

    /// Where to show the Quran page number.
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
                            pageHeader(for: pageData)
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

    @ViewBuilder
    private func pageHeader(for pageData: Page) -> some View {
        switch pageNumberPosition {
        case .besideJuz, .top:
            PageHeaderWithPageNumberView(page: pageData)
        case .bottom, .hidden:
            PageHeaderView(page: pageData)
        }
    }

    @ViewBuilder
    private func pageFooter(for pageData: Page) -> some View {
        switch pageNumberPosition {
        case .bottom:
            PageFooterView(pageNumber: pageData.number, isRight: pageData.isRight)

        case .besideJuz, .top:
            // Keep the original footer height reserved, but make it invisible.
            // Without this placeholder, `QuranPageView` gives the freed space to `Spacer()`,
            // so the last Quran lines move down and can appear behind the app tab bar.
            PageFooterView(pageNumber: pageData.number, isRight: pageData.isRight)
                .opacity(0)
                .accessibilityHidden(true)

        case .hidden:
            EmptyView()
        }
    }
}

private struct PageHeaderWithPageNumberView: View {
    let page: Page
    var horizentalPadding: CGFloat = 16

    var body: some View {
        HStack {
            let headerDisplay = getPageHeaderDisplay(page: page)

            HStack(spacing: 8) {
                if let juz = headerDisplay.juz {
                    Text(juz)
                        .font(.system(size: 14, weight: .medium))
                }

                CompactPageNumberBadge(pageNumber: page.number)

                if let hizb = headerDisplay.hizb {
                    HizbProgressView(hizbInfo: hizb)
                        .padding(.leading, 14)
                }
            }

            Spacer()

            ForEach(headerDisplay.titles, id: \.self) { title in
                Text("سورة \(title)")
                    .font(.chapterNames(size: 24))
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.brand900)
        .padding(.horizontal, horizentalPadding)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func getPageHeaderDisplay(page: Page) -> (juz: String?, hizb: HizbDisplayInfo?, titles: [String]) {
        guard let header = page.header1441 else { return (nil, nil, []) }

        let titles: [String] = header.chapters.map { $0.arabicTitle }
        let juzDisplay: String? = header.part.map { "الجزء \($0.number)" }
        let hizbDisplay: HizbDisplayInfo? = header.quarter.map { quarter in
            HizbDisplayInfo(number: quarter.hizbNumber, hizbFraction: quarter.hizbFraction)
        }

        return (juzDisplay, hizbDisplay, titles)
    }
}

private struct CompactPageNumberBadge: View {
    let pageNumber: Int

    var body: some View {
        MushafAssets.image(named: "pagenumb")
            .resizable()
            .frame(width: 34, height: 21)
            .overlay {
                Text(pageNumber.toArabic)
                    .font(.uthmanicTN1Bold(size: 25))
                    .minimumScaleFactor(0.25)
                    .offset(y: -1.5)
            }
            .allowsHitTesting(false)
            .accessibilityLabel("صفحة \(pageNumber)")
    }
}
