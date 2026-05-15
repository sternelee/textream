import Foundation
import SwiftUI

enum IOSReaderFontFamily: String, CaseIterable, Codable, Identifiable {
    case system
    case rounded
    case serif
    case monospaced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Monospaced"
        }
    }

    var fontDesign: Font.Design? {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}

enum IOSHighlightColorPreset: String, CaseIterable, Codable, Identifiable {
    case amber
    case mint
    case sky
    case rose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .amber: return "Amber"
        case .mint: return "Mint"
        case .sky: return "Sky"
        case .rose: return "Rose"
        }
    }

    var tint: Color {
        switch self {
        case .amber: return Color(red: 1.0, green: 0.79, blue: 0.24)
        case .mint: return Color(red: 0.38, green: 0.93, blue: 0.78)
        case .sky: return Color(red: 0.43, green: 0.77, blue: 1.0)
        case .rose: return Color(red: 1.0, green: 0.55, blue: 0.72)
        }
    }

    var softBackground: Color {
        tint.opacity(0.18)
    }
}

enum IOSSpeechLocaleOption: String, CaseIterable, Codable, Identifiable {
    case system
    case englishUS = "en-US"
    case englishUK = "en-GB"
    case chineseSimplified = "zh-CN"
    case chineseTraditional = "zh-TW"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Follow Device"
        case .englishUS: return "English (US)"
        case .englishUK: return "English (UK)"
        case .chineseSimplified: return "中文（简体）"
        case .chineseTraditional: return "中文（繁體）"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.autoupdatingCurrent.identifier
        case .englishUS, .englishUK, .chineseSimplified, .chineseTraditional:
            return rawValue
        }
    }
}

enum PhoneticSource: String, CaseIterable, Codable, Identifiable {
    case localDictionary
    case aiGenerated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .localDictionary: return "Local Dictionary"
        case .aiGenerated: return "AI Generated"
        }
    }

    var icon: String {
        switch self {
        case .localDictionary: return "book.fill"
        case .aiGenerated: return "sparkles"
        }
    }
}

enum IOSTeleprompterSample: String, CaseIterable, Identifiable {
    case shortEnglish
    case chinese
    case multiPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortEnglish: return "Short English"
        case .chinese: return "中文样稿"
        case .multiPage: return "Multi-page"
        }
    }

    var caption: String {
        switch self {
        case .shortEnglish:
            return "Quickly test Classic, Voice-Activated, and Word Tracking."
        case .chinese:
            return "Validate CJK segmentation and speech-driven progression."
        case .multiPage:
            return "Check page switching and state reset behavior."
        }
    }

    var preview: String {
        let firstPage = document.pages.first ?? ""
        let trimmed = firstPage.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(60))
        return prefix + (trimmed.count > 60 ? "…" : "")
    }

    var document: ScriptDocument {
        switch self {
        case .shortEnglish:
            return ScriptDocument(
                title: "Short English Test",
                pages: [
                    "Welcome to Textream on iPhone. This is a short script for testing classic mode, voice-activated mode, and word tracking."
                ]
            )
        case .chinese:
            return ScriptDocument(
                title: "中文测试稿",
                pages: [
                    "欢迎使用 Textream 的 iOS 版本。这个测试文稿用于验证中文分词、自动滚动、语音驱动滚动，以及逐词跟读能力。请保持正常语速朗读，观察高亮、进度和翻页行为是否符合预期。"
                ]
            )
        case .multiPage:
            return ScriptDocument(
                title: "Multi-page Test",
                pages: [
                    "This is page one. Read to the end and then switch to the next page.",
                    "This is page two. Verify page switching and state reset behavior."
                ]
            )
        }
    }
}

struct IOSPersistedReaderSettings: Codable, Equatable {
    var selectedMode: TeleprompterMode = .classic
    var fontSize: Double = 34
    var fontFamily: IOSReaderFontFamily = .rounded
    var highlightColor: IOSHighlightColorPreset = .amber
    var scrollSpeedWordsPerSecond: Double = 2.0
    var speechLocale: IOSSpeechLocaleOption = .system
    var lineSpacing: Double = 1.2
    var keepScreenAwake: Bool = true
    var hapticEnabled: Bool = true
    var mirrorModeEnabled: Bool = false
    var forceDarkMode: Bool = true
    var phoneticTooltipEnabled: Bool = true
    var nativeLanguage: String = "zh"
    var phoneticSource: PhoneticSource = .aiGenerated
}

struct IOSDraftState: Codable, Equatable {
    var document: ScriptDocument
    var pageTitle: String
    var currentDocumentURL: URL?
}
