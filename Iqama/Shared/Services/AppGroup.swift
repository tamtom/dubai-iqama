import Foundation

/// Shared storage for the cached Aladhan month data and resolved-location settings.
///
/// Ideally backed by an App Group container so the sandboxed widget can read what the main app
/// writes. The App Group capability requires provisioning (a registered Mac), so it's an opt-in:
/// when it isn't enabled, `containerURL` is nil and we fall back to the main app's local
/// Application Support. That keeps the main window + status bar working for non-UAE locations;
/// only the *widget* needs the App Group to show non-UAE live data (UAE is bundled, never shared).
enum AppGroup {
    static let identifier = "group.com.tamimi.shared.Dubai-iqama"

    /// The App Group container, or nil when the capability isn't provisioned.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Local fallback (main app, non-sandboxed): ~/Library/Application Support/Iqama.
    private static var localApplicationSupport: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Iqama", isDirectory: true)
    }

    /// Directory holding cached Aladhan month JSON. Prefers the App Group container (shared with
    /// the widget) and falls back to local Application Support so the main app always has a cache.
    static var cachesDirectory: URL? {
        guard let base = containerURL ?? localApplicationSupport else { return nil }
        let dir = base.appendingPathComponent("AladhanCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Shared defaults for location/iqama/calc keys when the App Group exists; otherwise nil so
    /// callers fall back to `.standard` (main app stays self-consistent; widget uses defaults).
    static var defaults: UserDefaults? {
        guard containerURL != nil else { return nil }
        return UserDefaults(suiteName: identifier)
    }
}
