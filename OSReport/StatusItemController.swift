import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var platforms: [Platform] = []
    private var lastUpdated: Date?
    private var lastError: String?
    private var isLoading = false
    private var timer: Timer?
    private var settingsWindow: NSWindow?

    private static let maxReleasesPerPlatform = 20

    override init() {
        super.init()
        statusItem.menu = menu
        updateIcon()
        rebuildMenu()
        let interval = RefreshInterval.current
        if interval.fetchesOnLaunch { refresh() }
        schedule(interval)
    }

    private func schedule(_ interval: RefreshInterval) {
        timer?.invalidate()
        timer = nil
        guard let seconds = interval.seconds else { return }
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView { [weak self] in self?.schedule($0) }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "OS Report Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func refresh() {
        guard !isLoading else { return }
        isLoading = true
        updateIcon()
        rebuildMenu()

        Task {
            do {
                var request = URLRequest(url: ReleaseParser.pageURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, _) = try await URLSession.shared.data(for: request)
                let html = String(decoding: data, as: UTF8.self)
                let parsed = await Task.detached { ReleaseParser.parse(html) }.value
                if parsed.isEmpty {
                    lastError = "No releases found on page"
                } else {
                    platforms = parsed
                    lastUpdated = Date()
                    lastError = nil
                }
            } catch {
                lastError = error.localizedDescription
            }
            isLoading = false
            updateIcon()
            rebuildMenu()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        if button.image == nil && button.title.isEmpty {
            let image = NSImage(systemSymbolName: "desktopcomputer.logo", accessibilityDescription: "OS Report")
                ?? NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "OS Report")
            if let image {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "OS"
            }
        }
        button.wantsLayer = true
        button.layer?.removeAnimation(forKey: "pulse")
        if isLoading {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.3
            pulse.duration = 0.7
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            button.layer?.add(pulse, forKey: "pulse")
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if platforms.isEmpty {
            let text = isLoading ? "Loading…" : (lastError.map { "Error: \($0)" } ?? "Click Refresh to load releases")
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        for (index, platform) in platforms.enumerated() {
            if index > 1, platform.kind == .macOS, platforms[index - 1].kind != .macOS {
                menu.addItem(.separator())
            }
            let top = NSMenuItem(title: platform.latest.name, action: #selector(openRelease(_:)), keyEquivalent: "")
            top.target = self
            top.representedObject = platform.latest.url
            let font = NSFont.menuFont(ofSize: 0)
            let title = NSMutableAttributedString()
            if let symbol = platform.kind?.symbolName,
               let image = Self.fixedWidthGlyph(symbol, font: font) {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2,
                                           width: image.size.width, height: image.size.height)
                title.append(NSAttributedString(attachment: attachment))
                title.append(NSAttributedString(string: " "))
            }
            title.append(NSAttributedString(string: platform.latest.name))
            title.addAttribute(.font, value: font, range: NSRange(location: 0, length: title.length))
            top.attributedTitle = title
            top.toolTip = platform.latest.date

            let submenu = NSMenu()
            for (index, release) in platform.releases.prefix(Self.maxReleasesPerPlatform).enumerated() {
                let item = NSMenuItem(title: "\(release.version)  —  \(release.date)",
                                      action: #selector(openRelease(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = release.url
                item.toolTip = release.name
                if index == 0 {
                    item.attributedTitle = NSAttributedString(
                        string: item.title,
                        attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
                    )
                }
                submenu.addItem(item)
            }
            top.submenu = submenu
            menu.addItem(top)
        }

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: isLoading ? "Refreshing…" : "Refresh",
                                     action: isLoading ? nil : #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let status: String
        if let lastUpdated {
            let f = DateFormatter()
            f.dateFormat = "MMM d 'at' h:mm a"
            status = "Last updated: \(f.string(from: lastUpdated))" + (lastError != nil ? " (last refresh failed)" : "")
        } else {
            status = "Last updated: never"
        }
        let statusItemEntry = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItemEntry.isEnabled = false
        menu.addItem(statusItemEntry)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private static func fixedWidthGlyph(_ name: String, font: NSFont) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        let box = NSSize(width: font.pointSize * 1.8, height: font.pointSize * 1.3)
        let scale = min(1, box.width / symbol.size.width, box.height / symbol.size.height)
        let drawn = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        let image = NSImage(size: box, flipped: false) { _ in
            symbol.draw(in: NSRect(x: (box.width - drawn.width) / 2, y: (box.height - drawn.height) / 2,
                                   width: drawn.width, height: drawn.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func openRelease(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }
}
