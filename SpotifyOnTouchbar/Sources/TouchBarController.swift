import AppKit
import DFRPrivate

// MARK: - Touch Bar Controller

@available(macOS 10.12.2, *)
class TouchBarController: NSObject, NSTouchBarDelegate {

    private var touchBar: NSTouchBar!
    private var systemTrayItem: NSCustomTouchBarItem!
    private var containerView: NSView!
    private var controlsView: NSView!

    // Lyrics view
    private var lyricsView: LyricsTextView!
    private weak var spotifyController: SpotifyController?

    private let trayIdentifier = NSTouchBarItem.Identifier("com.spotifylyrics.tray")
    private let controlsIdentifier = NSTouchBarItem.Identifier("com.spotifylyrics.controls")
    private let lyricsIdentifier = NSTouchBarItem.Identifier("com.spotifylyrics.content")

    init(spotifyController: SpotifyController) {
        self.spotifyController = spotifyController
        super.init()
        setupTouchBar()
        setupSystemTray()
        present()
    }

    private func setupTouchBar() {
        touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [controlsIdentifier, lyricsIdentifier]
    }

    private func setupSystemTray() {
        systemTrayItem = NSCustomTouchBarItem(identifier: trayIdentifier)
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.focusRingType = .none
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.borderWidth = 0
        button.layer?.cornerRadius = 0
        button.layer?.masksToBounds = false

        if let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Lyrics")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)) {
            image.isTemplate = true
            button.image = image
        }

