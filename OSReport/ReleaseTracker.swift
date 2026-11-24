import Foundation
import UserNotifications

@MainActor
final class ReleaseTracker {
    static let notificationsKey = "notifyNewReleases"

    private let defaults: UserDefaults
    private let seenKey = "seenLatestVersions"
    private let unseenKey = "unseenPlatforms"

    private(set) var unseen: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        unseen = Set(defaults.stringArray(forKey: unseenKey) ?? [])
    }

    /// Returns the platforms whose latest release is newer than last time. The first run only records a baseline.
    /// Saved versions are merged, never dropped or lowered, so a partial page can't make a known release look new later.
    func recordNewReleases(in platforms: [Platform]) -> [Platform] {
        let seen = defaults.dictionary(forKey: seenKey) as? [String: String]
        var merged = seen ?? [:]
        for platform in platforms where isNewer(platform.latest.version, than: merged[platform.name]) {
            merged[platform.name] = platform.latest.version
        }
        defaults.set(merged, forKey: seenKey)
        guard let seen else { return [] }

        let new = platforms.filter { isNewer($0.latest.version, than: seen[$0.name]) }
        if !new.isEmpty {
            unseen.formUnion(new.map(\.name))
            defaults.set(Array(unseen), forKey: unseenKey)
        }
        return new
    }

    private func isNewer(_ version: String, than old: String?) -> Bool {
        guard let old else { return true }
        return version.compare(old, options: .numeric) == .orderedDescending
    }

    func markAllSeen() {
        unseen.removeAll()
        defaults.removeObject(forKey: unseenKey)
    }

    static var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: notificationsKey) as? Bool ?? true
    }

    static func notify(about platforms: [Platform]) async {
        guard notificationsEnabled, !platforms.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let names = platforms.map(\.latest.name)
        let content = UNMutableNotificationContent()
        content.title = names.count == 1 ? "New Apple Release" : "New Apple Releases"
        content.body = names.count <= 3
            ? ListFormatter.localizedString(byJoining: names)
            : names.prefix(3).joined(separator: ", ") + " and \(names.count - 3) more"
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
