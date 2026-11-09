import SwiftUI

/// The Settings window (Settings…, Command-Comma). A single pane, so no tabs,
/// titled "Unnamed Launcher Settings". One grouped Form, 520 pt wide, that
/// sizes to its content. Story S-032 adds the Guide, Keys and Feedback
/// sections and S-036 adds Startup (DESIGN.md, Information architecture).
struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                ContentUnavailableView(
                    "No Settings Yet",
                    systemImage: "gearshape",
                    description: Text("Guide timing, keys, feedback and Open at Login appear here.")
                )
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
        .noInitialFocus()
    }
}
