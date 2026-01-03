import Foundation

/// Represents a downloaded ML model for a specific language
struct LanguageModel: Codable, Identifiable, Sendable {
    let id: UUID
    let languageCode: String
    let displayName: String
    var modelPath: URL
    var downloadStatus: DownloadStatus
    let fileSize: Int64
    var downloadedAt: Date?
    var lastUsed: Date?
    let version: String
    let checksumSHA256: String

    // Computed properties for view compatibility
    var code: String { languageCode }
    var name: String { displayName }
    var flag: String {
        SupportedLanguage.from(code: languageCode)?.flag ?? "🌐"
    }

    /// Native name of the language (e.g., "Deutsch" for German)
    var nativeName: String {
        SupportedLanguage.from(code: languageCode)?.nativeName ?? displayName
    }

    /// Static property for all supported languages
    static var supportedLanguages: [LanguageModel] {
        SupportedLanguage.allCases.map { lang in
            LanguageModel(
                languageCode: lang.rawValue,
                displayName: lang.displayName,
                modelPath: URL(fileURLWithPath: "/tmp/\(lang.rawValue).model"),
                fileSize: 500_000_000 // 500MB default
            )
        }
    }

    init(id: UUID = UUID(),
         languageCode: String,
         displayName: String,
         modelPath: URL,
         downloadStatus: DownloadStatus = .notDownloaded,
         fileSize: Int64,
         downloadedAt: Date? = nil,
         lastUsed: Date? = nil,
         version: String = "0.6b-v3",
         checksumSHA256: String = "") {
        self.id = id
        self.languageCode = languageCode
        self.displayName = displayName
        self.modelPath = modelPath
        self.downloadStatus = downloadStatus
        self.fileSize = fileSize
        self.downloadedAt = downloadedAt
        self.lastUsed = lastUsed
        self.version = version
        self.checksumSHA256 = checksumSHA256
    }
}

/// Download status for language models
enum DownloadStatus: Codable, Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double, bytesDownloaded: Int64)
    case downloaded
    case error(message: String)

    var isDownloaded: Bool {
        if case .downloaded = self {
            return true
        }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }

    var displayText: String {
        switch self {
        case .notDownloaded:
            return "Not downloaded"
        case .downloading(let progress, _):
            return "Downloading \(Int(progress * 100))%"
        case .downloaded:
            return "Downloaded"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

/// Supported languages for FluidAudio Parakeet TDT v3
enum SupportedLanguage: String, CaseIterable, Codable, Sendable {
    case en, es, fr, de, it, pt, ru, pl, nl, sv
    case da, no, fi, cs, ro, uk, el, bg, hr, sk
    case sl, et, lv, lt, mt

    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .pl: return "Polski"
        case .nl: return "Nederlands"
        case .sv: return "Svenska"
        case .da: return "Dansk"
        case .no: return "Norsk"
        case .fi: return "Suomi"
        case .cs: return "Čeština"
        case .ro: return "Română"
        case .uk: return "Українська"
        case .el: return "Ελληνικά"
        case .bg: return "Български"
        case .hr: return "Hrvatski"
        case .sk: return "Slovenčina"
        case .sl: return "Slovenščina"
        case .et: return "Eesti"
        case .lv: return "Latviešu"
        case .lt: return "Lietuvių"
        case .mt: return "Malti"
        }
    }

    var nativeName: String {
        displayName
    }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .de: return "🇩🇪"
        case .it: return "🇮🇹"
        case .pt: return "🇵🇹"
        case .ru: return "🇷🇺"
        case .pl: return "🇵🇱"
        case .nl: return "🇳🇱"
        case .sv: return "🇸🇪"
        case .da: return "🇩🇰"
        case .no: return "🇳🇴"
        case .fi: return "🇫🇮"
        case .cs: return "🇨🇿"
        case .ro: return "🇷🇴"
        case .uk: return "🇺🇦"
        case .el: return "🇬🇷"
        case .bg: return "🇧🇬"
        case .hr: return "🇭🇷"
        case .sk: return "🇸🇰"
        case .sl: return "🇸🇮"
        case .et: return "🇪🇪"
        case .lv: return "🇱🇻"
        case .lt: return "🇱🇹"
        case .mt: return "🇲🇹"
        }
    }

    static func isSupported(_ code: String) -> Bool {
        SupportedLanguage.allCases.contains { $0.rawValue == code }
    }

    static func from(code: String) -> SupportedLanguage? {
        SupportedLanguage.allCases.first { $0.rawValue == code }
    }
}
