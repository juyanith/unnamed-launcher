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

extension LoadedConfig {
    /// The app a Use Application binding uses, for its icon in the Guide
    /// (S-054). nil for menus and every other action, Context Aware included.
    public func appBundleId(_ binding: BindingNode) -> String? {
        guard let id = binding.action, case let .application(bundleId, _) = config.actions[id] else { return nil }
        return bundleId
    }

    /// Every app the bindings use, so their icons can be looked up once.
    public var appBundleIds: Set<String> {
        func ids(_ nodes: [BindingNode]) -> [String] {
            nodes.flatMap { node in (appBundleId(node).map { [$0] } ?? []) + ids(node.children) }
        }
        return Set(ids(leaders))
    }
}
