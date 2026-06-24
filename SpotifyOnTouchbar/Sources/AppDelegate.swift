import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var touchBarController: TouchBarController?
    var spotifyController: SpotifyController!
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var wakeRecoveryWorkItems: [DispatchWorkItem] = []
    private var lastWakeRefreshAt: Date = .distantPast
    private var wakeRecoveryToken = UUID()
    private var pollToken = UUID()
    private var pollingEnabled = false
    private let localization = AppLocalization.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        if shouldTerminateForExistingInstance() {
            NSApplication.shared.terminate(nil)
            return
        }

        spotifyController = SpotifyController()
        spotifyController.delegate = self

        // 尝试初始化 Touch Bar（仅在支持的机型上）
        if #available(macOS 10.12.2, *) {
            touchBarController = TouchBarController(spotifyController: spotifyController)
        }

        setupStatusBar()
        setupLifecycleObservers()
        startPolling()
    }

    deinit {
        removeLifecycleObservers()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note.tv", accessibilityDescription: "Spotify on Touchbar")
            button.action = #selector(statusBarClicked(_:))
        }
        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: localization.string(.appTitle), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        if touchBarController != nil {
            let showTouchBarItem = NSMenuItem(title: localization.string(.showTouchBarLyrics), action: #selector(showTouchBar(_:)), keyEquivalent: "t")
            showTouchBarItem.target = self
            menu.addItem(showTouchBarItem)
        }

        let languageItem = NSMenuItem(title: localization.string(.languageMenu), action: nil, keyEquivalent: "")
        languageItem.submenu = buildLanguageMenu()
        menu.addItem(languageItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: localization.string(.quit), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func buildLanguageMenu() -> NSMenu {
        let menu = NSMenu(title: localization.string(.languageMenu))
        let systemItem = NSMenuItem(title: localization.string(.followSystem), action: #selector(selectLanguage(_:)), keyEquivalent: "")
        systemItem.target = self
        systemItem.representedObject = AppLanguage.system.rawValue
        systemItem.state = localization.currentLanguage == .system ? .on : .off
        menu.addItem(systemItem)

        menu.addItem(NSMenuItem.separator())

        for language in AppLanguage.allCases {
            guard language != .system else { continue }
            let item = NSMenuItem(title: language.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == localization.currentLanguage ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc func statusBarClicked(_ sender: Any) {
        buildMenu()
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func showTouchBar(_ sender: NSMenuItem) {
        if #available(macOS 10.12.2, *) {
            touchBarController?.present()
        }
    }

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else { return }
        localization.setLanguage(language)
        buildMenu()
    }

    @objc func quit() {
        stopPolling()
        NSApplication.shared.terminate(nil)
    }

    func startPolling() {
        stopPolling()
        pollingEnabled = true
        let token = UUID()
        pollToken = token
        schedulePollingTick(after: 0.0, token: token)
    }

    func stopPolling() {
        pollingEnabled = false
        pollToken = UUID()
    }

    private func schedulePollingTick(after delay: TimeInterval, token: UUID) {
        guard pollingEnabled, pollToken == token else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.pollingEnabled, self.pollToken == token else { return }
            self.spotifyController.fetchNowPlaying()
            let nextDelay = max(0.12, self.spotifyController.recommendedPollInterval)
            self.schedulePollingTick(after: nextDelay, token: token)
        }
    }

    private func setupLifecycleObservers() {
        removeLifecycleObservers()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cancelWakeRecoveryBurst()
        }

        let didWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNowPlayingAfterWake()
        }

        let wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNowPlayingAfterWake()
        }

        let activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNowPlayingAfterWake()
        }

        let sessionObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNowPlayingAfterWake()
        }

        lifecycleObservers = [sleepObserver, didWakeObserver, wakeObserver, activeObserver, sessionObserver]
    }

    private func removeLifecycleObservers() {
        cancelWakeRecoveryBurst()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in lifecycleObservers {
            workspaceCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
    }

    private func refreshNowPlayingAfterWake() {
        let now = Date()
        if now.timeIntervalSince(lastWakeRefreshAt) < 1.5 {
            return
        }
        lastWakeRefreshAt = now
        wakeRecoveryToken = UUID()
        cancelWakeRecoveryBurst()
        spotifyController.prepareForSystemResume()
        touchBarController?.updateLyrics(localization.string(.syncingSpotify), syncing: false)

        let token = wakeRecoveryToken
        let delays: [TimeInterval] = [0.0, 0.25, 0.75, 1.5, 3.0, 5.0]
        wakeRecoveryWorkItems = delays.map { delay in
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.wakeRecoveryToken == token else { return }
                self.spotifyController.fetchNowPlaying()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            return workItem
        }
    }

    private func cancelWakeRecoveryBurst() {
        wakeRecoveryToken = UUID()
        for item in wakeRecoveryWorkItems {
            item.cancel()
        }
        wakeRecoveryWorkItems.removeAll()
    }

    private func shouldTerminateForExistingInstance() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        return running.contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}

// MARK: - SpotifyControllerDelegate

extension AppDelegate: SpotifyControllerDelegate {
    func didUpdateNowPlaying(track: String, artist: String, album: String, progress: TimeInterval, duration: TimeInterval) {
        cancelWakeRecoveryBurst()
        touchBarController?.showTrackInfo(track: track, artist: artist, instrumental: false)
        spotifyController.fetchLyrics(track: track, artist: artist, album: album, duration: duration)
    }

    func didUpdateLyrics(_ lyrics: LyricsData) {
        cancelWakeRecoveryBurst()
        if lyrics.lines.isEmpty {
            if lyrics.isInstrumental {
                touchBarController?.showTrackInfo(track: lyrics.track, artist: lyrics.artist, instrumental: true)
            } else {
                touchBarController?.showTrackInfo(track: lyrics.track, artist: lyrics.artist, instrumental: false)
            }
            return
        }

        if let tb = touchBarController {
            tb.updateLyrics(lyrics)
        }
    }

    func didUpdateSyncLine(current line: LyricsLine, prev: LyricsLine?, next: LyricsLine?, progress: Double, lineDuration: TimeInterval, hasPreciseTiming: Bool) {
        cancelWakeRecoveryBurst()
        if let tb = touchBarController {
            tb.highlightLine(line, prev: prev, next: next, progress: progress, lineDuration: lineDuration, hasPreciseTiming: hasPreciseTiming)
        }
    }

    func didEnterPlaybackGap(track: String, artist: String, instrumental: Bool) {
        cancelWakeRecoveryBurst()
        touchBarController?.showTrackInfo(track: track, artist: artist, instrumental: instrumental)
    }

    func spotifyNotRunning() {
        cancelWakeRecoveryBurst()
        touchBarController?.updateLyrics(localization.string(.spotifyNotRunning), syncing: false)
    }

    func noActiveTrack() {
        cancelWakeRecoveryBurst()
        if let tb = touchBarController {
            tb.updateLyrics(localization.string(.notPlaying), syncing: false)
        }
    }
}
