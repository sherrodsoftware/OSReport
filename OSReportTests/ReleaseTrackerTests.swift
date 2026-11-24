import Foundation
import Testing
@testable import OSReport

private func platform(_ name: String, _ version: String) -> Platform {
    Platform(name: name, releases: [
        Release(name: "\(name) \(version)", version: version, url: ReleaseParser.pageURL, date: "1 Jan 2026"),
    ])
}

@MainActor
struct ReleaseTrackerTests {
    private let suiteName = "OSReportTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    private func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }

    @Test func firstRunRecordsBaselineWithoutFlagging() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        #expect(tracker.recordNewReleases(in: [platform("iOS", "27.2")]).isEmpty)
        #expect(tracker.unseen.isEmpty)
    }

    @Test func flagsOnlyNewerVersions() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        _ = tracker.recordNewReleases(in: [platform("iOS", "27.1"), platform("tvOS", "27.2")])

        let new = tracker.recordNewReleases(in: [platform("iOS", "27.2"), platform("tvOS", "27.2")])
        #expect(new.map(\.name) == ["iOS"])
        #expect(tracker.unseen == ["iOS"])
    }

    @Test func comparesVersionsNumerically() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        _ = tracker.recordNewReleases(in: [platform("macOS Tahoe", "26.9")])
        #expect(tracker.recordNewReleases(in: [platform("macOS Tahoe", "26.10")]).map(\.name) == ["macOS Tahoe"])
    }

    @Test func flagsPlatformsThatAppearForTheFirstTime() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        _ = tracker.recordNewReleases(in: [platform("macOS Tahoe", "26.7.2")])
        let new = tracker.recordNewReleases(in: [platform("macOS Tahoe", "26.7.2"), platform("macOS Next", "28")])
        #expect(new.map(\.name) == ["macOS Next"])
    }

    @Test func unseenSurvivesRelaunchUntilMarkedSeen() {
        defer { cleanUp() }
        let first = ReleaseTracker(defaults: defaults)
        _ = first.recordNewReleases(in: [platform("iOS", "27.1")])
        _ = first.recordNewReleases(in: [platform("iOS", "27.2")])

        let relaunched = ReleaseTracker(defaults: defaults)
        #expect(relaunched.unseen == ["iOS"])
        relaunched.markAllSeen()
        #expect(ReleaseTracker(defaults: defaults).unseen.isEmpty)
    }

    @Test func platformMissingFromOneRefreshIsNotFlaggedWhenItReturns() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        _ = tracker.recordNewReleases(in: [platform("iOS", "27.2"), platform("tvOS", "27.2")])
        _ = tracker.recordNewReleases(in: [platform("iOS", "27.2")])

        #expect(tracker.recordNewReleases(in: [platform("iOS", "27.2"), platform("tvOS", "27.2")]).isEmpty)
        #expect(tracker.unseen.isEmpty)
    }

    @Test func olderVersionOnOneRefreshDoesNotLowerTheSavedVersion() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        _ = tracker.recordNewReleases(in: [platform("iOS", "27.2")])
        #expect(tracker.recordNewReleases(in: [platform("iOS", "27.1")]).isEmpty)
        #expect(tracker.recordNewReleases(in: [platform("iOS", "27.2")]).isEmpty)
    }

    @Test func platformMissingFromOneRefreshStillFlagsANewerReleaseWhenItReturns() {
        defer { cleanUp() }
        let tracker = ReleaseTracker(defaults: defaults)
        _ = tracker.recordNewReleases(in: [platform("iOS", "27.2"), platform("tvOS", "27.2")])
        _ = tracker.recordNewReleases(in: [platform("iOS", "27.2")])
        #expect(tracker.recordNewReleases(in: [platform("iOS", "27.2"), platform("tvOS", "27.3")]).map(\.name) == ["tvOS"])
    }
}

struct RefreshIntervalTests {
    @Test func onlyTimedIntervalsSchedule() {
        #expect(RefreshInterval.hourly.seconds == 3600)
        #expect(RefreshInterval.sixHours.seconds == 21600)
        #expect(RefreshInterval.daily.seconds == 86400)
        #expect(RefreshInterval.onLaunch.seconds == nil)
        #expect(RefreshInterval.manual.seconds == nil)
    }

    @Test func everyOptionButManualFetchesOnLaunch() {
        #expect(RefreshInterval.allCases.filter { !$0.fetchesOnLaunch } == [.manual])
    }
}