        button.frame = NSRect(x: 0, y: 0, width: 28, height: 28)
        button.target = self
        button.action = #selector(trayButtonTapped)
        systemTrayItem.view = button
        systemTrayItem.addToSystemTray()
    }

    @objc private func trayButtonTapped() {
        present()
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == controlsIdentifier {
            let item = NSCustomTouchBarItem(identifier: identifier)

            controlsView = NSView(frame: NSRect(x: 0, y: 0, width: 82, height: 34))
            controlsView.wantsLayer = true
            controlsView.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.06).cgColor
            controlsView.layer?.cornerRadius = 12
            controlsView.layer?.borderWidth = 0.5
            controlsView.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor
            controlsView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
            controlsView.layer?.shadowOpacity = 1
            controlsView.layer?.shadowRadius = 5
            controlsView.layer?.shadowOffset = CGSize(width: 0, height: 1)

            let stack = NSStackView(frame: controlsView.bounds)
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.distribution = .fillEqually
            stack.spacing = 2
            stack.translatesAutoresizingMaskIntoConstraints = false

            let previousButton = makeActionButton(
                symbol: "backward.fill",
                accessibility: "上一首",
                action: #selector(previousTrackTapped)
            )
            let nextButton = makeActionButton(
                symbol: "forward.fill",
                accessibility: "下一首",
                action: #selector(nextTrackTapped)
            )

            stack.addArrangedSubview(previousButton)
            stack.addArrangedSubview(nextButton)
            controlsView.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: controlsView.leadingAnchor, constant: 3),
                stack.trailingAnchor.constraint(equalTo: controlsView.trailingAnchor, constant: -3),
                stack.topAnchor.constraint(equalTo: controlsView.topAnchor, constant: 4),
                stack.bottomAnchor.constraint(equalTo: controlsView.bottomAnchor, constant: -4)
            ])

            item.view = controlsView
            return item
        }

        guard identifier == lyricsIdentifier else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 48))
        containerView.wantsLayer = true

        lyricsView = LyricsTextView(frame: NSRect(x: 0, y: 0, width: 560, height: 48))
        lyricsView.font = makeKaiFont(size: 16, weight: .medium)
        lyricsView.textColor = .white
        lyricsView.highlightColor = NSColor(calibratedRed: 0.36, green: 0.96, blue: 0.48, alpha: 1.0)
        lyricsView.verticalOffset = -7
        lyricsView.horizontalPadding = 8
        lyricsView.tapAction = { [weak self] in
            self?.togglePlaybackTapped()
        }
        containerView.addSubview(lyricsView)

        item.view = containerView
        return item
    }

    private func makeActionButton(symbol: String, accessibility: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.focusRingType = .none
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.borderWidth = 0
        button.layer?.cornerRadius = 0
        button.layer?.masksToBounds = false

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibility)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)) {
            image.isTemplate = true
            button.image = image
        }

        button.toolTip = accessibility
        button.contentTintColor = .white
        button.target = self
        button.action = action
        button.frame = NSRect(x: 0, y: 0, width: 32, height: 26)

        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.00).cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 0
        button.layer?.masksToBounds = false
        return button
    }

    @objc private func togglePlaybackTapped() {
        spotifyController?.togglePlayPause()
    }

    @objc private func previousTrackTapped() {
        spotifyController?.skipToPreviousTrack()
    }

    @objc private func nextTrackTapped() {
        spotifyController?.skipToNextTrack()
    }

    // MARK: - Presentation

    func present() {
        NSTouchBar.setSystemModalShowsCloseBoxWhenFrontMost(false)
        touchBar.presentAsSystemModal(for: systemTrayItem)
    }

    func dismiss() {
        touchBar.dismissSystemModal()
    }

    // MARK: - Update Methods

    func updateLyrics(_ text: String, syncing: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            self?.lyricsView?.stopProgressTimer()
            self?.lyricsView?.font = self?.makeKaiFont(size: syncing ? 16 : 15, weight: .medium) ?? NSFont.systemFont(ofSize: syncing ? 16 : 15, weight: .medium)
            self?.lyricsView?.textColor = syncing ? .white : .lightGray
            self?.lyricsView?.lineDuration = 0
            self?.lyricsView?.progress = 0
            self?.lyricsView?.allowsTapToggle = false
            self?.lyricsView?.text = text
            self?.lyricsView?.needsDisplay = true
        }
    }

    func updateLyrics(_ lyrics: LyricsData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lyricsView?.stopProgressTimer()

            if lyrics.isInstrumental {
                self.showTrackInfo(track: lyrics.track, artist: lyrics.artist, instrumental: true)
                return
            }

            if self.preferredDisplayStartIndex(in: lyrics) > 0 || self.shouldDelayFirstLyricDisplay(lyrics) {
                self.showTrackInfo(track: lyrics.track, artist: lyrics.artist, instrumental: false)
                return
            }

            self.lyricsView?.font = self.makeKaiFont(size: 16, weight: .medium)
            self.lyricsView?.textColor = .white
            self.lyricsView?.allowsTapToggle = false
            self.lyricsView?.lineDuration = 0
            self.lyricsView?.progress = 0

            if let firstLine = lyrics.lines.first?.text, !firstLine.isEmpty {
                self.lyricsView?.text = firstLine
            } else {
                self.lyricsView?.text = AppLocalization.shared.string(.loadingLyrics)
            }

            self.lyricsView?.needsDisplay = true
        }
    }

    func highlightLine(_ line: LyricsLine, prev: LyricsLine?, next: LyricsLine?, progress: Double, lineDuration: TimeInterval, hasPreciseTiming: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.lyricsView?.font = self?.makeKaiFont(size: 16, weight: .medium) ?? NSFont.systemFont(ofSize: 16, weight: .medium)
            self?.lyricsView?.textColor = .white
            self?.lyricsView?.allowsTapToggle = true
            self?.lyricsView?.text = line.text
            self?.lyricsView?.lineDuration = lineDuration
            self?.lyricsView?.progress = progress
            self?.lyricsView?.needsDisplay = true
        }
    }

    func showTrackInfo(track: String, artist: String, instrumental: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.lyricsView?.stopProgressTimer()
            self?.lyricsView?.font = self?.makeKaiFont(size: 16, weight: .medium) ?? NSFont.systemFont(ofSize: 16, weight: .medium)
            self?.lyricsView?.textColor = instrumental ? .systemYellow : .white
            self?.lyricsView?.allowsTapToggle = false
            self?.lyricsView?.lineDuration = 0
            self?.lyricsView?.text = instrumental ? "♪ \(track)" : "♪ \(track) — \(artist)"
            self?.lyricsView?.progress = 0
            self?.lyricsView?.horizontalPadding = 8
            self?.lyricsView?.needsDisplay = true
        }
    }

    private func shouldDelayFirstLyricDisplay(_ lyrics: LyricsData) -> Bool {
        guard let firstLine = lyrics.lines.first else { return false }
        let firstLineDuration = max(0, firstLine.endTime - firstLine.startTime)
        guard firstLine.startTime <= 0.25 else { return false }

        let trimmed = firstLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let nonWhitespaceCount = Double(trimmed.filter { !$0.isWhitespace }.count)
        let density = nonWhitespaceCount / max(0.01, firstLineDuration)
        let containsLatin = trimmed.contains { $0.isLatinLetter }
        let containsCJK = trimmed.contains { $0.isCJK }

        if containsCJK {
            return firstLineDuration >= 1.9 && density <= 2.0
        }

        if !containsLatin {
            return firstLineDuration >= 2.0 && density <= 2.1
        }

        return firstLineDuration >= 2.4 && density <= 1.5
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
                let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let visibleCount = Double(trimmed.filter { !$0.isWhitespace }.count)
                let nextGap: TimeInterval
                if candidate + 1 < lines.count {
                    nextGap = lines[candidate + 1].startTime - line.startTime
                } else {
                    nextGap = 99
                }

                if visibleCount >= 10.0 && nextGap >= 4.0 {
                    return candidate
                }
            }
        }

        return 0
    }

    // MARK: - Helpers

    private func makeKaiFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let preferredFamilies = [
            "Kaiti SC",
            "STKaiti",
            "KaiTi",
            "BiauKai",
            "Songti SC"
        ]

        for family in preferredFamilies {
            if let font = NSFont(name: family, size: size) {
                return font
            }
        }

        return NSFont.systemFont(ofSize: size, weight: weight)
    }
}

