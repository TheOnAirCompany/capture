import Foundation

/// Options for testing, passed when launching the app:
///
///     open -n Capture.app --args --onboarding --language en
///
/// - `--onboarding`: shows the onboarding again.
/// - `--language <code>`: uses a language (`en`, `fr`) for this launch only.
enum LaunchArguments {
    private static let languageOverrideKey = "languageOverride"

    /// Applied before any text is loaded, from the app's initializer.
    static func apply(_ arguments: [String] = CommandLine.arguments) {
        let defaults = UserDefaults.standard

        if arguments.contains("--onboarding") {
            defaults.removeObject(forKey: "hasCompletedOnboarding")
        }

        if let index = arguments.firstIndex(of: "--language"), arguments.indices.contains(index + 1) {
            defaults.set([arguments[index + 1]], forKey: "AppleLanguages")
            defaults.set(true, forKey: languageOverrideKey)
        } else if defaults.bool(forKey: languageOverrideKey) {
            // The override was for one launch: back to the system language.
            defaults.removeObject(forKey: "AppleLanguages")
            defaults.removeObject(forKey: languageOverrideKey)
        }
    }
}
