import Sparkle
import SwiftUI

enum RefreshInterval: String, CaseIterable, Identifiable {
    case onLaunch, hourly, sixHours, daily, manual

    static let defaultsKey = "refreshInterval"
    static let `default`: RefreshInterval = .sixHours

    static var current: RefreshInterval {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(RefreshInterval.init) ?? .default
    }

    var id: String { rawValue }

    var label: String {
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
    @AppStorage(RefreshInterval.defaultsKey) private var interval: RefreshInterval = .default
    @AppStorage(ReleaseTracker.notificationsKey) private var notifyNewReleases = true
    @State private var checksForAppUpdates: Bool
    private let updater: SPUUpdater
    var onIntervalChange: (RefreshInterval) -> Void

    init(updater: SPUUpdater, onIntervalChange: @escaping (RefreshInterval) -> Void) {
        self.updater = updater
        self.onIntervalChange = onIntervalChange
        _checksForAppUpdates = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Automatic Updates")
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("How often OS Report should check Apple's release notes.")
                        .foregroundStyle(.secondary)

                    Picker("Automatic Updates", selection: $interval) {
                        ForEach(RefreshInterval.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications")
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Show one notification summarizing new releases each time OS Report finds them.")
                        .foregroundStyle(.secondary)

                    Toggle("Notify me about new releases", isOn: $notifyNewReleases)
                        .toggleStyle(.checkbox)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("App Updates")
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Check for new versions of OS Report and offer to install them.")
                        .foregroundStyle(.secondary)

                    Toggle("Automatically check for updates", isOn: $checksForAppUpdates)
                        .toggleStyle(.checkbox)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: interval) { _, newValue in onIntervalChange(newValue) }
        .onChange(of: checksForAppUpdates) { _, newValue in updater.automaticallyChecksForUpdates = newValue }
    }
}
