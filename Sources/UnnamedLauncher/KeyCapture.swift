import AppKit
import CoreGraphics
import UnnamedLauncherKit

/// The session-level event tap (SPEC.md, Permissions and lifecycle). It
/// sends every key event to `handler`, which decides at once whether to
/// consume it. The tap's source is on the main run loop, so the handler
/// runs on the main thread and must never block.
final class KeyCapture {
    /// Returns true to consume the event.
    private let handler: (KeyEvent) -> Bool
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    init(handler: @escaping (KeyEvent) -> Bool) {
        self.handler = handler
    }

    var isRunning: Bool { tap != nil }

    /// Installs the tap. Returns false when macOS refuses, which happens when
    /// a permission is missing or a new grant needs a relaunch.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: keyCaptureCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            log.error("macOS refused the event tap")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        log.info("Capturing leader keys")
        return true
    }

    /// Removes the tap, so no keys are captured.
    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        log.info("Stopped capturing keys")
    }

    fileprivate func handle(_ raw: RawKeyEvent) -> Bool {
        switch raw.type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turned the tap off (S-037). Turn it back on.
            log.notice("macOS turned off the event tap (\(raw.type.rawValue)); turning it back on")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown:
            return handler(.down(keyCode: raw.keyCode, modifiers: Modifiers(raw.flags), isRepeat: raw.isRepeat))
        case .keyUp:
            return handler(.up(keyCode: raw.keyCode))
        case .flagsChanged:
            return handler(.flags(Modifiers(raw.flags)))
        default:
            return false
        }
    }
}

/// The parts of a CGEvent the tap needs, copied out so they can cross to
/// the main actor.
struct RawKeyEvent: Sendable {
    var type: CGEventType
    var keyCode: UInt16
    var isRepeat: Bool
    var flags: CGEventFlags
}

/// The C callback. It runs on the main run loop, where the tap's source is.
nonisolated private func keyCaptureCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                            userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let raw = RawKeyEvent(type: type,
                          keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)),
                          isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                          flags: event.flags)
    let address = UInt(bitPattern: userInfo)
    let consume = MainActor.assumeIsolated {
        let capture = Unmanaged<KeyCapture>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue()
        return capture.handle(raw)
    }
    return consume ? nil : Unmanaged.passUnretained(event)
}

extension Modifiers {
    /// The four chord modifiers in a CGEvent's flags. Caps Lock and Fn are ignored.
    nonisolated init(_ flags: CGEventFlags) {
        var modifiers: Modifiers = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        self = modifiers
    }
}
