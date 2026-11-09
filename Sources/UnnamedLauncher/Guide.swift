import AppKit
import SwiftUI
import UnnamedLauncherKit

/// What the Guide shows for one menu (S-005).
struct GuideContent: Equatable {
    struct Row: Equatable, Identifiable {
        var key: String
        var title: String
        var isMenu: Bool
        /// False for Context Aware with nothing to run in the app in front.
        var isAvailable = true
        /// "not available in Notes", shown on an unavailable row.
        var note: String?
        var id: String { key }
    }

    var path: [String]
    var rows: [Row]
    var cancelKey: String
    /// nil when Back is turned off.
    var backKey: String?
    /// Why an action failed (S-015). When set, the Guide shows only this.
    var failure: String?

    init(menu: BindingNode, path: [String], config: LoadedConfig, frontApp: String?, frontAppName: String? = nil) {
        self.path = path
        let appName = frontAppName ?? frontApp.flatMap(Self.appName) ?? "this app"
        rows = menu.children.compactMap { child in
            child.path.lastStep.map { step in
                let available = child.isMenu || config.isAvailable(child, frontApp: frontApp)
                return Row(key: step.key.name, title: child.title, isMenu: child.isMenu,
                           isAvailable: available, note: available ? nil : "not available in \(appName)")
            }
        }
        cancelKey = Self.footerLabel(config.cancelKey)
        backKey = config.backKey.map(Self.footerLabel)
    }

    /// The name people know an app by, from its bundle id.
    private static func appName(_ bundleId: String) -> String? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.localizedName
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
    /// The error flash for an unbound key (S-018).
    var isFlashing = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            pathRow
            if let failure = content.failure {
                failureRow(failure)
            } else {
                menuRows
                footer
            }
        }
        .padding(Space.margin)
        .fixedSize()
        .background { background }
        .overlay {
            // The flash outlines the Guide in the accent, the Guide's one use of it.
            RoundedRectangle(cornerRadius: Radius.guide)
                .strokeBorder(Palette.accent, lineWidth: Space.xs / 2)
                .opacity(isFlashing ? 1 : 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(content.failure ?? content.announcement)
    }

    private func failureRow(_ message: String) -> some View {
        Label {
            Text(message)
                .frame(maxWidth: Layout.guideFailureWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(Surfaces.warning)
    }

    private var menuRows: some View {
            HStack(alignment: .top, spacing: Space.xl) {
                ForEach(Array(content.columns.enumerated()), id: \.offset) { _, column in
                    // A Grid lines the titles up after the widest keycap.
                    Grid(alignment: .leading, horizontalSpacing: Space.sm, verticalSpacing: Space.sm) {
                        ForEach(column) { row in rowView(row) }
                    }
                    .frame(width: Layout.guideColumnWidth, alignment: .leading)
                }
            }
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
            VStack(alignment: .leading, spacing: 0) {
                Text(row.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let note = row.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .foregroundStyle(.secondary)
                .opacity(row.isMenu ? 1 : 0)
        }
        .opacity(row.isAvailable ? 1 : Surfaces.unavailableOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.key), \(row.title)\(row.isMenu ? ", menu" : "")\(row.note.map { ", \($0)" } ?? "")")
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

extension GuideContent {
    static let placeholder = GuideContent(path: [], rows: [], cancelKey: "esc", backKey: "delete")

    init(path: [String], rows: [Row], cancelKey: String, backKey: String?, failure: String? = nil) {
        self.path = path
        self.rows = rows
        self.cancelKey = cancelKey
        self.backKey = backKey
        self.failure = failure
    }
}
