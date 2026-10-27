import Foundation
import UserNotifications

@MainActor
final class ReleaseTracker {
    static let notificationsKey = "notifyNewReleases"

    private let defaults = UserDefaults.standard
    private let seenKey = "seenLatestVersions"
    private let unseenKey = "unseenPlatforms"

    private(set) var unseen: Set<String>

    init() {
        unseen = Set(defaults.stringArray(forKey: unseenKey) ?? [])
    }

    /// Returns the platforms whose latest release is newer than last time. The first run only records a baseline.
    func recordNewReleases(in platforms: [Platform]) -> [Platform] {
        let seen = defaults.dictionary(forKey: seenKey) as? [String: String]
        defaults.set(Dictionary(uniqueKeysWithValues: platforms.map { ($0.name, $0.latest.version) }), forKey: seenKey)
        guard let seen else { return [] }

        let new = platforms.filter { platform in
            guard let old = seen[platform.name] else { return true }
            return platform.latest.version.compare(old, options: .numeric) == .orderedDescending
        }
        if !new.isEmpty {
            unseen.formUnion(new.map(\.name))
            defaults.set(Array(unseen), forKey: unseenKey)
        }
        return new
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
