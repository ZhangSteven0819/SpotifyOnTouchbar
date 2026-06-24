import Foundation

// MARK: - Data Models

struct LyricsLine: Hashable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct LyricsData {
    let lines: [LyricsLine]
    let track: String
    let artist: String
    let isInstrumental: Bool
    let hasPreciseTiming: Bool

    /// 找到给定时间对应的歌词行索引
    func currentIndex(at time: TimeInterval) -> Int {
        guard !lines.isEmpty else { return -1 }
        for (index, line) in lines.enumerated() {
            if time >= line.startTime && time < line.endTime {
                return index
            }
        }
        return -1
    }

    func fallbackIndex(at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }

        if time < lines[0].startTime {
            let introLeadWindow = min(0.75, max(0.30, lines[0].startTime * 0.04))
            return (lines[0].startTime - time) <= introLeadWindow ? 0 : nil
        }

        for index in 0..<(lines.count - 1) {
            let current = lines[index]
            let next = lines[index + 1]

            if time >= current.endTime && time < next.startTime {
                let gap = next.startTime - current.endTime
                if gap <= 12.0 {
                    let distanceToCurrent = abs(time - current.endTime)
                    let distanceToNext = abs(next.startTime - time)
                    return distanceToCurrent <= distanceToNext ? index : index + 1
                }

                return index
            }
        }

        if let last = lines.last, time >= last.endTime {
            return (time - last.endTime) <= 6.0 ? (lines.count - 1) : nil
        }

        return nil
    }
}

// MARK: - Spotify Controller Delegate

protocol SpotifyControllerDelegate: AnyObject {
    func didUpdateNowPlaying(track: String, artist: String, album: String, progress: TimeInterval, duration: TimeInterval)
    func didUpdateLyrics(_ lyrics: LyricsData)
    func didUpdateSyncLine(current line: LyricsLine, prev: LyricsLine?, next: LyricsLine?, progress: Double, lineDuration: TimeInterval, hasPreciseTiming: Bool)
    func didEnterPlaybackGap(track: String, artist: String, instrumental: Bool)
    func spotifyNotRunning()
    func noActiveTrack()
}

// MARK: - Spotify Controller

class SpotifyController {
    weak var delegate: SpotifyControllerDelegate?

    private var currentTrack = ""
    private var currentArtist = ""
    private var currentAlbum = ""
    private var currentLyrics: LyricsData?
    private var lastLineIndex = -1
    private var isSyncing = false
    private var lastProgress: TimeInterval = 0
    private var currentDuration: TimeInterval = 0
    private var pendingLyricsRequest: String?
    private var lyricsCache: [String: LyricsData] = [:]
    private var lastLyricsFetchKey: String?
    private var lastLyricsFetchAt: Date = .distantPast
    private var fetchRetryCount = 0
    private var hasDisplayedLyricForCurrentTrack = false
    private var wasPaused = false
    private let syncLead: TimeInterval = 0.04
    private var resumeRecoveryDeadline: Date = .distantPast
    private var resumeBaselineTrack = ""
    private var resumeBaselineArtist = ""
    private var resumeBaselineProgress: TimeInterval = 0
    private var lyricsRequestSerial = 0
    private var activeLyricsRequestSerial = 0
    private var lyricsRequestInFlight = false
    private(set) var recommendedPollInterval: TimeInterval = 0.18
    private let lyricsCacheStore = LyricsCacheStore.shared

    func skipToNextTrack() {
        _ = runSpotifyScript("""
        tell application "Spotify"
            if it is running then
                next track
            end if
        end tell
        """)
    }

    func skipToPreviousTrack() {
        _ = runSpotifyScript("""
        tell application "Spotify"
            if it is running then
                previous track
            end if
        end if
        """)
    }

    func togglePlayPause() {
        _ = runSpotifyScript("""
        tell application "Spotify"
            if it is running then
                playpause
            end if
        end tell
        """)
    }

