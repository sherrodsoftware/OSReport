<h1>
  <img src="docs/images/os-report-icon-2026.10.27.png" alt="OS Report icon" width="48" />
  OS Report
</h1>

A small open-source macOS menu bar utility that shows the latest Apple
operating system releases at a glance. OS Report reads Apple's
[security releases page](https://support.apple.com/en-us/100100) and lists the
newest version of each platform right in the menu bar—no browsing required.

<p align="center">
  <img src="docs/images/os-report-menu-2026.10.27.png" alt="OS Report menu showing the latest Apple OS releases" width="520" />
</p>

## What it does

1. **Lives in the menu bar only.** No Dock icon and no main window—just a
   menu bar icon that's always a click away.
2. **Shows the latest release for each Apple operating system**: macOS, iOS,
   iPadOS, tvOS, watchOS, and visionOS, each with its own glyph.
3. **Puts the newest macOS at the top**, followed by the other platforms, with
   older macOS versions grouped below a divider from newest to oldest.
4. **Lists earlier releases in a submenu** for each platform, with release
   dates, and the newest version highlighted.
5. **Opens Apple's support article** for any release with a single click.
6. **Keeps iOS and iPadOS separate**, even when Apple lists them together.
7. **Refreshes on your schedule.** Choose on launch, every hour, every 6
   hours, every day, or manually only in Settings.
8. **Flags new releases.** When a refresh finds a newer version, a small dot
   appears on the menu bar icon and next to each new release in the menu until
   you've opened it.
9. **Sends one notification per batch** of new releases instead of one for
   every platform. Notifications can be turned off in Settings.
10. **Shows a subtle loading indicator** in the menu bar while it fetches, and
    the time of the last successful update in the menu.
11. **Keeps itself up to date** with built-in app updates powered by
    [Sparkle](https://sparkle-project.org).

## Requirements

- macOS 15 or later
- An internet connection to reach support.apple.com

## Security

Please see [SECURITY.md](SECURITY.md) for responsible vulnerability reporting.

## License

OS Report is available under the [MIT License](LICENSE.md).
