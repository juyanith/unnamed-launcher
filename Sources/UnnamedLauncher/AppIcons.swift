import AppKit

/// App icons for the Guide's Use Application rows (S-054). Filled when the
/// config loads, so showing the Guide only reads what is already here.
@MainActor
final class AppIcons {
    static let shared = AppIcons()

    /// Installed apps only.
    private var icons: [String: NSImage] = [:]
    /// How many times an app was looked up, for the self-test.
    private(set) var lookups = 0

    /// The icon for an app, if it's installed and already looked up.
    func icon(for bundleId: String) -> NSImage? {
        icons[bundleId]
    }

    /// Looks up the apps not seen yet. A missing app is tried again on the
    /// next load, in case it was installed since.
    func load(_ bundleIds: Set<String>) {
        for id in bundleIds where icons[id] == nil {
            lookups += 1
            icons[id] = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
    }
}
