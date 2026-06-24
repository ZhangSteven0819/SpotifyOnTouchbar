import Foundation

// LRC 歌词解析器
class LRCParser {
    /// 解析 LRC 格式的同步歌词文本
    static func parse(_ lrcText: String) -> [LyricsLine] {
        var lines: [LyricsLine] = []
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return lines }

        let nsString = lrcText as NSString
        let matches = regex.matches(in: lrcText, options: [], range: NSRange(location: 0, length: nsString.length))

        for (i, match) in matches.enumerated() {
            guard match.numberOfRanges >= 5 else { continue }

            let minStr = nsString.substring(with: match.range(at: 1))
            let secStr = nsString.substring(with: match.range(at: 2))
            var msStr = "0"
            if match.range(at: 3).location != NSNotFound {
                msStr = nsString.substring(with: match.range(at: 3))
            }
            let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

            guard let min = Int(minStr), let sec = Int(secStr), let ms = Int(msStr) else { continue }

            let msVal = msStr.count <= 2 ? ms * 10 : ms
            let startTime = Double(min * 60 + sec) + Double(msVal) / 1000.0

            // 计算结束时间：下一个时间戳
            let endTime: TimeInterval
            if i + 1 < matches.count {
                let nextMatch = matches[i + 1]
                let nMin = Int(nsString.substring(with: nextMatch.range(at: 1))) ?? 0
                let nSec = Int(nsString.substring(with: nextMatch.range(at: 2))) ?? 0
                var nMsStr = "0"
                if nextMatch.range(at: 3).location != NSNotFound {
                    nMsStr = nsString.substring(with: nextMatch.range(at: 3))
                }
                let nMs = Int(nMsStr) ?? 0
                let nMsVal = nMsStr.count <= 2 ? nMs * 10 : nMs
                endTime = Double(nMin * 60 + nSec) + Double(nMsVal) / 1000.0
            } else {
                endTime = startTime + 5.0
            }

            guard !text.isEmpty else { continue }
            lines.append(LyricsLine(startTime: startTime, endTime: endTime, text: text))
        }

        return lines
    }
}
