//
//  QuranPageView.swift
//  Mushaf
//
//  Created by Ibrahim Qraiqe on 26/10/2025.
//  Fork patch: normal tap is reserved for page chrome; short long press selects verse.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Preference key used to bubble up the on-screen rectangle of the selected verse.
public struct SelectedVerseRectKey: PreferenceKey {
    public nonisolated(unsafe) static var defaultValue: CGRect? = nil

    public static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        guard let newRect = nextValue() else { return }
        if let current = value {
            // Keep the rectangle that is visually higher on screen (smaller minY).
            value = newRect.minY < current.minY ? newRect : current
        } else {
            value = newRect
        }
    }
}

public struct QuranPageView<Header: View, Footer: View>: View {
    public let pageNumber: Int
    public var page: Page
    public let initialHighlightedVerse: Verse?
    @Binding public var selectedVerse: Verse?

    /// Fired on a short long press over a verse highlight area.
    public var onVerseLongPress: ((Verse) -> Void)? = nil

    private let headerBuilder: () -> Header
    private let footerBuilder: () -> Footer

    // State to track which verse is currently being pressed (shared across all lines).
    @State private var pressingVerseID: Int? = nil

    public init(
        pageNumber: Int,
        page: Page,
        initialHighlightedVerse: Verse?,
        selectedVerse: Binding<Verse?>,
        onVerseLongPress: ((Verse) -> Void)? = nil,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.pageNumber = pageNumber
        self.page = page
        self.initialHighlightedVerse = initialHighlightedVerse
        self._selectedVerse = selectedVerse
        self.onVerseLongPress = onVerseLongPress
        self.headerBuilder = header
        self.footerBuilder = footer
    }

    public var body: some View {
        GeometryReader { reader in
            let availableWidth = reader.size.width
            let availableHeight = reader.size.height
            let isLandscape = availableWidth > availableHeight
            // Calculate line height based on the aspect ratio (1440:232).
            let lineHeight = availableWidth / 1440 * 232

            if isLandscape {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerBuilder()

                        ForEach(0...14, id: \.self) { line in
                            lineView(
                                line: line,
                                availableWidth: availableWidth,
                                availableHeight: lineHeight
                            )
                            .frame(width: availableWidth, height: lineHeight * 0.7)
                            .id("\(pageNumber)-\(line)")
                        }

                        footerBuilder().padding(.vertical, 40)
                    }
                    .frame(width: availableWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollBounceBehavior(.basedOnSize)
                .id("landscape-\(pageNumber)")
            } else {
                VStack(spacing: 0) {
                    headerBuilder()

                    ForEach(0...14, id: \.self) { line in
                        lineView(
                            line: line,
                            availableWidth: availableWidth,
                            availableHeight: availableHeight
                        )
                        .frame(width: availableWidth, height: lineHeight * 0.73)
                        .id("\(pageNumber)-\(line)")
                    }

                    Spacer()
                    footerBuilder()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("portrait-\(pageNumber)")
            }
        }
        .id(pageNumber)
    }

    private func lineView(line: Int, availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        LineImageView(
            pageNumber: pageNumber,
            chapterheader: Array(page.chapterHeaders1441),
            line: line,
            verses: Array(page.verses1441),
            container: CGSize(width: availableWidth, height: availableHeight),
            selectedVerse: selectedVerse,
            highlightedVerse: initialHighlightedVerse,
            pressingVerseID: $pressingVerseID,
            onVerseLongPress: handleVerseLongPress
        )
    }

    private func handleVerseLongPress(_ verse: Verse) {
        withAnimation {
            selectedVerse = verse

            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif

            onVerseLongPress?(verse)
        }
    }
}

// MARK: - Line Image View

private struct LineImageView: View {
    let pageNumber: Int
    let chapterheader: [ChapterHeader]
    let line: Int
    let verses: [Verse]
    let container: CGSize
    let selectedVerse: Verse?
    let highlightedVerse: Verse?
    @Binding var pressingVerseID: Int?

    var onVerseLongPress: (Verse) -> Void

