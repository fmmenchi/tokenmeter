import Foundation

/// The one list of providers: those the app ships with, then the user's `providers.json`, which adds
/// new ones and replaces a built-in with the same id (ADR 0015, 0016, 0017).
public enum Providers {
    /// Fresh sources each call: they keep per-file scanning state.
    public static func standard(
        config: URL = ProviderConfigFile.defaultURL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [any ProviderSource] {
        var merged = ProviderConfigFile.builtIn().providers
        // A broken file adds nothing and leaves the built-ins alone; the probe prints why.
        for provider in ((try? ProviderConfigFile.load(from: config)) ?? nil)?.providers ?? [] {
            if let index = merged.firstIndex(where: { $0.id == provider.id }) {
                merged[index] = provider
            } else {
                merged.append(provider)
            }
        }
        return merged.map { ConfiguredSource($0, home: home) }
    }
}