private final class LyricsTextView: NSView {
    var text: String = ""
    var font: NSFont = NSFont.systemFont(ofSize: 16, weight: .medium)
    var textColor: NSColor = .white
    var highlightColor: NSColor = .systemGreen
    var allowsTapToggle: Bool = false
    var tapAction: (() -> Void)?
    var progress: Double = 0 {
        didSet {
            let clamped = min(1.0, max(0.0, progress))
            let now = ProcessInfo.processInfo.systemUptime
            syncReferenceTime = now

            if clamped <= displayedProgress {
                displayedProgress = clamped
                syncReferenceProgress = clamped
                needsDisplay = true
                return
            }

            syncReferenceProgress = clamped
            startDisplayTimerIfNeeded()
        }
    }
    var verticalOffset: CGFloat = 0
    var horizontalPadding: CGFloat = 16
    var lineDuration: TimeInterval = 0.0

    private var displayedProgress: Double = 0
    private var syncReferenceProgress: Double = 0
    private var syncReferenceTime: TimeInterval = 0
    private var displayTimer: Timer?
    private var tapFeedback: Double = 0
    private var tapFeedbackTimer: Timer?
    private var lastTapTriggeredAt: TimeInterval = 0
    private let tapButton = NSButton(frame: .zero)
    private var cachedLayoutBounds: CGSize = .zero
    private var cachedLayoutText: String = ""
    private var cachedLayoutFontName: String = ""
    private var cachedLayoutPadding: CGFloat = 0
    private var cachedLayoutOffset: CGFloat = 0
    private var cachedTextRect: NSRect = .zero
    private var cachedHitRect: NSRect = .zero

    deinit {
        displayTimer?.invalidate()
        tapFeedbackTimer?.invalidate()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureTapButton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureTapButton() {
        tapButton.isBordered = false
        tapButton.bezelStyle = .shadowlessSquare
        tapButton.title = ""
        tapButton.image = nil
        tapButton.alphaValue = 0.02
        tapButton.focusRingType = .none
        tapButton.setButtonType(.momentaryChange)
        tapButton.target = self
        tapButton.action = #selector(handleTapButton)
        addSubview(tapButton)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !text.isEmpty else { return }
        updateLayoutCacheIfNeeded()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.32)
        shadow.shadowBlurRadius = 0
        shadow.shadowOffset = NSSize(width: 0, height: 0)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
            .shadow: shadow,
            .strokeColor: NSColor(calibratedWhite: 0, alpha: 0.35),
            .strokeWidth: -0.7
        ]

        let attributed = NSAttributedString(string: text, attributes: attrs)
        let rect = cachedTextRect
        tapButton.frame = cachedHitRect
        tapButton.isHidden = !allowsTapToggle
        if tapFeedback > 0.001 {
            let tapRect = rect.insetBy(dx: -8, dy: -5)
            let tapPath = NSBezierPath(roundedRect: tapRect, xRadius: 8, yRadius: 8)
            highlightColor.withAlphaComponent(0.12 * tapFeedback).setFill()
            tapPath.fill()
        }

