import Foundation

/// A language the app ships translations for. English is the development language and the fallback.
package struct AppLanguage: Hashable, Sendable {
    package let code: String
    /// The language's name in itself, so people can find their own language in the list.
    package let nativeName: String

    package static let supported: [AppLanguage] = [
        AppLanguage(code: "en", nativeName: "English"),
        AppLanguage(code: "zh-Hans", nativeName: "简体中文"),
        AppLanguage(code: "zh-Hant", nativeName: "繁體中文"),
        AppLanguage(code: "ja", nativeName: "日本語"),
        AppLanguage(code: "ko", nativeName: "한국어"),
        AppLanguage(code: "de", nativeName: "Deutsch"),
        AppLanguage(code: "fr", nativeName: "Français"),
        AppLanguage(code: "es", nativeName: "Español"),
        AppLanguage(code: "pt-BR", nativeName: "Português (Brasil)"),
        AppLanguage(code: "ru", nativeName: "Русский"),
    ]
}
