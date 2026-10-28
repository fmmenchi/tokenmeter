import Foundation

/// Reads the Claude plan label from the local profile. Decodes the two plan fields only (ADR 0012).
public struct ClaudePlanReader: Sendable {
    public let file: URL

    public init(file: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")) {
        self.file = file
    }

    private struct Profile: Decodable {
        struct Account: Decodable {
            let organizationType: String?
            let organizationRateLimitTier: String?
        }
        let oauthAccount: Account?
    }

    public func plan() -> String? {
        guard let data = try? Data(contentsOf: file),
              let account = (try? JSONDecoder().decode(Profile.self, from: data))?.oauthAccount else { return nil }
        return PlanName.claude(organizationType: account.organizationType, rateLimitTier: account.organizationRateLimitTier)
    }
}
