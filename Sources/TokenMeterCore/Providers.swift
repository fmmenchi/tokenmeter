import Foundation

/// The one list of providers: exactly the entries of `providers.json`, all treated alike (ADR 0018).
public enum Providers {
    /// Fresh sources each call: they keep per-file scanning state.
    public static func standard(
        config: URL = ProviderConfigFile.defaultURL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [any ProviderSource] {
        let providers: [ProviderConfig]
        ProviderConfigFile.addClaudeIntegration(to: config)
        if let file = try? ProviderConfigFile.load(from: config) {
            providers = file.providers
        } else {
            // Missing: create it. Broken: leave it for the user and run on the seed; the probe says why.
            ProviderConfigFile.writeSeed(to: config)
            providers = ProviderConfigFile.seed().providers
        }
        return providers.map { ConfiguredSource($0, home: home) }
    }
}
