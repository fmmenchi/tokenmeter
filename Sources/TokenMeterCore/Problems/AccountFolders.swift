import Foundation

/// The folders of a tool (ADR 0014): which folder is a Claude Code or a Codex CLI one, who is signed in there, and where
/// the app looks for one nobody named. Read only, and the email is the one thing read from a file of credentials.
public enum AccountFolders {
    /// A folder of a tool, with the email it is signed in with when there is one.
    public struct Found: Equatable, Sendable {
        public let tool: AccountTool
        public let folder: URL
        public let email: String?

        public init(tool: AccountTool, folder: URL, email: String?) {
            self.tool = tool
            self.folder = folder
            self.email = email
        }
    }

    /// The folder an entry reads, as a URL: `home` with `~` expanded, or the tool's default folder when nil.
    public static func folder(of home: String?, tool: AccountTool,
                              userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        let path = home ?? tool.defaultHome
        if path == "~" { return userHome }
        if path.hasPrefix("~/") { return userHome.appendingPathComponent(String(path.dropFirst(2))) }
        return URL(fileURLWithPath: path)
    }

    /// Whether `folder` holds what the tool leaves in its folder: `.claude.json` and `projects/` for Claude Code,
    /// `auth.json` and `config.toml` for the Codex CLI.
    public static func isFolder(_ folder: URL, of tool: AccountTool) -> Bool {
        let fileManager = FileManager.default
        func exists(_ name: String, directory: Bool) -> Bool {
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: folder.appendingPathComponent(name).path, isDirectory: &isDirectory)
                && isDirectory.boolValue == directory
        }
        switch tool {
        case .claudeCode: return exists(".claude.json", directory: false) && exists("projects", directory: true)
        case .codexCLI: return exists("auth.json", directory: false) && exists("config.toml", directory: false)
        }
    }

    /// The tool whose folder this is, if any.
    public static func tool(of folder: URL) -> AccountTool? {
        AccountTool.allCases.first { isFolder(folder, of: $0) }
    }

    /// The email the folder is signed in with: `oauthAccount.emailAddress` of Claude Code's `.claude.json`, or the `email`
    /// claim of the identity token in the Codex CLI's `auth.json`. The token is decoded and nothing of it is kept; a login
    /// with an API key, or a token that cannot be read, gives nil.
    public static func email(in folder: URL, tool: AccountTool) -> String? {
        switch tool {
        case .claudeCode:
            guard let object = json(folder.appendingPathComponent(".claude.json")),
                  let account = object["oauthAccount"] as? [String: Any],
                  let email = account["emailAddress"] as? String, !email.isEmpty else { return nil }
            return email
        case .codexCLI:
            guard let object = json(folder.appendingPathComponent("auth.json")),
                  let tokens = object["tokens"] as? [String: Any],
                  let token = tokens["id_token"] as? String else { return nil }
            return claim("email", of: token)
        }
    }

    /// Every folder of a tool at the top of the person's home: the hidden folders there, and the defaults. Never deeper.
    public static func scan(userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Found] {
        let fileManager = FileManager.default
        var candidates = AccountTool.allCases.map { folder(of: nil, tool: $0, userHome: userHome) }
        if let names = try? fileManager.contentsOfDirectory(atPath: userHome.path) {
            candidates += names.filter { $0.hasPrefix(".") }.sorted().map { userHome.appendingPathComponent($0) }
        }
        var seen = Set<String>()
        return candidates.compactMap { folder in
            let path = folder.standardizedFileURL.path
            guard seen.insert(path).inserted, let tool = tool(of: folder) else { return nil }
            return Found(tool: tool, folder: URL(fileURLWithPath: path, isDirectory: true), email: email(in: folder, tool: tool))
        }
    }

    private static func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// One string claim of a JWT's payload, read without checking the signature: it is the person's own file, and the
    /// claim is shown to them alone.
    static func claim(_ name: String, of token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let value = object[name] as? String, !value.isEmpty else { return nil }
        return value
    }
}
