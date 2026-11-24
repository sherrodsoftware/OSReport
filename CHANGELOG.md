# Changelog

## OS Report 2026.11.24

- OS Report now runs with Apple's Enhanced Security protections, including a hardened memory allocator and memory tagging on Macs that support it.
- Fixed false new-release alerts that could appear after Apple's page loaded partially.
- The "Automatically check for updates" setting now stays in sync when Sparkle changes it, such as after answering its automatic-update prompt.
- Added unit tests for release parsing, platform ordering, and new-release detection.

## OS Report 2026.10.27

- First release.
- Shows the latest release of macOS, iOS, iPadOS, tvOS, watchOS, and visionOS in the menu bar, with the newest macOS first and older macOS versions below a divider.
- Each platform has a submenu of earlier releases, and every release opens its Apple support article.
- New releases are marked with a dot on the menu bar icon and in the menu, and announced in a single notification.
- Refreshes on launch, every hour, every 6 hours, every day, or manually only.
- Updates itself with Sparkle.
