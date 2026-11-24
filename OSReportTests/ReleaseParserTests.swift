import Foundation
import Testing
@testable import OSReport

private func row(_ name: String, href: String? = nil, date: String = "1 Jan 2026") -> String {
    let nameCell = href.map { #"<p class="gb-paragraph"><a href="\#($0)" class="gb-anchor">\#(name)</a></p>"# }
        ?? #"<p class="gb-paragraph">\#(name)</p><div class="note"><p>No published CVE entries.</p></div>"#
    return """
    <tr><td class="gb-table-cell">\(nameCell)</td>\
    <td class="gb-table-cell"><p>Devices</p></td>\
    <td class="gb-table-cell"><p class="gb-paragraph">\(date)</p></td></tr>
    """
}

private func page(_ rows: String...) -> String {
    "<table><tr><th>Name</th><th>Available for</th><th>Release date</th></tr>\(rows.joined())</table>"
}

private func names(_ platforms: [Platform]) -> [String] { platforms.map(\.name) }

struct ReleaseParserTests {
    @Test func splitsCombinedRowsIntoSeparatePlatforms() {
        let platforms = ReleaseParser.parse(page(row("iOS 27.2 and iPadOS 27.2", href: "https://support.apple.com/en-us/1")))
        #expect(names(platforms) == ["iOS", "iPadOS"])
        #expect(platforms.map(\.latest.version) == ["27.2", "27.2"])
        #expect(platforms.allSatisfy { $0.latest.url.absoluteString == "https://support.apple.com/en-us/1" })
    }

    @Test func dropsNonOperatingSystemReleases() {
        let platforms = ReleaseParser.parse(page(
            row("Safari 27.2", href: "https://support.apple.com/en-us/2"),
            row("Xcode 27", href: "https://support.apple.com/en-us/3"),
            row("Security Update 2026-001 Catalina"),
            row("tvOS 27.2", href: "https://support.apple.com/en-us/4")
        ))
        #expect(names(platforms) == ["tvOS"])
    }

    @Test func rowsWithoutAnArticleLinkToTheReleasesPage() throws {
        let platform = try #require(ReleaseParser.parse(page(row("watchOS 27.0.1"))).first)
        #expect(platform.latest.url == ReleaseParser.pageURL)
        #expect(platform.latest.name == "watchOS 27.0.1")
    }

    @Test func decodesEntitiesAndNonBreakingSpaces() throws {
        let platform = try #require(ReleaseParser.parse(page(row("visionOS&nbsp;27.2", date: "26&nbsp;Oct&nbsp;2026"))).first)
        #expect(platform.name == "visionOS")
        #expect(platform.latest.date == "26 Oct 2026")
    }

    @Test func sortsReleasesNewestFirstByNumericVersion() throws {
        let platform = try #require(ReleaseParser.parse(page(
            row("iOS 18.7.9"), row("iOS 27.0.1"), row("iOS 27.2"), row("iOS 27"), row("iOS 26.10")
        )).first)
        #expect(platform.releases.map(\.version) == ["27.2", "27.0.1", "27", "26.10", "18.7.9"])
    }

    @Test func keepsEachMacOSNameSeparate() {
        let platforms = ReleaseParser.parse(page(row("macOS Tahoe 26.7.2"), row("macOS Sequoia 15.8.2"), row("macOS Tahoe 26.7.1")))
        #expect(Set(names(platforms)) == ["macOS Tahoe", "macOS Sequoia"])
        #expect(platforms.first { $0.name == "macOS Tahoe" }?.releases.count == 2)
    }

    @Test func ordersNewestMacFirstThenPlatformsThenOlderMacs() {
        let platforms = ReleaseParser.parse(page(
            row("tvOS 27.2"),
            row("macOS Sonoma 14.8.9"),
            row("watchOS 27.2"),
            row("macOS Tahoe 26.7.2"),
            row("iPadOS 27.2"),
            row("macOS Golden Gate 27.2"),
            row("visionOS 27.2"),
            row("macOS Big Sur 11.7.11"),
            row("iOS 27.2"),
            row("macOS Sequoia 15.8.2")
        ))
        #expect(names(platforms) == [
            "macOS Golden Gate", "iOS", "iPadOS", "tvOS", "watchOS", "visionOS",
            "macOS Tahoe", "macOS Sequoia", "macOS Sonoma", "macOS Big Sur",
        ])
    }

    @Test func findsEachRowsContents() {
        let html = "<table><tr><td>a</td></tr>\n<tr><td>b\nc</td></tr><tr></tr></table>"
        #expect(ReleaseParser.rows(in: html[...]) == ["<td>a</td>", "<td>b\nc</td>", ""])
    }

    @Test func ignoresAnUnclosedFinalRow() {
        #expect(ReleaseParser.rows(in: "<tr><td>a</td></tr><tr><td>cut off"[...]) == ["<td>a</td>"])
    }

    @Test func ignoresPagesWithoutReleaseRows() {
        #expect(ReleaseParser.parse("<html><body>Maintenance</body></html>").isEmpty)
    }

    @Test(arguments: [
        ("macOS Tahoe", OSKind.macOS), ("iOS", .iOS), ("iPadOS", .iPadOS),
        ("watchOS", .watchOS), ("tvOS", .tvOS), ("visionOS", .visionOS),
    ])
    func mapsPlatformNamesToKinds(name: String, kind: OSKind) {
        #expect(Platform(name: name, releases: []).kind == kind)
    }
}
