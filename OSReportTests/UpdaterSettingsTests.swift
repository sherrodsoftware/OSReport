import Foundation
import Testing
@testable import OSReport

private final class FakeUpdater: NSObject {
    @objc dynamic var automaticallyChecksForUpdates = false
    private(set) var writes = 0

    override func didChangeValue(forKey key: String) {
        if key == #keyPath(automaticallyChecksForUpdates) { writes += 1 }
        super.didChangeValue(forKey: key)
    }
}

@MainActor
struct UpdaterSettingsTests {
    @Test func startsWithTheUpdaterValue() {
        let updater = FakeUpdater()
        updater.automaticallyChecksForUpdates = true
        #expect(UpdaterSettings(updater, \.automaticallyChecksForUpdates).automaticallyChecksForUpdates)
    }

    @Test func checkboxChangesReachTheUpdater() {
        let updater = FakeUpdater()
        let settings = UpdaterSettings(updater, \.automaticallyChecksForUpdates)
        settings.automaticallyChecksForUpdates = true
        #expect(updater.automaticallyChecksForUpdates)
        #expect(updater.writes == 1)
    }

    @Test func updaterChangesReachTheCheckbox() {
        let updater = FakeUpdater()
        let settings = UpdaterSettings(updater, \.automaticallyChecksForUpdates)
        updater.automaticallyChecksForUpdates = true
        #expect(settings.automaticallyChecksForUpdates)
    }

    @Test func updaterChangesAreNotWrittenBack() {
        let updater = FakeUpdater()
        let settings = UpdaterSettings(updater, \.automaticallyChecksForUpdates)
        updater.automaticallyChecksForUpdates = true
        updater.automaticallyChecksForUpdates = false
        #expect(!settings.automaticallyChecksForUpdates)
        #expect(updater.writes == 2)
    }

    @Test func updaterChangesNotifyObservers() {
        let updater = FakeUpdater()
        let settings = UpdaterSettings(updater, \.automaticallyChecksForUpdates)
        nonisolated(unsafe) var notified = false
        withObservationTracking {
            _ = settings.automaticallyChecksForUpdates
        } onChange: {
            notified = true
        }
        updater.automaticallyChecksForUpdates = true
        #expect(notified)
    }
}
