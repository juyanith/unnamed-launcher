import AppKit
import UnnamedLauncherKit

/// Runs a binding's action (S-006). Open App works in M1; the other types
/// arrive in M2 (S-010 to S-014) and report that until then.
enum ActionRunner {
    /// A failure, written for the Guide and the log (S-015).
    struct Failure: Error, Equatable {
        let message: String
    }

    static func run(_ action: Config.Action, id: String) async throws(Failure) {
        switch action {
        case let .application(bundleId):
            try await openApp(bundleId)
        case .noop:
            return
        default:
            throw Failure(message: "\(action.displayName) actions aren't available yet, so “\(id)” did nothing.")
        }
    }

    /// Brings the app forward if it's running, otherwise launches it. Going
    /// through NSWorkspace activates it even though this app isn't active.
    private static func openApp(_ bundleId: String) async throws(Failure) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw Failure(message: "Couldn't open \(bundleId): not installed.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            throw Failure(message: "Couldn't open \(bundleId): \(error.localizedDescription)")
        }
    }
}
