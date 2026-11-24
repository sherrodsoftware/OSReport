import SwiftUI

enum RefreshInterval: String, CaseIterable, Identifiable {
    case onLaunch, hourly, sixHours, daily, manual

    static let defaultsKey = "refreshInterval"
    static let `default`: RefreshInterval = .sixHours

    static var current: RefreshInterval {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(RefreshInterval.init) ?? .default
    }

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .onLaunch: "On launch"
        case .hourly: "Every hour"
        case .sixHours: "Every 6 hours"
        case .daily: "Every day"
        case .manual: "Manually only"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .hourly: 60 * 60
        case .sixHours: 6 * 60 * 60
        case .daily: 24 * 60 * 60
        case .onLaunch, .manual: nil
        }
    }

    var fetchesOnLaunch: Bool { self != .manual }
}

struct SettingsView: View {
    let updaterSettings: UpdaterSettings
    let onIntervalChange: (RefreshInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2.bold())
            RefreshSettingsSection(onIntervalChange: onIntervalChange)
            NotificationSettingsSection()
            AppUpdateSettingsSection(updaterSettings: updaterSettings)
        }
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct RefreshSettingsSection: View {
    @AppStorage(RefreshInterval.defaultsKey) private var interval: RefreshInterval = .default
    let onIntervalChange: (RefreshInterval) -> Void

    var body: some View {
        SettingsGroup("Automatic Updates", description: "How often OS Report should check Apple's release notes.") {
            Picker("Automatic Updates", selection: $interval) {
                ForEach(RefreshInterval.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
        .onChange(of: interval) { _, newValue in onIntervalChange(newValue) }
    }
}

private struct NotificationSettingsSection: View {
    @AppStorage(ReleaseTracker.notificationsKey) private var notifyNewReleases = true

    var body: some View {
        SettingsGroup(
            "Notifications",
            description: "Show one notification summarizing new releases each time OS Report finds them."
        ) {
            Toggle("Notify me about new releases", isOn: $notifyNewReleases)
                .toggleStyle(.checkbox)
        }
    }
}

private struct AppUpdateSettingsSection: View {
    @Bindable var updaterSettings: UpdaterSettings

    var body: some View {
        SettingsGroup("App Updates", description: "Check for new versions of OS Report and offer to install them.") {
            Toggle("Automatically check for updates", isOn: $updaterSettings.automaticallyChecksForUpdates)
                .toggleStyle(.checkbox)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, description: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 10) {
                Text(description)
                    .foregroundStyle(.secondary)
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
