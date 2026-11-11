import Foundation

/// Picks the action Context Aware runs for the app in front (SPEC.md,
/// Actions, contextual).
public enum ContextResolver {
    /// The action to run, or nil when the action is unavailable for this app.
    /// Other kinds of action are returned as they are.
    public static func resolve(_ action: Config.Action, frontApp: String?,
                               contexts: [Config.Context]) -> Config.Action? {
        guard case let .contextual(variants, fallback) = action else { return action }
        if let frontApp {
            // The first context, in `contexts` order, that has the app and a variant.
            for context in contexts where context.apps.contains(frontApp) {
                if let variant = variants[context.id] { return variant }
            }
        }
        return fallback
    }
}

extension LoadedConfig {
    /// False for a Context Aware binding with nothing to run for this app.
    public func isAvailable(_ binding: BindingNode, frontApp: String?) -> Bool {
        guard let id = binding.action, let action = config.actions[id] else { return true }
        return ContextResolver.resolve(action, frontApp: frontApp, contexts: config.contexts) != nil
    }
}

/// Where a Guide row's icon comes from (S-054, S-055).
public enum IconSource: Hashable, Sendable {
    /// An app's icon, by bundle id.
    case app(String)
    /// The Finder icon of a file or folder, by full path.
    case file(String)
    /// The icon of the app that opens a URL.
    case url(URL)
    /// An SF Symbol, by name (S-056).
    case symbol(String)
}

extension LoadedConfig {
    /// The icon for an entry: its own icon if it has one (S-056); otherwise
    /// its app for Use Application, its file, folder or URL for Open. nil for
    /// menus and every other action, Context Aware included.
    public func iconSource(_ binding: BindingNode, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> IconSource? {
        if let icon = binding.icon { return IconSource(icon, home: home) }
        guard let id = binding.action else { return nil }
        switch config.actions[id] {
        case let .application(bundleId, _):
            return .app(bundleId)
        case let .open(target):
            guard let url = try? ActionPlanner.openURL(target, home: home) else { return nil }
            // The path as written, ~ expanded: a folder's file URL adds a trailing slash.
            return url.isFileURL ? .file(ActionPlanner.expandTilde(target, home: home)) : .url(url)
        default:
            return nil
        }
    }

    /// Every icon the bindings use, so each can be looked up once.
    public func iconSources(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Set<IconSource> {
        func sources(_ nodes: [BindingNode]) -> [IconSource] {
            nodes.flatMap { node in (iconSource(node, home: home).map { [$0] } ?? []) + sources(node.children) }
        }
        return Set(sources(leaders))
    }
}

extension IconSource {
    /// An entry's `icon`: a path starting with / or ~ is a file, anything
    /// else an SF Symbol name.
    public init(_ icon: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self = icon.hasPrefix("/") || icon.hasPrefix("~") ? .file(ActionPlanner.expandTilde(icon, home: home)) : .symbol(icon)
    }
}
