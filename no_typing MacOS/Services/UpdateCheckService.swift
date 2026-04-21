import Foundation
import AppKit

/// Checks the GitHub Releases API for the latest published release and compares
/// its tag against the running app's `CFBundleShortVersionString`.
///
/// Usage:
///   Call `UpdateCheckService.shared.checkForUpdates()` once on launch.
///   Observe `UpdateCheckService.shared.updateAvailable` (published on main thread).
@MainActor
final class UpdateCheckService: ObservableObject {

    static let shared = UpdateCheckService()

    // MARK: - Published State

    /// `true` once a newer release tag has been confirmed on GitHub.
    @Published private(set) var updateAvailable = false

    /// The latest tag string returned by GitHub, e.g. `"1.2.0"` or `"v1.2.0"`.
    @Published private(set) var latestVersion: String? = nil

    // MARK: - Constants

    /// GitHub REST endpoint for the latest non-pre-release, non-draft release.
    private let latestReleaseURL = URL(
        string: "https://api.github.com/repos/no-typing/no-typing-mac/releases/latest"
    )!

    /// Download page that the "Update Available" badge links to.
    static let downloadPageURL = URL(string: "https://no-typing.com/download")!

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Fires an async network request; safe to call multiple times (de-duped by rate limiter below).
    func checkForUpdates() {
        Task { await fetchLatestRelease() }
    }

    // MARK: - Private

    private func fetchLatestRelease() async {
        guard let currentVersion = Bundle.main.shortVersionString else { return }

        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28",                  forHTTPHeaderField: "X-GitHub-Api-Version")
        // A descriptive User-Agent is required by GitHub's API policy.
        request.setValue("NoTyping-macOS-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Honour HTTP errors gracefully (rate-limit, auth, …)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return
            }

            guard
                let json        = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tagName     = json["tag_name"] as? String
            else { return }

            let remoteVersion = normalise(tagName)
            let localVersion  = normalise(currentVersion)

            let isNewer = compareVersions(remoteVersion, isNewerThan: localVersion)

            // Always update on the main actor (class is @MainActor so self is safe)
            self.latestVersion  = tagName
            self.updateAvailable = isNewer

        } catch {
            // Network failures are silent – the badge simply won't appear.
        }
    }

    // MARK: - Version helpers

    /// Strips a leading "v" so `"v1.2.3"` and `"1.2.3"` compare equally.
    private func normalise(_ version: String) -> String {
        version.hasPrefix("v") ? String(version.dropFirst()) : version
    }

    /// Returns `true` when `remote` is strictly newer than `local` using
    /// semantic-version component comparison (major · minor · patch).
    private func compareVersions(_ remote: String, isNewerThan local: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let localComponents  = local .split(separator: ".").compactMap { Int($0) }

        let count = max(remoteComponents.count, localComponents.count)
        for i in 0 ..< count {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let l = i < localComponents.count  ? localComponents[i]  : 0
            if r > l { return true  }
            if r < l { return false }
        }
        return false  // identical
    }
}

// MARK: - Bundle helper

private extension Bundle {
    /// `CFBundleShortVersionString` from the main bundle, e.g. `"1.2.3"`.
    var shortVersionString: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
