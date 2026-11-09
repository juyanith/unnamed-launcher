import AppKit
import UnnamedLauncherKit

/// Ties the parts together: permissions, the event tap, the sequence
/// engine, the Guide and the actions (M1). The menu bar menu reads its state.
@Observable
final class Launcher {
    let store: ConfigStore
    private(set) var missingPermissions: [Permission] = Permission.missing
    /// Both permissions are granted but macOS still refused the tap.
    private(set) var needsRelaunch = false
    /// The last failed action, for the log and the Guide (S-015).
    private(set) var lastFailure: String?

    /// Enabled in the menu bar menu (S-009). Remembered across launches.
    var isEnabled: Bool = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet {
            if !Store.isOverridden { UserDefaults.standard.set(isEnabled, forKey: "enabled") }
            updateCapture()
        }
    }

    /// The engine runs on the tap thread; effects come back to the main queue.
    @ObservationIgnored private let engine = EngineBox()
    @ObservationIgnored private lazy var capture = KeyCapture { [engine, weak self] event in
        let output = engine.handle(event)
        if let effect = output.effect {
            // The main queue keeps effects in order: show, then run.
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.apply(effect) } }
        }
        return output.consume
    }
    @ObservationIgnored let guide = GuideController()
    @ObservationIgnored private var permissionTimer: Timer?
    /// False in snapshots and the self-test, which never touch the keyboard.
    @ObservationIgnored private var capturesKeys = false

    init(store: ConfigStore) {
        self.store = store
        store.onLoad = { [unowned self] config in
            engine.replace(config)
            guide.hide()
        }
    }

    /// True while leaders are being captured.
    var isCapturing: Bool { capture.isRunning }

    /// Loads the config and starts capturing. Snapshots and the self-test
    /// pass `captureKeys: false`, so they never touch the real keyboard.
    func start(captureKeys: Bool) {
        store.start()
        capturesKeys = captureKeys
        guard captureKeys else { return }
        updateCapture()
        // Grants happen in System Settings, so look again every two seconds
        // until both are in, and whenever the app becomes active.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
    }

    func refreshPermissions() {
        let missing = Permission.missing
        if missing != missingPermissions { missingPermissions = missing }
        updateCapture()
    }

    private func updateCapture() {
        guard capturesKeys else { return }
        if isEnabled && missingPermissions.isEmpty {
            let started = capture.start()
            if needsRelaunch == started { needsRelaunch = !started }
        } else {
            capture.stop()
            engine.reset()
            guide.hide()
            if needsRelaunch { needsRelaunch = false }
        }
    }

    /// Quits and opens a fresh copy, for grants that need a relaunch.
    func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    /// Removes the tap before quitting (S-009).
    func stop() {
        capture.stop()
    }

    // MARK: - Events

    private func apply(_ effect: SequenceEffect) {
        guard let config = store.loaded else { return }
        switch effect {
        case let .showMenu(menu, path):
            if config.config.runtime.showHud {
                guide.show(GuideContent(menu: menu, path: path, config: config))
            }
        case let .run(binding):
            guide.hide()
            guard let id = binding.action, let action = config.config.actions[id] else { return }
            Task {
                do throws(ActionRunner.Failure) {
                    try await ActionRunner.run(action, id: id)
                } catch {
                    lastFailure = error.message
                    log.error("Action failed: \(error.message, privacy: .public)")
                }
            }
        case .cancelled:
            guide.hide()
        case .unbound:
            // Flash and timing arrive in M3 (S-018); the bell works now.
            if config.config.ui.errorBell { NSSound.beep() }
        }
    }
}
