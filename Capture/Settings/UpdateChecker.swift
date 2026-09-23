import Foundation
import Observation

/// Looks for a newer release of Capture on GitHub.
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case noRelease
        case available(version: String, download: URL)
        case failed
    }

    private(set) var state = State.idle

    static let releasesURL = URL(string: "https://api.github.com/repos/TheOnAirCompany/capture/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }

        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    func check() async {
        state = .checking
        do {
            var request = URLRequest(url: Self.releasesURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 404 {
                state = .noRelease
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let version = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard Self.isVersion(version, newerThan: Self.currentVersion) else {
                state = .upToDate
                return
            }
            // Prefer the disk image, otherwise the release page.
            let download = release.assets.first { $0.name.hasSuffix(".dmg") }?.browser_download_url ?? release.html_url
            state = .available(version: version, download: download)
        } catch {
            state = .failed
        }
    }

    static func isVersion(_ version: String, newerThan current: String) -> Bool {
        version.compare(current, options: .numeric) == .orderedDescending
    }
}
