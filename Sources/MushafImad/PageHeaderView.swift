//
// PageHeader.swift
// MushafImad
//
// Created by Ibrahim Qraiqe on 31/10/2025.
// Patch: show the page number inline beside the Juz text when requested.
//

import SwiftUI

public struct PageHeaderView: View {
    public let page: Page
    public var horizentalPadding: CGFloat = 16
    public var showsPageNumber: Bool = false

    public init(
        page: Page,
        horizentalPadding: CGFloat = 16,
        showsPageNumber: Bool = false
    ) {
        self.page = page
        self.horizentalPadding = horizentalPadding
        self.showsPageNumber = showsPageNumber
    }

    public var body: some View {
        HStack {
            // Use the PageHeader functionality for formatted display.
            let headerDisplay = getPageHeaderDisplay(page: page)

            HStack(spacing: showsPageNumber ? 8 : 25) {
                if let juz = headerDisplay.juz {
                    Text(juz)
                        .font(.system(size: 14, weight: .medium))
                }

                if showsPageNumber {
                    inlinePageNumber
                }

                if let hizb = headerDisplay.hizb {
                    HizbProgressView(hizbInfo: hizb)
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

    private var inlinePageNumber: some View {
        MushafAssets.image(named: "pagenumb")
            .resizable()
            .frame(width: 38, height: 24)
            .overlay {
                Text(page.number.toArabic)
                    .font(.uthmanicTN1Bold(size: 24))
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.2)
                    .offset(y: -1)
            }
            .allowsHitTesting(false)
    }

    public func getPageHeaderDisplay(page: Page) -> (juz: String?, hizb: HizbDisplayInfo?, titles: [String]) {
        // Get the header for the current Mushaf type (defaulting to 1441).
        guard let header = page.header1441 else {
            return (nil, nil, [])
        }

        let titles: [String] = header.chapters.map { $0.arabicTitle }

        // Format Juz display.
        let juzDisplay: String? = header.part.map { "الجزء \($0.number)" }

        // Format Hizb display.
        let hizbDisplay: HizbDisplayInfo? = header.quarter.map { quarter in
            HizbDisplayInfo(
                number: quarter.hizbNumber,
                hizbFraction: quarter.hizbFraction
            )
        }

        return (juzDisplay, hizbDisplay, titles)
    }
}
