import Foundation
import Observation

/// Mirrors a KVO-observable Bool (Sparkle's automatic-check setting) so SwiftUI stays in sync when either side changes it.
@MainActor
@Observable
final class UpdaterSettings {
    var automaticallyChecksForUpdates: Bool {
        didSet {
            if automaticallyChecksForUpdates != read() { write(automaticallyChecksForUpdates) }
        }
    }

    @ObservationIgnored private let read: () -> Bool
    @ObservationIgnored private let write: (Bool) -> Void
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init<Source: NSObject>(_ source: Source, _ keyPath: ReferenceWritableKeyPath<Source, Bool>) {
        read = { source[keyPath: keyPath] }
        write = { source[keyPath: keyPath] = $0 }
        automaticallyChecksForUpdates = source[keyPath: keyPath]
        observation = source.observe(keyPath, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            let apply = { @MainActor [weak self] in
                guard let self, self.automaticallyChecksForUpdates != value else { return }
                self.automaticallyChecksForUpdates = value
            }
            if Thread.isMainThread {
                MainActor.assumeIsolated { apply() }
            } else {
                Task { @MainActor in apply() }
            }
        }
    }
}
