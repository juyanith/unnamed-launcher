import AppKit
import SwiftUI
import UnnamedLauncherKit

/// What the Guide shows for one menu (S-005).
struct GuideContent: Equatable {
    struct Row: Equatable, Identifiable {
        var key: String
        var title: String
        var isMenu: Bool
        var id: String { key }
    }

    var path: [String]
    var rows: [Row]
    var cancelKey: String
    /// nil when Back is turned off.
    var backKey: String?

    init(menu: BindingNode, path: [String], config: LoadedConfig) {
        self.path = path
        rows = menu.children.compactMap { child in
            child.path.lastStep.map { Row(key: $0.key.name, title: child.title, isMenu: child.isMenu) }
        }
        cancelKey = Self.footerLabel(config.cancelKey)
        backKey = config.backKey.map(Self.footerLabel)
    }

    /// "esc" and "delete", as printed on a Mac keyboard, for the default
    /// keys; the key name otherwise.
    private static func footerLabel(_ key: KeyName) -> String {
        switch key {
        case .escape: "esc"
        case .backspace: "delete"
        default: key.name
        }
    }

    /// Rows split into columns of at most 12, up to three (DESIGN.md).
    var columns: [[Row]] {
        let perColumn = max(Layout.guideRowsPerColumn,
                            Int((Double(rows.count) / Double(Layout.guideMaxColumns)).rounded(.up)))
        return stride(from: 0, to: rows.count, by: perColumn).map { Array(rows[$0..<min($0 + perColumn, rows.count)]) }
    }

    /// What VoiceOver says when the Guide opens or changes menu.
    var announcement: String {
        "\(path.last ?? ""), \(rows.count) \(rows.count == 1 ? "key" : "keys")"
    }
}

/// The Guide: the path, the next keys, and how to cancel or go back.
struct GuideView: View {
    let content: GuideContent
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            pathRow
            HStack(alignment: .top, spacing: Space.xl) {
                ForEach(Array(content.columns.enumerated()), id: \.offset) { _, column in
                    // A Grid lines the titles up after the widest keycap.
                    Grid(alignment: .leading, horizontalSpacing: Space.sm, verticalSpacing: Space.sm) {
                        ForEach(column) { row in rowView(row) }
                    }
                    .frame(width: Layout.guideColumnWidth, alignment: .leading)
                }
            }
            footer
        }
        .padding(Space.margin)
        .fixedSize()
        .background { background }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(content.announcement)
    }

    private var pathRow: some View {
        Text(content.path.joined(separator: " › "))
            .font(.headline)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }

    private func rowView(_ row: GuideContent.Row) -> some View {
        GridRow {
            Keycap(label: row.key)
                .gridColumnAlignment(.leading)
            Text(row.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .foregroundStyle(.secondary)
                .opacity(row.isMenu ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.key), \(row.title)\(row.isMenu ? ", menu" : "")")
    }

    private var footer: some View {
        HStack(spacing: Space.lg) {
            footerKey(content.cancelKey, "Cancel")
            if let back = content.backKey { footerKey(back, "Back") }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func footerKey(_ key: String, _ title: String) -> some View {
        HStack(spacing: Space.xs) {
            Keycap(label: key, font: .system(.caption, design: .monospaced))
            Text(title)
        }
    }

    @ViewBuilder private var background: some View {
        // The Guide is all control layer, so rows sit on its glass (rule 9).
        if reduceTransparency {
            RoundedRectangle(cornerRadius: Radius.guide).fill(.regularMaterial)
        } else {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: Radius.guide))
        }
    }
}

/// The panel that holds the Guide. Non-activating and never key, so the
/// app in front keeps its focus; keys come from the event tap, not here.
final class GuidePanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Shows, updates and hides the Guide.
final class GuideController {
    private let panel = GuidePanel()
    private let host = NSHostingView(rootView: GuideView(content: .placeholder))
    private(set) var content: GuideContent?
    /// Whether the Guide is meant to be up. Kept separately from the panel,
    /// because a fade doesn't finish while the display is asleep.
    private var isShown = false

    init() {
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentView = host
    }

    var isVisible: Bool { isShown && panel.isVisible }
    var window: NSWindow { panel }

    func show(_ content: GuideContent) {
        let wasVisible = isVisible
        isShown = true
        self.content = content
        host.rootView = GuideView(content: content)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setContentSize(size)
        // Center on the main screen. S-019 picks the front app's screen and position.
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
        }
        if !wasVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            fade(to: 1)
        }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: content.announcement, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        content = nil
        fade(to: 0)
        // Order out after the fade by the clock, not the animation's
        // completion, which never comes while the display is asleep.
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.guideFadeSeconds) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 0
            }
        }
    }

    /// A fade from Motion; instant under Reduce Motion.
    private func fade(to alpha: CGFloat) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = alpha
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.guideFadeSeconds
            panel.animator().alphaValue = alpha
        }
    }
}

extension GuideContent {
    static let placeholder = GuideContent(path: [], rows: [], cancelKey: "esc", backKey: "delete")

    init(path: [String], rows: [Row], cancelKey: String, backKey: String?) {
        self.path = path
        self.rows = rows
        self.cancelKey = cancelKey
        self.backKey = backKey
    }
}
