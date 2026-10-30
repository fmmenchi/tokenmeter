import Foundation

/// The integrations the app knows, by the id `providers.json` gives them in `integration`.
public struct Integrations: Sendable {
    private let byID: [String: any ProviderIntegration]

    public init(_ integrations: [any ProviderIntegration]) {
        byID = Dictionary(integrations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public subscript(id: String) -> (any ProviderIntegration)? { byID[id] }
}