    func prepareForSystemResume() {
        lyricsRequestSerial += 1
        activeLyricsRequestSerial = lyricsRequestSerial
        lyricsRequestInFlight = false
        resumeBaselineTrack = currentTrack
        resumeBaselineArtist = currentArtist
        resumeBaselineProgress = lastProgress
        resumeRecoveryDeadline = Date().addingTimeInterval(6.0)

        lastLineIndex = -1
        isSyncing = false
        pendingLyricsRequest = nil
        fetchRetryCount = 0
        lastLyricsFetchKey = nil
        lastLyricsFetchAt = .distantPast
        hasDisplayedLyricForCurrentTrack = false
        wasPaused = false
    }

    // MARK: - 获取当前播放信息

    /// 通过 AppleScript 获取 Spotify 当前播放信息
    func fetchNowPlaying() {
        let script = """
        tell application "Spotify"
            if it is running then
                set playerState to player state as text
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set trackDuration to duration of current track
                set playerPosition to player position
                return playerState & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & (trackDuration as text) & "|||" & (playerPosition as text)
            else
                return "not_running"
            end if
        end tell
        """

        guard let data = runSpotifyScriptAndCapture(script) else {
            return
        }
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }

        if output == "not_running" {
            recommendedPollInterval = 0.8
            lyricsRequestSerial += 1
            activeLyricsRequestSerial = lyricsRequestSerial
            lyricsRequestInFlight = false
            isSyncing = false
            lastLineIndex = -1
            wasPaused = false
            delegate?.spotifyNotRunning()
            return
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return }

        let playerState = parts[0]
        let track = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let durationMilliseconds = Double(parts[4]) ?? 0
        let progress = Double(parts[5]) ?? 0
        currentDuration = durationMilliseconds > 1000 ? durationMilliseconds / 1000.0 : durationMilliseconds

        let isRecoveringFromResume = Date() < resumeRecoveryDeadline
        if isRecoveringFromResume, track == resumeBaselineTrack, artist == resumeBaselineArtist {
            if abs(progress - resumeBaselineProgress) < 0.75 {
                return
            }
        }
        if isRecoveringFromResume {
            resumeRecoveryDeadline = .distantPast
        }

        let previousProgress = lastProgress
        lastProgress = progress

        let trackChanged = (track != currentTrack || artist != currentArtist)
        let seekJumped = abs(progress - previousProgress) > 1.2
        let isPlaying = playerState == "playing"
        let resumedFromPause = isPlaying && wasPaused
        wasPaused = !isPlaying
        currentTrack = track
        currentArtist = artist
        currentAlbum = album

        if !isPlaying {
            recommendedPollInterval = 0.4
        } else if currentLyrics != nil || isSyncing {
            recommendedPollInterval = 0.16
        } else {
            recommendedPollInterval = 0.26
        }

