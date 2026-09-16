import Foundation
import AppKit

final class LaunchAgentManager {
    static let shared = LaunchAgentManager()

    private let agentLabel = "com.touchbarlyrics.spotifyfollow"
    private let legacyLabels = [
        "com.steven.touchbarlyrics-follow",
        "com.touchbarlyrics.spotifywatcher"
    ]
    private let defaultsAutoFollowKey = "autoFollowSpotify"

    private var launchAgentsDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents")
    }

    private var plistURL: URL {
        return launchAgentsDirectory.appendingPathComponent("\(agentLabel).plist")
    }

    private var appSupportDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/SpotifyOnTouchbar")
    }

    private var scriptURL: URL {
        return appSupportDirectory.appendingPathComponent("spotify-follow.sh")
    }

    var isAutoFollowEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: defaultsAutoFollowKey) == nil {
                return true // 默认开启
            }
            return UserDefaults.standard.bool(forKey: defaultsAutoFollowKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsAutoFollowKey)
            if newValue {
                installAndEnable()
            } else {
                disableAndRemove()
            }
        }
    }

    private init() {}

    func setupInitialState() {
        // 清理旧的遗留 Agent（如果有）
        cleanLegacyAgents()

        if isAutoFollowEnabled {
            installAndEnable()
        }
    }

    func toggleAutoFollow() {
        isAutoFollowEnabled = !isAutoFollowEnabled
    }

    private func cleanLegacyAgents() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        for label in legacyLabels {
            let oldPlist = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
            if fileManager.fileExists(atPath: oldPlist.path) {
                runCommand("/bin/launchctl", ["bootout", "gui/\(getuid())", oldPlist.path])
                runCommand("/bin/launchctl", ["unload", oldPlist.path])
                try? fileManager.removeItem(at: oldPlist)
            }
        }
    }

    private func installAndEnable() {
        let fileManager = FileManager.default

        // 1. 创建 Application Support 目录
        try? fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true, attributes: nil)

        // 2. 写入守护 shell 脚本
        let scriptContent = """
        #!/bin/zsh
        set -euo pipefail

        # 检查 Spotify 是否正在运行
        if pgrep -x Spotify >/dev/null 2>&1; then
            if ! pgrep -x "Spotify on Touchbar" >/dev/null 2>&1; then
                /usr/bin/open -gja "/Applications/Spotify on Touchbar.app" >/dev/null 2>&1 || true
            fi
        else
            if pgrep -x "Spotify on Touchbar" >/dev/null 2>&1; then
                /usr/bin/osascript -e 'tell application "Spotify on Touchbar" to quit' >/dev/null 2>&1 || true
            fi
        fi
        """

        try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        let permissions: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try? fileManager.setAttributes(permissions, ofItemAtPath: scriptURL.path)

        // 3. 写入 LaunchAgent plist
        let logsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
        let outLog = logsDir.appendingPathComponent("spotify-follow.out.log").path
        let errLog = logsDir.appendingPathComponent("spotify-follow.err.log").path

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(scriptURL.path)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>StartInterval</key>
            <integer>5</integer>
            <key>StandardOutPath</key>
            <string>\(outLog)</string>
            <key>StandardErrorPath</key>
            <string>\(errLog)</string>
            <key>LimitLoadToSessionType</key>
            <string>Aqua</string>
        </dict>
        </plist>
        """

        try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)

        // 4. 加载 LaunchAgent
        runCommand("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
        runCommand("/bin/launchctl", ["unload", plistURL.path])
        let bootstrapStatus = runCommand("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
        if bootstrapStatus != 0 {
            runCommand("/bin/launchctl", ["load", "-w", plistURL.path])
        }
        runCommand("/bin/launchctl", ["enable", "gui/\(getuid())/\(agentLabel)"])
    }

    private func disableAndRemove() {
        let fileManager = FileManager.default
        runCommand("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
        runCommand("/bin/launchctl", ["unload", plistURL.path])
        try? fileManager.removeItem(at: plistURL)
        try? fileManager.removeItem(at: scriptURL)
    }

    @discardableResult
    private func runCommand(_ command: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
