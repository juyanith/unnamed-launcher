import Foundation

/// A key event from the event tap, reduced to what the engine needs.
public enum KeyEvent: Sendable, Equatable {
    case down(keyCode: UInt16, modifiers: Modifiers, isRepeat: Bool)
    case up(keyCode: UInt16)
    /// The modifiers held changed (flagsChanged).
    case flags(Modifiers)
}

/// What the app should do after one event.
public enum SequenceEffect: Sendable, Equatable {
    /// A sequence started or moved into a menu, including Back. Show it.
    /// `frontApp` is the app that was in front when the leader was pressed.
    case showMenu(BindingNode, path: [String], frontApp: String?)
    /// A binding was selected, or a direct binding's chord was pressed: run its
    /// action for `frontApp`. Any sequence has ended.
    case run(BindingNode, frontApp: String?)
    /// A Context Aware binding with nothing to run for the app in front.
    /// The sequence stays in its menu (S-013).
    case unavailable(BindingNode, path: [String])
    /// Cancel, or Back from a leader's menu. The sequence has ended.
    case cancelled
    /// A key that isn't bound. The sequence stays in `menu`.
    case unbound(BindingNode, path: [String])
}

public struct SequenceOutput: Sendable, Equatable {
    /// True when the event must not reach the app in front.
    public var consume: Bool
    public var effect: SequenceEffect?

    public static let pass = SequenceOutput(consume: false, effect: nil)
    static func consumed(_ effect: SequenceEffect? = nil) -> SequenceOutput { .init(consume: true, effect: effect) }
}

/// The sequence state machine (SPEC.md, During a sequence). Pure: key
/// events in, decisions out, no AppKit and no timers, so the event tap's
/// callback stays fast and every rule is unit-tested.
public struct SequenceEngine: Sendable {
    public private(set) var config: LoadedConfig
    /// The menus from the leader down to the current one. Empty when idle.
    public private(set) var stack: [BindingNode] = []
    /// Leader modifiers still physically held. They're ignored on step keys.
    private var heldLeaderModifiers: Modifiers = []
    /// Key-downs that were consumed, so their key-ups are consumed too.
    private var consumedKeys: Set<UInt16> = []
    /// The app in front right now, kept up to date by the app.
    private var frontApp: String?
    /// The app that was in front when the leader was pressed.
    public private(set) var sequenceFrontApp: String?

    public init(config: LoadedConfig) {
        self.config = config
    }

    public var isActive: Bool { !stack.isEmpty }

    /// The titles from the leader down: ["Commands", "Applications"].
    public var path: [String] { stack.map(\.title) }

    /// Swaps in a new config. A running sequence ends.
    public mutating func replaceConfig(_ config: LoadedConfig) {
        self.config = config
        stack = []
    }

    /// The bundle id of the app in front. Call it whenever that changes.
    public mutating func setFrontApp(_ bundleId: String?) {
        frontApp = bundleId
    }

    /// Ends the sequence from outside (for example, Enabled turned off).
    public mutating func reset() {
        stack = []
        heldLeaderModifiers = []
    }

    public mutating func handle(_ event: KeyEvent) -> SequenceOutput {
        switch event {
        case let .flags(modifiers):
            // Once a leader modifier is released it stops being ignored.
            heldLeaderModifiers.formIntersection(modifiers)
            return .pass

        case let .up(keyCode):
            return consumedKeys.remove(keyCode) != nil ? .consumed() : .pass

        case let .down(keyCode, modifiers, isRepeat):
            if stack.isEmpty {
                return idle(keyCode: keyCode, modifiers: modifiers, isRepeat: isRepeat)
            }
            consumedKeys.insert(keyCode)
            if isRepeat { return .consumed() }
            return step(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private mutating func idle(keyCode: UInt16, modifiers: Modifiers, isRepeat: Bool) -> SequenceOutput {
        guard let key = KeyName(keyCode: keyCode),
              let leader = config.leader(for: Chord(modifiers: modifiers, key: key)) else {
            // A repeat of a consumed leader is still consumed.
            return isRepeat && consumedKeys.contains(keyCode) ? .consumed() : .pass
        }
        if !leader.isMenu {
            // A direct binding runs at once, with no sequence. One that has
            // nothing to run for the app in front lets the chord through.
            guard config.isAvailable(leader, frontApp: frontApp) else { return .pass }
            if isRepeat { return .consumed() }
            consumedKeys.insert(keyCode)
            return .consumed(.run(leader, frontApp: frontApp))
        }
        if isRepeat { return .consumed() }
        consumedKeys.insert(keyCode)
        heldLeaderModifiers = modifiers
        sequenceFrontApp = frontApp
        stack = [leader]
        return .consumed(.showMenu(leader, path: path, frontApp: sequenceFrontApp))
    }

    private mutating func step(keyCode: UInt16, modifiers: Modifiers) -> SequenceOutput {
        guard let menu = stack.last else { return .pass }
        guard let key = KeyName(keyCode: keyCode) else { return .consumed(.unbound(menu, path: path)) }
        let extra = modifiers.subtracting(heldLeaderModifiers)

        if extra.isEmpty && key == config.cancelKey {
            reset()
            return .consumed(.cancelled)
        }
        if extra.isEmpty && key == config.backKey {
            stack.removeLast()
            guard let parent = stack.last else {
                reset()
                return .consumed(.cancelled)
            }
            return .consumed(.showMenu(parent, path: path, frontApp: sequenceFrontApp))
        }
        guard extra.isEmpty, let child = menu.child(for: key) else {
            return .consumed(.unbound(menu, path: path))
        }
        if child.isMenu {
            stack.append(child)
            return .consumed(.showMenu(child, path: path, frontApp: sequenceFrontApp))
        }
        guard config.isAvailable(child, frontApp: sequenceFrontApp) else {
            return .consumed(.unavailable(child, path: path))
        }
        let app = sequenceFrontApp
        reset()
        return .consumed(.run(child, frontApp: app))
    }
}