        if trackChanged {
            recommendedPollInterval = isPlaying ? 0.14 : 0.4
            lyricsRequestSerial += 1
            activeLyricsRequestSerial = lyricsRequestSerial
            lyricsRequestInFlight = false
            currentLyrics = nil
            lastLineIndex = -1
            isSyncing = false
            pendingLyricsRequest = nil
            fetchRetryCount = 0
            lastLyricsFetchKey = nil
            lastLyricsFetchAt = .distantPast
            hasDisplayedLyricForCurrentTrack = false
            delegate?.didUpdateNowPlaying(track: track, artist: artist, album: album, progress: progress, duration: currentDuration)
        } else if !isPlaying {
            return
        } else if isSyncing,
                  let lyrics = currentLyrics,
                  !lyrics.lines.isEmpty,
                  lyrics.track == track,
                  lyrics.artist == artist {
            syncLyrics(at: progress, forceRefresh: resumedFromPause || seekJumped)
        } else if seekJumped,
                  let lyrics = currentLyrics,
                  !lyrics.lines.isEmpty,
                  lyrics.track == track,
                  lyrics.artist == artist {
            syncLyrics(at: progress, forceRefresh: true)
        } else if resumedFromPause,
                  let lyrics = currentLyrics,
                  !lyrics.lines.isEmpty,
                  lyrics.track == track,
                  lyrics.artist == artist {
            isSyncing = true
            syncLyrics(at: progress, forceRefresh: true)
        } else if currentLyrics == nil {
            delegate?.didUpdateNowPlaying(track: track, artist: artist, album: album, progress: progress, duration: currentDuration)
        } else {
            retryLyricsFetchIfNeeded(track: track, artist: artist, album: album)
        }
    }

    // MARK: - 获取歌词

    func fetchLyrics(track: String, artist: String, album: String, duration: TimeInterval) {
        let requestKey = "\(track)|||\(artist)"

        if let currentLyrics = currentLyrics,
           currentLyrics.track == track,
           currentLyrics.artist == artist,
           !currentLyrics.lines.isEmpty {
            isSyncing = true
            lastLyricsFetchKey = requestKey
            lastLyricsFetchAt = Date()
            syncLyrics(at: lastProgress, forceRefresh: false)
            return
        }

        guard !lyricsRequestInFlight else { return }

        lyricsRequestSerial += 1
        activeLyricsRequestSerial = lyricsRequestSerial
        let requestSerial = activeLyricsRequestSerial
        pendingLyricsRequest = requestKey
        lastLyricsFetchKey = requestKey
        lastLyricsFetchAt = Date()

        if let diskCachedLyrics = lyricsCacheStore.load(track: track, artist: artist, album: album, duration: duration) {
            pendingLyricsRequest = nil
            lyricsRequestInFlight = false
            currentLyrics = diskCachedLyrics
            isSyncing = !diskCachedLyrics.lines.isEmpty
            lyricsCache[requestKey] = diskCachedLyrics
            lastLineIndex = -1
            fetchRetryCount = 0
            hasDisplayedLyricForCurrentTrack = false
            DispatchQueue.main.async {
                self.delegate?.didUpdateLyrics(diskCachedLyrics)
                if diskCachedLyrics.lines.isEmpty {
                    self.delegate?.didEnterPlaybackGap(track: track, artist: artist, instrumental: diskCachedLyrics.isInstrumental)
                } else {
                    self.syncLyrics(at: self.lastProgress)
                }
            }
            return
        }

        if let cachedLyrics = lyricsCache[requestKey] {
            pendingLyricsRequest = nil
            lyricsRequestInFlight = false
            currentLyrics = cachedLyrics
            isSyncing = !cachedLyrics.lines.isEmpty
            lastLineIndex = -1
            fetchRetryCount = 0
            hasDisplayedLyricForCurrentTrack = false
            DispatchQueue.main.async {
                self.delegate?.didUpdateLyrics(cachedLyrics)
                if cachedLyrics.lines.isEmpty {
                    self.delegate?.didEnterPlaybackGap(track: track, artist: artist, instrumental: cachedLyrics.isInstrumental)
                } else {
                    self.syncLyrics(at: self.lastProgress)
                }
            }
            return
        }

        lyricsRequestInFlight = true
        fetchLyricsFromLRCLib(track: track, artist: artist, album: album, duration: duration, requestSerial: requestSerial)
    }

    /// 从 LRCLib.net 获取时间同步歌词
    private func fetchLyricsFromLRCLib(track: String, artist: String, album: String, duration: TimeInterval, requestSerial: Int) {
        guard let preciseURL = preciseLyricsURL(track: track, artist: artist, album: album, duration: duration) else {
            return
        }
        let searchURLs = searchLyricsURLs(track: track, artist: artist, album: album)

        let requestKey = "\(track)|||\(artist)"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard self.activeLyricsRequestSerial == requestSerial else { return }
            guard self.pendingLyricsRequest == requestKey,
                  self.currentTrack == track,
                  self.currentArtist == artist else { return }

            if let preciseObject = self.fetchJSONObjectWithCurl(from: preciseURL) as? [String: Any],
               self.hasUsableLyricsPayload(preciseObject) {
                self.applyLyricsResult(
                    preciseObject,
                    requestKey: requestKey,
                    track: track,
                    artist: artist,
                    requestSerial: requestSerial
                )
                return
            }

            for searchURL in searchURLs {
                if let searchArray = self.fetchJSONObjectWithCurl(from: searchURL) as? [[String: Any]] {
                    let filtered = self.deduplicated(searchArray.filter(self.hasUsableLyricsPayload))
                    if let best = self.bestMatch(in: filtered, track: track, artist: artist, album: album, duration: duration) {
                        self.applyLyricsResult(
                            best,
                            requestKey: requestKey,
                            track: track,
                            artist: artist,
                            requestSerial: requestSerial
                        )
                        return
                    }
                }
            }

            self.handleNoLyrics(track: track, artist: artist, confirmedInstrumental: false, requestSerial: requestSerial)
        }
    }

    private func applyLyricsResult(_ result: [String: Any], requestKey: String, track: String, artist: String, requestSerial: Int) {
        guard activeLyricsRequestSerial == requestSerial else { return }
        guard pendingLyricsRequest == requestKey,
              currentTrack == track,
              currentArtist == artist else { return }

        if let syncLyrics = result["syncedLyrics"] as? String, !syncLyrics.isEmpty {
            let lines = LRCParser.parse(syncLyrics)
            if !lines.isEmpty {
                let lyricsData = LyricsData(lines: lines, track: track, artist: artist, isInstrumental: false, hasPreciseTiming: true)
                currentLyrics = lyricsData
                isSyncing = true
                lastLineIndex = -1
                lyricsCache[requestKey] = lyricsData
                lyricsCacheStore.store(
                    track: track,
                    artist: artist,
                    album: currentAlbum,
                    duration: currentDuration,
                    lyricsData: lyricsData,
                    rawLRCText: syncLyrics,
                    source: "syncedLyrics"
                )
                pendingLyricsRequest = nil
                lyricsRequestInFlight = false
                fetchRetryCount = 0
                hasDisplayedLyricForCurrentTrack = false
                DispatchQueue.main.async {
                    guard self.activeLyricsRequestSerial == requestSerial else { return }
                    self.delegate?.didUpdateLyrics(lyricsData)
                    self.syncLyrics(at: self.lastProgress)
                }
                return
            }
        }

        if let plainLyrics = result["plainLyrics"] as? String, !plainLyrics.isEmpty {
            parsePlainLyrics(plainLyrics, track: track, artist: artist, requestSerial: requestSerial)
        } else {
            handleNoLyrics(track: track, artist: artist, confirmedInstrumental: false, requestSerial: requestSerial)
        }
    }

    private func handleNoLyrics(track: String, artist: String, confirmedInstrumental: Bool, requestSerial: Int) {
        guard activeLyricsRequestSerial == requestSerial else { return }
        let lyricsData = LyricsData(lines: [], track: track, artist: artist, isInstrumental: confirmedInstrumental, hasPreciseTiming: false)
        self.pendingLyricsRequest = nil
        self.lyricsRequestInFlight = false
        self.currentLyrics = confirmedInstrumental ? lyricsData : nil
        self.isSyncing = false
        if confirmedInstrumental {
            self.lyricsCache["\(track)|||\(artist)"] = lyricsData
            self.lyricsCacheStore.store(
                track: track,
                artist: artist,
                album: currentAlbum,
                duration: currentDuration,
                lyricsData: lyricsData,
                rawLRCText: "# instrumental\n",
                source: "instrumental"
            )
            self.fetchRetryCount = 0
            self.hasDisplayedLyricForCurrentTrack = false
        } else {
            self.fetchRetryCount += 1
        }
        DispatchQueue.main.async {
            guard self.activeLyricsRequestSerial == requestSerial else { return }
            self.delegate?.didUpdateLyrics(lyricsData)
        }
    }

    /// 将普通歌词转为按时间间隔的行
    private func parsePlainLyrics(_ text: String, track: String, artist: String, requestSerial: Int) {
        guard activeLyricsRequestSerial == requestSerial else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let lines = rawLines.filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            handleNoLyrics(track: track, artist: artist, confirmedInstrumental: false, requestSerial: requestSerial)
            return
        }

        let totalDuration = max(currentDuration, 60.0)
        let pauseSlots = max(0, rawLines.count - lines.count)
        let pauseBudget = min(totalDuration * 0.18, Double(pauseSlots) * 1.8)
        let singingBudget = max(Double(lines.count) * 1.2, totalDuration - pauseBudget)

        let weights = lines.map { line in
            max(1.0, weightedCharacterCount(in: line))
        }
        let totalWeight = max(1.0, weights.reduce(0, +))

        var lyricsLines: [LyricsLine] = []
        var currentTime: TimeInterval = 0
        var lineIndex = 0

        for rawLine in rawLines {
            if rawLine.isEmpty {
                currentTime += pauseSlots > 0 ? (pauseBudget / Double(pauseSlots)) : 0.9
                continue
            }

            let weight = weights[lineIndex]
            let allocated = max(1.15, (weight / totalWeight) * singingBudget)
            let startTime = currentTime
            let endTime = min(totalDuration, startTime + allocated)
            lyricsLines.append(
                LyricsLine(
                    startTime: startTime,
                    endTime: max(startTime + 0.8, endTime),
                    text: rawLine
                )
            )
            currentTime = endTime
            lineIndex += 1
        }

        let lyricsData = LyricsData(lines: lyricsLines, track: track, artist: artist, isInstrumental: false, hasPreciseTiming: false)
        self.pendingLyricsRequest = nil
        self.lyricsRequestInFlight = false
        self.currentLyrics = lyricsData
        self.isSyncing = true
        self.lastLineIndex = -1
        self.lyricsCache["\(track)|||\(artist)"] = lyricsData
        self.lyricsCacheStore.store(
            track: track,
            artist: artist,
            album: currentAlbum,
            duration: currentDuration,
            lyricsData: lyricsData,
            rawLRCText: makeLRCText(from: lyricsLines),
            source: "plainLyricsV2"
        )
        self.fetchRetryCount = 0
        self.hasDisplayedLyricForCurrentTrack = false
        DispatchQueue.main.async {
            guard self.activeLyricsRequestSerial == requestSerial else { return }
            self.delegate?.didUpdateLyrics(lyricsData)
            self.syncLyrics(at: self.lastProgress)
        }
    }

    // MARK: - 同步歌词

    private func syncLyrics(at time: TimeInterval, forceRefresh: Bool = false) {
        guard let lyrics = currentLyrics,
              lyrics.track == currentTrack,
              lyrics.artist == currentArtist else {
            return
        }
        let adjustedTime = max(0, time + syncLead)
        let idx = lyrics.currentIndex(at: adjustedTime)
        let displayStartIndex = preferredDisplayStartIndex(in: lyrics)

        let resolvedIndex: Int
        if idx >= 0, idx < lyrics.lines.count {
            resolvedIndex = idx
        } else if let fallbackIndex = lyrics.fallbackIndex(at: adjustedTime) {
            resolvedIndex = fallbackIndex
        } else {
            lastLineIndex = -1
            if !hasDisplayedLyricForCurrentTrack || lyrics.isInstrumental {
                delegate?.didEnterPlaybackGap(track: lyrics.track, artist: lyrics.artist, instrumental: lyrics.isInstrumental)
            }
            return
        }

        if resolvedIndex < displayStartIndex {
            lastLineIndex = -1
            delegate?.didEnterPlaybackGap(track: lyrics.track, artist: lyrics.artist, instrumental: false)
            return
        }

        let current = lyrics.lines[resolvedIndex]
        let prev = resolvedIndex > 0 ? lyrics.lines[resolvedIndex - 1] : nil
        let next = (resolvedIndex + 1) < lyrics.lines.count ? lyrics.lines[resolvedIndex + 1] : nil
        let duration = max(0.01, current.endTime - current.startTime)

        if resolvedIndex == 0 && shouldHoldFirstLyric(current: current, adjustedTime: adjustedTime, lineDuration: duration) {
            lastLineIndex = -1
            delegate?.didEnterPlaybackGap(track: lyrics.track, artist: lyrics.artist, instrumental: false)
            return
        }

        let rawProgress = min(1.0, max(0.0, (adjustedTime - current.startTime) / duration))
        let progress = singingProgress(for: current.text, rawProgress: rawProgress, lineDuration: duration)

        if !forceRefresh && lastLineIndex == resolvedIndex {
            delegate?.didUpdateSyncLine(
                current: current,
                prev: prev,
                next: next,
                progress: progress,
                lineDuration: duration,
                hasPreciseTiming: lyrics.hasPreciseTiming
            )
            return
        }

        lastLineIndex = resolvedIndex
        hasDisplayedLyricForCurrentTrack = true
        delegate?.didUpdateSyncLine(
            current: current,
            prev: prev,
            next: next,
            progress: progress,
            lineDuration: duration,
            hasPreciseTiming: lyrics.hasPreciseTiming
        )
    }

    private func singingProgress(for text: String, rawProgress: Double, lineDuration: TimeInterval) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return rawProgress }

        let weightedLength = max(1.0, weightedCharacterCount(in: trimmed))
        let estimatedSingingDuration = estimatedVocalDuration(for: weightedLength)
        let slack = max(0.0, lineDuration - estimatedSingingDuration)

        // Keep the fill close to the vocal onset while avoiding visible early drift.
        let headSlack = min(0.02, max(0.0, (slack / max(0.01, lineDuration)) * 0.03))
        let tailSlack = min(0.10, max(0.005, (slack / max(0.01, lineDuration)) * 0.16))
        let effectiveStart = headSlack
        let effectiveEnd = max(effectiveStart + 0.12, 1.0 - tailSlack)

        if rawProgress <= effectiveStart {
            return 0
        }
        if rawProgress >= effectiveEnd {
            return 1
        }

        let normalized = (rawProgress - effectiveStart) / max(0.001, effectiveEnd - effectiveStart)
        return normalized * normalized * (3.0 - (2.0 * normalized))
    }

    private func shouldHoldFirstLyric(current: LyricsLine, adjustedTime: TimeInterval, lineDuration: TimeInterval) -> Bool {
        guard isLikelyIntroTaggedFirstLine(text: current.text, startTime: current.startTime, lineDuration: lineDuration) else {
            return false
        }

        let introHold = min(1.55, max(0.45, lineDuration * 0.58))
        return adjustedTime < current.startTime + introHold
    }

    private func isLikelyIntroTaggedFirstLine(text: String, startTime: TimeInterval, lineDuration: TimeInterval) -> Bool {
        guard startTime <= 0.25 else { return false }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let weightedLength = weightedCharacterCount(in: trimmed)
        let density = weightedLength / max(0.01, lineDuration)
        let containsLatin = trimmed.contains { $0.isLatinLetter }
        let containsCJK = trimmed.contains { $0.isCJK }

        if containsCJK {
            return lineDuration >= 1.9 && density <= 1.95
        }

        if !containsLatin {
            return lineDuration >= 2.0 && density <= 2.05
        }

        return lineDuration >= 2.4 && density <= 1.45
    }

    private func preferredDisplayStartIndex(in lyrics: LyricsData) -> Int {
        let lines = lyrics.lines
        guard lines.count >= 4 else { return 0 }
        guard lines[0].startTime <= 3.5 else { return 0 }

        for index in 1..<min(lines.count, 8) {
            let previous = lines[index - 1]
            let current = lines[index]
            let gapFromPrevious = current.startTime - previous.startTime

            guard gapFromPrevious >= 5.5 else { continue }

            let dialogueWindowEnd = min(lines.count - 1, index + 5)
            for candidate in index...dialogueWindowEnd {
                let line = lines[candidate]
                let weightedLength = weightedCharacterCount(in: line.text.trimmingCharacters(in: .whitespacesAndNewlines))
                let nextGap: TimeInterval
                if candidate + 1 < lines.count {
                    nextGap = lines[candidate + 1].startTime - line.startTime
                } else {
                    nextGap = 99
                }

                if weightedLength >= 10.5 && nextGap >= 4.0 {
                    return candidate
                }
            }
        }

        return 0
    }

    private func weightedCharacterCount(in text: String) -> Double {
        text.reduce(0) { partial, character in
            partial + weight(for: character)
        }
    }

    private func estimatedVocalDuration(for weightedLength: Double) -> TimeInterval {
        // Heuristic tuned for mixed Chinese/English lyrics on Touch Bar, not word-level timestamps.
        min(4.8, max(0.7, weightedLength * 0.17))
    }

    private func weight(for character: Character) -> Double {
        if character.isWhitespace {
            return 0.18
        }
        if character.isPunctuation {
            return 0.22
        }
        if character.isCJK {
            return 1.0
        }
        if character.isLatinLetter {
            return 0.62
        }
        if character.isNumber {
            return 0.56
        }
        return 0.8
    }

    private func retryLyricsFetchIfNeeded(track: String, artist: String, album: String) {
        let requestKey = "\(track)|||\(artist)"
        guard currentTrack == track, currentArtist == artist else { return }
        guard lyricsCache[requestKey] == nil else { return }
        guard !lyricsRequestInFlight else { return }
        guard pendingLyricsRequest == nil || pendingLyricsRequest == requestKey else { return }
        guard fetchRetryCount < 6 else { return }

        let minimumInterval = min(2.0, 0.35 + (Double(fetchRetryCount) * 0.25))
        if lastLyricsFetchKey != requestKey || Date().timeIntervalSince(lastLyricsFetchAt) >= minimumInterval {
            fetchLyrics(track: track, artist: artist, album: album, duration: currentDuration)
        }
    }

    private func bestMatch(in results: [[String: Any]], track: String, artist: String, album: String, duration: TimeInterval) -> [String: Any]? {
        guard !results.isEmpty else { return nil }

        let targetTrack = normalize(track)
        let targetArtist = normalize(artist)
        let targetAlbum = normalize(album)

        return results.max { lhs, rhs in
            score(result: lhs, targetTrack: targetTrack, targetArtist: targetArtist, targetAlbum: targetAlbum, targetDuration: duration) <
            score(result: rhs, targetTrack: targetTrack, targetArtist: targetArtist, targetAlbum: targetAlbum, targetDuration: duration)
        }
    }

    private func deduplicated(_ results: [[String: Any]]) -> [[String: Any]] {
        var seen = Set<String>()
        var output: [[String: Any]] = []

        for result in results {
            let key = [
                result["trackName"] as? String ?? "",
                result["artistName"] as? String ?? "",
                String(result["duration"] as? Double ?? 0),
                result["syncedLyrics"] as? String ?? "",
                result["plainLyrics"] as? String ?? "",
                String(result["instrumental"] as? Bool ?? false)
            ].joined(separator: "|||")

            if seen.insert(key).inserted {
                output.append(result)
            }
        }

        return output
    }

    private func score(result: [String: Any], targetTrack: String, targetArtist: String, targetAlbum: String, targetDuration: TimeInterval) -> Int {
        let resultTrack = normalize(result["trackName"] as? String ?? "")
        let resultArtist = normalize(result["artistName"] as? String ?? "")
        let resultAlbum = normalize(result["albumName"] as? String ?? "")
        let resultDuration = result["duration"] as? Double ?? 0

        var score = 0
        if resultTrack == targetTrack { score += 1000 }
        if resultArtist == targetArtist { score += 800 }
        if !targetAlbum.isEmpty && resultAlbum == targetAlbum { score += 550 }
        if resultTrack.contains(targetTrack) || targetTrack.contains(resultTrack) { score += 300 }
        if resultArtist.contains(targetArtist) || targetArtist.contains(resultArtist) { score += 220 }
        if !targetAlbum.isEmpty && (resultAlbum.contains(targetAlbum) || targetAlbum.contains(resultAlbum)) { score += 140 }
        if let synced = result["syncedLyrics"] as? String, !synced.isEmpty { score += 400 }
        if let plain = result["plainLyrics"] as? String, !plain.isEmpty { score += 80 }
        if let instrumental = result["instrumental"] as? Bool, instrumental { score += 120 }
        if resultDuration > 0, targetDuration > 0 {
            let diff = abs(resultDuration - targetDuration)
            if diff < 1.5 {
                score += 500
            } else if diff < 4 {
                score += 180
            } else {
                score -= Int(diff * 25)
            }
        }
        score -= abs(resultTrack.count - targetTrack.count) * 2
        score -= abs(resultArtist.count - targetArtist.count)
        return score
    }

    private func preciseLyricsURL(track: String, artist: String, album: String, duration: TimeInterval) -> URL? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album.isEmpty ? nil : album),
            URLQueryItem(name: "duration", value: duration > 0 ? String(Int(round(duration))) : nil)
        ].compactMap { item in
            guard let value = item.value, !value.isEmpty else { return nil }
            return item
        }
        return components.url
    }

    private func searchLyricsURLs(track: String, artist: String, album: String) -> [URL] {
        let queries: [String] = [
            [track, artist, album].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " "),
            [artist, track, album].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " "),
            [track, artist].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " "),
            [artist, track].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " "),
            track,
            artist
        ]

        return queries.compactMap { query in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var components = URLComponents(string: "https://lrclib.net/api/search")!
            components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            return components.url
        }
    }

    private func hasUsableLyricsPayload(_ result: [String: Any]) -> Bool {
        if let synced = result["syncedLyrics"] as? String, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let plain = result["plainLyrics"] as? String, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let instrumental = result["instrumental"] as? Bool, instrumental {
            return true
        }
        return false
    }

    private func fetchJSONObjectWithCurl(from url: URL) -> Any? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        task.arguments = [
            "-L",
            "--silent",
            "--show-error",
            "--max-time", "15",
            "--connect-timeout", "5",
            "--user-agent", "SpotifyOnTouchbar/1.0",
            url.absoluteString
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    @discardableResult
    private func runSpotifyScript(_ script: String) -> Bool {
        runSpotifyScriptAndCapture(script) != nil
    }

    private func runSpotifyScriptAndCapture(_ script: String) -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        return pipe.fileHandleForReading.readDataToEndOfFile()
    }

    private func normalize(_ value: String) -> String {
        let preserved = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"\(.*?\)|\[.*?\]|（.*?）"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"feat\.?|ft\.?|with|ver\.?|version|remaster(?:ed)?|live"#, with: "", options: [.regularExpression, .caseInsensitive])

        var output = String.UnicodeScalarView()
        output.reserveCapacity(preserved.unicodeScalars.count)
        for scalar in preserved.unicodeScalars {
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                output.append(scalar)
            }
        }

        return String(output)
            .lowercased(with: .current)
    }

    private func makeLRCText(from lines: [LyricsLine]) -> String {
        lines.map { line in
            "[\(formatTimestamp(line.startTime))] \(line.text)"
        }.joined(separator: "\n")
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let safeSeconds = max(0, seconds)
        let totalCentiseconds = Int((safeSeconds * 100.0).rounded())
        let minutes = totalCentiseconds / 6000
        let remainder = totalCentiseconds % 6000
        let secondsValue = remainder / 100
        let centiseconds = remainder % 100
        return String(format: "%02d:%02d.%02d", minutes, secondsValue, centiseconds)
    }

}

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    var isPunctuation: Bool {
        let punctuationMarks = CharacterSet.punctuationCharacters.union(.symbols)
        return unicodeScalars.allSatisfy { punctuationMarks.contains($0) }
    }

    var isNumber: Bool {
        unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    var isLatinLetter: Bool {
        unicodeScalars.allSatisfy { scalar in
            (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
        }
    }

    var isCJK: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF,
                 0x3040...0x30FF,
                 0x31F0...0x31FF,
                 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }
}
