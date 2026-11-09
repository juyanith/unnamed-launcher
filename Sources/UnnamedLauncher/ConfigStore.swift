import AppKit
import OSLog
import UnnamedLauncherKit

let log = Logger(subsystem: "net.unnamed.launcher", category: "launcher")

/// The config file, loaded and checked (S-001, S-008). A reload with errors
/// keeps the last valid config running.
@Observable
final class ConfigStore {
    let url: URL
    /// The config in use, or nil when no valid config has loaded yet.
    private(set) var loaded: LoadedConfig?
    /// Errors from the last load. Empty when it succeeded.
    private(set) var errors: [ConfigIssue] = []
    /// When the config in use was loaded.
    private(set) var loadedAt: Date?
    /// True after this launch wrote the starter config ("Created config file").
    private(set) var createdStarter = false

    /// Called after every successful load, so the engine can swap configs.
    var onLoad: ((LoadedConfig) -> Void)?

    init(url: URL) {
        self.url = url
    }

    /// Writes the starter config if there is no file, then loads.
    func start() {
        do {
            createdStarter = try ConfigLoader.writeStarterIfMissing(at: url)
            if createdStarter { log.info("Wrote the starter config to \(self.url.path, privacy: .public)") }
        } catch {
            log.error("Unable to write the starter config: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }

    /// Reads the file again and uses it if it's valid (Reload Config).
    func reload() {
        switch ConfigLoader.load(contentsOf: url) {
        case let .success(config):
            loaded = config
            errors = []
            loadedAt = .now
            for warning in config.warnings { log.notice("Config warning: \(warning.message, privacy: .public)") }
            onLoad?(config)
        case let .failure(failure):
            errors = failure.issues
            for issue in failure.issues { log.error("Config error: \(issue.message, privacy: .public)") }
        }
    }

    /// Opens the file in the default editor for JSON.
    func openFile() {
        NSWorkspace.shared.open(url)
    }

    func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
