import SwiftUI

/// Fixed sizes. Spacing lives in Space (Grid.swift).
enum Layout {
    /// The Settings window's single Form.
    static let settingsWidth: CGFloat = 520
    /// Bindings window sidebar.
    static let sidebarMin: CGFloat = 180
    static let sidebarIdeal: CGFloat = 200
    /// Bindings window minimum and first-open size.
    static let windowMin = CGSize(width: 680, height: 440)
    static let windowDefault = CGSize(width: 900, height: 600)

    /// The Guide: rows per column before it adds a column (12, then 24).
    static let guideRowsPerColumn = 12
    static let guideMaxColumns = 3
    /// Width of one Guide column; titles longer than this truncate.
    static let guideColumnWidth: CGFloat = 240
    /// A keycap's minimum width, so "E" and "F12" line up in a column.
    static let keycapMinWidth: CGFloat = 28
}
