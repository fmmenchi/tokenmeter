import Foundation

/// The shape of `~/.tokenmeter/providers.json` (ADR 0016). Dotted paths and nothing else.
public struct ProviderConfigFile: Decodable, Sendable {
    public let version: Int
    public let providers: [ProviderConfig]

    public static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".tokenmeter/providers.json")

    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    /// Nil when the file does not exist; throws when it exists but cannot be used.
    public static func load(from url: URL = defaultURL) throws -> ProviderConfigFile? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let file: ProviderConfigFile
        do {
            file = try JSONDecoder().decode(ProviderConfigFile.self, from: Data(contentsOf: url))
        } catch {
            throw Failure(description: "\(url.path): \(error)")
        }
        guard file.version == 1 else { throw Failure(description: "\(url.path): unsupported version \(file.version)") }
        var seen = Set<String>()
        for provider in file.providers {
            guard !provider.id.isEmpty, seen.insert(provider.id).inserted else {
                throw Failure(description: "\(url.path): provider id \"\(provider.id)\" is empty or repeated")
            }
            guard !provider.windows.isEmpty, provider.windows.allSatisfy({ $0 > 0 }) else {
                throw Failure(description: "\(url.path): \"\(provider.id)\" needs windows in minutes")
            }
        }
        return file
    }
}

public struct ProviderConfig: Decodable, Sendable {
    public let id: String
    public let title: String
    public let windows: [Int]
    public let setupHint: String?
    public let log: Log?
    public let usage: Usage?
    public let quota: Quota?
    public let plan: Plan?

    public struct Log: Decodable, Sendable {
        public let root: String
        /// Cheap byte filter applied before a line is decoded.
        public let contains: String?
        /// Paths that must equal these strings for a line to count.
        public let `where`: [String: String]?
        /// ISO 8601 timestamp path.
        public let timestamp: String
    }

    public struct Usage: Decodable, Sendable {
        public enum Mode: String, Decodable, Sendable { case perEvent, cumulative }
        public let mode: Mode
        public let dedupeBy: [String]?
        public let tokens: Tokens
    }

    public struct Tokens: Decodable, Sendable {
        public let input: Field?
        public let output: Field?
        public let cacheRead: Field?
        public let cacheWrite: Field?
    }

    /// A path, or `{ "path": …, "minus": … }` for a difference.
    public struct Field: Decodable, Sendable {
        public let path: String
        public let minus: String?

        public init(from decoder: any Decoder) throws {
            if let path = try? decoder.singleValueContainer().decode(String.self) {
                self.path = path
                minus = nil
            } else {
                let keyed = try decoder.container(keyedBy: Keys.self)
                path = try keyed.decode(String.self, forKey: .path)
                minus = try keyed.decodeIfPresent(String.self, forKey: .minus)
            }
        }

        private enum Keys: String, CodingKey { case path, minus }
    }

    public struct Quota: Decodable, Sendable {
        public let file: String?
        public let windows: [Window]

        public struct Window: Decodable, Sendable {
            public enum TimeFormat: String, Decodable, Sendable { case epochSeconds, iso8601 }
            /// The object holding the fields below; the line or file root when absent.
            public let at: String?
            public let usedPercent: String
            public let resetsAt: String?
            public let resetsAtFormat: TimeFormat?
            public let minutes: Int?
            public let minutesPath: String?
        }
    }

    public struct Plan: Decodable, Sendable {
        public let file: String?
        public let path: String
    }
}
