import Foundation

/// Public, app-facing resolver for Quran audio URLs.
///
/// Use this instead of building URLs in the host app. It centralizes the rules:
/// - `.mp3quran` and `.both`: audio comes from the reciter `folderURL` using `001.mp3`.
/// - `.itqan`: audio comes from the Itqan API track URL for the requested surah.
///
/// This makes playback and downloads use one canonical source of truth.
@MainActor
public final class QuranAudioResolver {
    public static let shared = QuranAudioResolver()

    private init() {}

    public func resolveAudioURL(
        reciterId: Int,
        chapterNumber: Int
    ) async throws -> URL {
        guard (1...114).contains(chapterNumber) else {
            throw TimingProviderError.missingData
        }

        guard let reciter = ReciterDataProvider.getReciterInfo(id: reciterId) else {
            throw TimingProviderError.missingData
        }

        return try await resolveAudioURL(
            reciterId: reciterId,
            chapterNumber: chapterNumber,
            folderURL: reciter.folderURL,
            timingSource: reciter.timingSource
        )
    }

    public func resolveAudioURL(
        reciterId: Int,
        chapterNumber: Int,
        folderURL: String,
        timingSource: TimingSource
    ) async throws -> URL {
        guard (1...114).contains(chapterNumber) else {
            throw TimingProviderError.missingData
        }

        switch timingSource {
        case .itqan:
            if let audioURL = await AyahTimingService.shared.refreshChapterTimings(
                for: reciterId,
                surahId: chapterNumber
            ) ?? AyahTimingService.shared.getRemoteAudioURL(
                for: reciterId,
                surahId: chapterNumber
            ) {
                return audioURL
            }

            throw TimingProviderError.missingData

        case .both, .mp3quran:
            guard let baseURL = URL(string: folderURL) else {
                throw TimingProviderError.invalidURL
            }

            return Self.chapterAudioURL(
                baseURL: baseURL,
                chapterNumber: chapterNumber
            )

        case .none:
            throw TimingProviderError.unsupportedTimingSource
        }
    }

    public func resolveCandidateAudioURLs(
        reciterId: Int,
        chapterNumber: Int
    ) async throws -> [URL] {
        guard let reciter = ReciterDataProvider.getReciterInfo(id: reciterId) else {
            throw TimingProviderError.missingData
        }

        switch reciter.timingSource {
        case .itqan:
            return [try await resolveAudioURL(reciterId: reciterId, chapterNumber: chapterNumber)]

        case .both, .mp3quran:
            guard let baseURL = URL(string: reciter.folderURL) else {
                throw TimingProviderError.invalidURL
            }
            return Self.candidateChapterAudioURLs(
                baseURL: baseURL,
                chapterNumber: chapterNumber
            )

        case .none:
            throw TimingProviderError.unsupportedTimingSource
        }
    }

    public static func chapterAudioURL(
        baseURL: URL,
        chapterNumber: Int
    ) -> URL {
        let paddedName = String(format: "%03d.mp3", chapterNumber)
        let base = baseURL.absoluteString
        let normalizedBase = base.hasSuffix("/") ? base : base + "/"
        return URL(string: normalizedBase + paddedName)
            ?? baseURL.appendingPathComponent(paddedName)
    }

    public static func candidateChapterAudioURLs(
        baseURL: URL,
        chapterNumber: Int
    ) -> [URL] {
        let paddedName = String(format: "%03d.mp3", chapterNumber)
        let plainName = "\(chapterNumber).mp3"
        let base = baseURL.absoluteString
        let normalizedBase = base.hasSuffix("/") ? base : base + "/"

        var seen = Set<String>()
        var urls: [URL] = []

        func add(_ url: URL?) {
            guard let url else { return }
            guard seen.insert(url.absoluteString).inserted else { return }
            urls.append(url)
        }

        add(URL(string: normalizedBase + paddedName))
        add(URL(string: normalizedBase + plainName))
        add(baseURL.appendingPathComponent(paddedName))
        add(baseURL.appendingPathComponent(plainName))

        return urls
    }
}
