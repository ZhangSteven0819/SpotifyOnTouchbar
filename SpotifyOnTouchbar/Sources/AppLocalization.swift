import Foundation

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        }
    }
}

final class AppLocalization {
    static let shared = AppLocalization()

    private let defaultsKey = "appLanguage"

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: defaultsKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: defaultsKey)
        self.currentLanguage = AppLanguage(rawValue: stored ?? "") ?? .system
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }

    func string(_ key: Key) -> String {
        switch resolvedLanguage() {
        case .system:
            return key.defaultValue
        case .english:
            return english[key] ?? key.defaultValue
        case .simplifiedChinese:
            return simplifiedChinese[key] ?? key.defaultValue
        case .traditionalChinese:
            return traditionalChinese[key] ?? key.defaultValue
        case .japanese:
            return japanese[key] ?? key.defaultValue
        case .korean:
            return korean[key] ?? key.defaultValue
        case .spanish:
            return spanish[key] ?? key.defaultValue
        case .french:
            return french[key] ?? key.defaultValue
        case .german:
            return german[key] ?? key.defaultValue
        case .portuguese:
            return portuguese[key] ?? key.defaultValue
        }
    }

    func resolvedLanguage() -> AppLanguage {
        guard currentLanguage == .system else { return currentLanguage }
        return systemPreferredLanguage()
    }

    private func systemPreferredLanguage() -> AppLanguage {
        for code in Locale.preferredLanguages {
            let normalized = code.lowercased()
            if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") || normalized.hasPrefix("zh-mo") {
                return .traditionalChinese
            }
            if normalized.hasPrefix("zh-hans") || normalized.hasPrefix("zh-cn") || normalized.hasPrefix("zh-sg") || normalized.hasPrefix("zh") {
                return .simplifiedChinese
            }
            if normalized.hasPrefix("ja") { return .japanese }
            if normalized.hasPrefix("ko") { return .korean }
            if normalized.hasPrefix("es") { return .spanish }
            if normalized.hasPrefix("fr") { return .french }
            if normalized.hasPrefix("de") { return .german }
            if normalized.hasPrefix("pt") { return .portuguese }
            if normalized.hasPrefix("en") { return .english }
        }
        return .english
    }

    enum Key: CaseIterable {
        case appTitle
        case showTouchBarLyrics
        case quit
        case languageMenu
        case followSystem
        case spotifyNotRunning
        case notPlaying
        case syncingSpotify
        case loadingLyrics
        case noLyricsFound

        var defaultValue: String {
            switch self {
            case .appTitle: return "Spotify on Touchbar"
            case .showTouchBarLyrics: return "显示 Touch Bar 歌词"
            case .quit: return "退出"
            case .languageMenu: return "语言"
            case .followSystem: return "跟随系统"
            case .spotifyNotRunning: return "Spotify 未运行"
            case .notPlaying: return "未在播放"
            case .syncingSpotify: return "正在同步 Spotify…"
            case .loadingLyrics: return "加载歌词中..."
            case .noLyricsFound: return "未找到歌词"
            }
        }
    }

    private let english: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Show Touch Bar Lyrics",
        .quit: "Quit",
        .languageMenu: "Language",
        .followSystem: "Follow System",
        .spotifyNotRunning: "Spotify not running",
        .notPlaying: "Not playing",
        .syncingSpotify: "Syncing Spotify…",
        .loadingLyrics: "Loading lyrics...",
        .noLyricsFound: "No lyrics found"
    ]

    private let simplifiedChinese: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "显示 Touch Bar 歌词",
        .quit: "退出",
        .languageMenu: "语言",
        .followSystem: "跟随系统",
        .spotifyNotRunning: "Spotify 未运行",
        .notPlaying: "未在播放",
        .syncingSpotify: "正在同步 Spotify…",
        .loadingLyrics: "加载歌词中...",
        .noLyricsFound: "未找到歌词"
    ]

    private let traditionalChinese: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "顯示 Touch Bar 歌詞",
        .quit: "退出",
        .languageMenu: "語言",
        .followSystem: "跟隨系統",
        .spotifyNotRunning: "Spotify 未執行",
        .notPlaying: "未在播放",
        .syncingSpotify: "正在同步 Spotify…",
        .loadingLyrics: "載入歌詞中...",
        .noLyricsFound: "未找到歌詞"
    ]

    private let japanese: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Touch Bar 歌詞を表示",
        .quit: "終了",
        .languageMenu: "言語",
        .followSystem: "システムに従う",
        .spotifyNotRunning: "Spotify が起動していません",
        .notPlaying: "再生中ではありません",
        .syncingSpotify: "Spotify を同期中…",
        .loadingLyrics: "歌詞を読み込み中...",
        .noLyricsFound: "歌詞が見つかりません"
    ]

    private let korean: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Touch Bar 가사 표시",
        .quit: "종료",
        .languageMenu: "언어",
        .followSystem: "시스템 따르기",
        .spotifyNotRunning: "Spotify가 실행 중이 아닙니다",
        .notPlaying: "재생 중이 아닙니다",
        .syncingSpotify: "Spotify 동기화 중…",
        .loadingLyrics: "가사를 불러오는 중...",
        .noLyricsFound: "가사를 찾을 수 없습니다"
    ]

    private let spanish: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Mostrar letras en Touch Bar",
        .quit: "Salir",
        .languageMenu: "Idioma",
        .followSystem: "Seguir el sistema",
        .spotifyNotRunning: "Spotify no está ejecutándose",
        .notPlaying: "No está reproduciendo",
        .syncingSpotify: "Sincronizando Spotify…",
        .loadingLyrics: "Cargando letras...",
        .noLyricsFound: "No se encontraron letras"
    ]

    private let french: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Afficher les paroles sur la Touch Bar",
        .quit: "Quitter",
        .languageMenu: "Langue",
        .followSystem: "Suivre le système",
        .spotifyNotRunning: "Spotify n'est pas en cours d'exécution",
        .notPlaying: "Aucune lecture",
        .syncingSpotify: "Synchronisation de Spotify…",
        .loadingLyrics: "Chargement des paroles...",
        .noLyricsFound: "Aucune parole trouvée"
    ]

    private let german: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Touch-Bar-Texte anzeigen",
        .quit: "Beenden",
        .languageMenu: "Sprache",
        .followSystem: "Systemsprache verwenden",
        .spotifyNotRunning: "Spotify läuft nicht",
        .notPlaying: "Wird nicht abgespielt",
        .syncingSpotify: "Spotify wird synchronisiert…",
        .loadingLyrics: "Texte werden geladen...",
        .noLyricsFound: "Keine Texte gefunden"
    ]

    private let portuguese: [Key: String] = [
        .appTitle: "Spotify on Touchbar",
        .showTouchBarLyrics: "Mostrar letras na Touch Bar",
        .quit: "Sair",
        .languageMenu: "Idioma",
        .followSystem: "Seguir o sistema",
        .spotifyNotRunning: "Spotify não está em execução",
        .notPlaying: "Sem reprodução",
        .syncingSpotify: "Sincronizando o Spotify…",
        .loadingLyrics: "Carregando letras...",
        .noLyricsFound: "Nenhuma letra encontrada"
    ]
}