        if let context = NSGraphicsContext.current?.cgContext {
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(true)
            context.setShouldSmoothFonts(true)
        }

        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])

        let displayProgress = transformedProgress(for: text, linearProgress: displayedProgress)
        if displayProgress > 0 {
            let highlightAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: highlightColor,
                .paragraphStyle: paragraph,
                .shadow: shadow,
                .strokeColor: NSColor(calibratedWhite: 0, alpha: 0.2),
                .strokeWidth: -0.45
            ]
            let highlightAttributed = NSAttributedString(string: text, attributes: highlightAttrs)
            let highlightWidth = floor(rect.width * displayProgress)
            let clipRect = NSRect(x: rect.minX, y: rect.minY, width: highlightWidth, height: rect.height)

            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.clip(to: clipRect)
                highlightAttributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
                context.restoreGState()
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            displayTimer?.invalidate()
            displayTimer = nil
        }
    }

    private func startDisplayTimerIfNeeded() {
        guard displayTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.updateDisplayedProgressFromClock()
            self.needsDisplay = true
        }

        displayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopProgressTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    func flashTapFeedback() {
        tapFeedbackTimer?.invalidate()
        tapFeedback = 1.0
        needsDisplay = true

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.tapFeedback = max(0.0, self.tapFeedback - max(0.12, self.tapFeedback * 0.36))
            self.needsDisplay = true
            if self.tapFeedback <= 0.01 {
                self.tapFeedback = 0
                self.needsDisplay = true
                timer.invalidate()
                self.tapFeedbackTimer = nil
            }
        }

        tapFeedbackTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func handleTapButton() {
        triggerTapAction()
    }

    private func triggerTapAction() {
        guard allowsTapToggle else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTapTriggeredAt > 0.18 else { return }
        lastTapTriggeredAt = now
        flashTapFeedback()
        tapAction?()
    }

    private func transformedProgress(for text: String, linearProgress: Double) -> Double {
        let clamped = min(1.0, max(0.0, linearProgress))
        let characters = Array(text)
        guard characters.count > 1 else { return clamped }

        let weights = characters.enumerated().map { index, character in
            characterWeight(character, isLast: index == characters.count - 1)
        }
        let totalWeight = max(0.001, weights.reduce(0, +))
        let targetWeight = smoothedProgress(clamped) * totalWeight

        var consumedWeight = 0.0
        for (index, weight) in weights.enumerated() {
            let nextWeight = consumedWeight + weight
            if targetWeight <= nextWeight {
                let localProgress = (targetWeight - consumedWeight) / max(0.001, weight)
                return (Double(index) + localProgress) / Double(weights.count)
            }
            consumedWeight = nextWeight
        }

        return 1.0
    }

    private func updateDisplayedProgressFromClock() {
        guard lineDuration > 0 else {
            displayedProgress = syncReferenceProgress
            stopProgressTimer()
            return
        }

        let duration = max(0.01, lineDuration)
        let elapsed = max(0.0, ProcessInfo.processInfo.systemUptime - syncReferenceTime)
        let advanced = min(1.0, syncReferenceProgress + (elapsed / duration))

        if advanced <= displayedProgress {
            displayedProgress = advanced
            return
        }

        displayedProgress = advanced
    }

    private func smoothedProgress(_ value: Double) -> Double {
        value * value * (3.0 - (2.0 * value))
    }

    private func characterWeight(_ character: Character, isLast: Bool) -> Double {
        if character.isWhitespace {
            return 0.2
        }

        if character.isPunctuation {
            return isLast ? 0.55 : 0.3
        }

        if character.isCJK {
            return isLast ? 1.15 : 1.0
        }

        if character.isLatinVowel {
            return isLast ? 1.2 : 1.0
        }

        if character.isLatinLetter {
            return isLast ? 1.0 : 0.82
        }

        if character.isNumber {
            return 0.8
        }

        return isLast ? 1.05 : 0.92
    }

    private func updateLayoutCacheIfNeeded() {
        let fontKey = "\(font.fontName)|\(font.pointSize)"
        guard cachedLayoutBounds != bounds.size
                || cachedLayoutText != text
                || cachedLayoutFontName != fontKey
                || cachedLayoutPadding != horizontalPadding
                || cachedLayoutOffset != verticalOffset
        else {
            return
        }

        cachedLayoutBounds = bounds.size
        cachedLayoutText = text
        cachedLayoutFontName = fontKey
        cachedLayoutPadding = horizontalPadding
        cachedLayoutOffset = verticalOffset

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]

        let attributed = NSAttributedString(string: text, attributes: attrs)
        let maxWidth = bounds.width - (horizontalPadding * 2)
        let measured = attributed.boundingRect(
            with: NSSize(width: maxWidth, height: bounds.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let textWidth = min(maxWidth, ceil(measured.width))
        let textHeight = min(bounds.height, ceil(measured.height))
        let x = floor((bounds.width - textWidth) / 2.0) - 26
        let y = floor((bounds.height - textHeight) / 2.0 + verticalOffset)
        cachedTextRect = NSRect(
            x: x,
            y: y,
            width: floor(textWidth),
            height: floor(textHeight)
        ).integral
        cachedHitRect = NSRect(x: x - 6, y: y - 4, width: floor(textWidth) + 12, height: floor(textHeight) + 8).integral
    }
}

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    var isPunctuation: Bool {
        let punctuationMarks = CharacterSet.punctuationCharacters
            .union(.symbols)
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

    var isLatinVowel: Bool {
        let vowels = "aeiouAEIOU"
        return String(self).unicodeScalars.allSatisfy { scalar in
            vowels.unicodeScalars.contains(scalar)
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
                 0xAC00...0xD7AF,
                 0x0E00...0x0E7F,
                 0x0600...0x06FF,
                 0x0750...0x077F,
                 0x08A0...0x08FF,
                 0x0400...0x04FF,
                 0x0590...0x05FF,
                 0x0900...0x097F:
                return true
            default:
                return false
            }
        }
    }
}
