import Foundation
import CryptoKit

struct LyricsCacheMetadata: Codable {
    let track: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let isInstrumental: Bool
    let cachedAt: Date
    let source: String
}

final class LyricsCacheStore {
    static let shared = LyricsCacheStore()

    private let fileManager = FileManager.default
    private let directoryURL: URL

    private init() {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        directoryURL = baseDirectory
            .appendingPathComponent("SpotifyOnTouchbar", isDirectory: true)
            .appendingPathComponent("LyricsCache", isDirectory: true)

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func load(track: String, artist: String, album: String, duration: TimeInterval) -> LyricsData? {
        let key = cacheKey(track: track, artist: artist, album: album, duration: duration)
        let metaURL = directoryURL.appendingPathComponent("\(key).json")
        let lrcURL = directoryURL.appendingPathComponent("\(key).lrc")

        guard let metadata = readMetadata(from: metaURL),
              let rawText = try? String(contentsOf: lrcURL, encoding: .utf8) else {
            return nil
        }

        // Older plain-lyrics caches used a naive equal-slice timing model.
        // Ignore them so we can regenerate with the newer weighted estimator.
        if metadata.source == "plainLyrics" {
            return nil
        }

        if metadata.isInstrumental {
            return LyricsData(lines: [], track: metadata.track, artist: metadata.artist, isInstrumental: true, hasPreciseTiming: false)
        }

        let lines = LRCParser.parse(rawText)
        guard !lines.isEmpty else { return nil }
        return LyricsData(lines: lines, track: metadata.track, artist: metadata.artist, isInstrumental: false, hasPreciseTiming: metadata.source == "syncedLyrics")
    }

    func store(
        track: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        lyricsData: LyricsData,
        rawLRCText: String,
        source: String
    ) {
        let key = cacheKey(track: track, artist: artist, album: album, duration: duration)
        let metaURL = directoryURL.appendingPathComponent("\(key).json")
        let lrcURL = directoryURL.appendingPathComponent("\(key).lrc")

        let metadata = LyricsCacheMetadata(
            track: track,
            artist: artist,
            album: album,
            duration: duration,
            isInstrumental: lyricsData.isInstrumental,
            cachedAt: Date(),
            source: source
        )

        guard let metaData = try? JSONEncoder().encode(metadata) else { return }
        do {
            try rawLRCText.write(to: lrcURL, atomically: true, encoding: .utf8)
            try metaData.write(to: metaURL, options: .atomic)
        } catch {
            return
        }
    }

    private func readMetadata(from url: URL) -> LyricsCacheMetadata? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LyricsCacheMetadata.self, from: data)
    }

    private func cacheKey(track: String, artist: String, album: String, duration: TimeInterval) -> String {
        let durationKey = String(Int(round(duration * 10.0)))
        let raw = [
            normalize(track),
            normalize(artist),
            normalize(album),
            durationKey
        ].joined(separator: "|||")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"\(.*?\)|\[.*?\]|（.*?）"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"feat\.?|ft\.?|with|ver\.?|version|remaster(?:ed)?|live"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
