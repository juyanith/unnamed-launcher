import AppKit
import UnnamedLauncherKit

/// Carries out an ActionPlan. The seam between the launcher and the world:
/// SystemPerformer does it for real, RecordingPerformer (self-test) only
/// writes it down.
protocol ActionPerformer {
    func perform(_ plan: ActionPlan) async throws(PlanError)
}

/// Runs a binding's action (S-006, S-010 to S-014).
struct ActionRunner {
    var performer: any ActionPerformer = SystemPerformer()
    var home: URL = .homeDirectory

    func run(_ action: Config.Action, id: String) async throws(PlanError) {
        let plan = try ActionPlanner.plan(action, home: home)
        try await performer.perform(plan)
    }
}

/// Does each plan with NSWorkspace.
struct SystemPerformer: ActionPerformer {
    func perform(_ plan: ActionPlan) async throws(PlanError) {
        switch plan {
        case let .openApp(bundleId):
            try await openApp(bundleId)
        case let .open(url):
            try await open(url)
        case .nothing:
            return
        case .spawn, .send:
            throw PlanError("This kind of action isn't available yet.")
        }
    }

    /// Brings the app forward if it's running, otherwise launches it. Going
    /// through NSWorkspace activates it even though this app isn't active.
    private func openApp(_ bundleId: String) async throws(PlanError) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw PlanError("Couldn't open \(bundleId): not installed.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            throw PlanError("Couldn't open \(bundleId): \(error.localizedDescription)")
        }
    }

    /// Opens a file, folder or URL in its default app (S-010).
    private func open(_ url: URL) async throws(PlanError) {
        let name = url.isFileURL ? url.path(percentEncoded: false) : url.absoluteString
        if url.isFileURL, !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            throw PlanError("Couldn't open \(name): it doesn't exist.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.open(url, configuration: configuration)
        } catch {
            throw PlanError("Couldn't open \(name): \(error.localizedDescription)")
        }
    }
}

/// Writes plans down instead of doing them, for the self-test.
final class RecordingPerformer: ActionPerformer {
    private(set) var plans: [ActionPlan] = []

    func perform(_ plan: ActionPlan) async throws(PlanError) {
        plans.append(plan)
    }
}