    // Original line image dimensions (all line images are 1440 x 232 pixels).
    private let originalLineSize = CGSize(width: 1440, height: 232)

    // Timer to delay highlight activation while filtering accidental touches.
    @State private var highlightTimer: Timer?

    var selectedCorners: UIRectCorner {
        [.allCorners]
    }

    private func shouldHighlight(_ verse: Verse) -> Bool {
        selectedVerse?.verseID == verse.verseID ||
        highlightedVerse?.verseID == verse.verseID ||
        pressingVerseID == verse.verseID
    }

    @ViewBuilder
    private func verseHighlightsView(verse: Verse, geometry: GeometryProxy) -> some View {
        ForEach(verse.highlights1441.filter { $0.line == line }, id: \.self) { highlight in
            let visualLeftX = geometry.size.width * CGFloat(1.0 - highlight.right)
            let visualRightX = geometry.size.width * CGFloat(1.0 - highlight.left)
            let highlightWidth = visualRightX - visualLeftX
            let highlightHeight = geometry.size.height * 0.94

            Rectangle()
                .fill(shouldHighlight(verse) ? Color(.accent900) : Color.clear)
                .cornerRadius(8, corners: selectedCorners)
                .frame(width: highlightWidth, height: highlightHeight)
                .contentShape(Rectangle())
                .onLongPressGesture(
                    minimumDuration: 0.30,
                    maximumDistance: 24,
                    pressing: { isPressing in
                        if isPressing {
                            // Give the user quick visual feedback without treating a normal tap as verse actions.
                            highlightTimer?.invalidate()
                            let verseID = verse.verseID
                            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    pressingVerseID = verseID
                                }
                            }
                        } else {
                            highlightTimer?.invalidate()
                            highlightTimer = nil
                            pressingVerseID = nil
                        }
                    },
                    perform: {
                        highlightTimer?.invalidate()
                        highlightTimer = nil
                        pressingVerseID = nil
                        onVerseLongPress(verse)
                    }
                )
                .position(x: visualLeftX + highlightWidth / 2, y: highlightHeight * 0.8)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SelectedVerseRectKey.self,
                            value: shouldHighlight(verse) ? proxy.frame(in: .named("MushafRoot")) : nil
                        )
                    }
                )
        }
    }

    var body: some View {
        let imageAspect = originalLineSize.width / originalLineSize.height
        let containerWidth = container.width

        ZStack {
            GeometryReader { geometry in
                let scaledImageHeight = geometry.size.width / imageAspect
                let cropOffset = (scaledImageHeight - geometry.size.height) / 2
                let lineScale = geometry.size.width / originalLineSize.width

                ForEach(verses, id: \.verseID) { verse in
                    verseHighlightsView(verse: verse, geometry: geometry)

                    if let marker = verse.marker1441, marker.line == line {
                        let markerX = geometry.size.width * CGFloat(1.0 - marker.centerX)
                        let fullImageY = scaledImageHeight * CGFloat(marker.centerY)
                        let markerY = fullImageY - cropOffset

                        VerseFasel(number: verse.number, scale: lineScale)
                            .position(x: markerX, y: markerY + 10)
                            .allowsHitTesting(false)
                    }
                }

                ForEach(chapterheader, id: \.self) { chapterheader in
                    let chapterX = geometry.size.width * CGFloat(1.0 - chapterheader.centerX)
                    let fullImageY = scaledImageHeight * CGFloat(chapterheader.centerY)
                    let chapterY = fullImageY - cropOffset

                    if chapterheader.line == line {
                        MushafAssets.image(named: "suraNameBar")
                            .resizable()
                            .frame(width: containerWidth * 0.9, height: scaledImageHeight * 0.8)
                            .position(x: chapterX, y: chapterY + 8)
                            .allowsHitTesting(false)
                    }
                }

                QuranLineImageView(
                    page: pageNumber,
                    line: line + 1,
                    imageAspect: imageAspect,
                    containerWidth: containerWidth,
                    scaledImageHeight: scaledImageHeight
                )
                .allowsHitTesting(false)
            }
        }
    }
}
