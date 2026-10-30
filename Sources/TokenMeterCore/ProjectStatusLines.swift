import Foundation

/// Finds projects whose own settings replace the status line tokenmeter relies on (ADR 0026).
/// Read only: nothing is ever written to a project.
public enum ProjectStatusLines {
    public struct Override: Equatable, Sendable {
        public let project: URL
        /// The command in force there; empty when the status line is not a `command` one.
        public let command: String
    }

    /// One sentence for the widget, the panel and Settings; nil when no project overrides the status line (ADR 0027).
    public static func notice(for overrides: [Override]) -> String? {
        guard !overrides.isEmpty else { return nil }
        let names = overrides.prefix(3).map(\.project.lastPathComponent).joined(separator: ", ")
        let more = overrides.count > 3 ? " +\(overrides.count - 3)" : ""
        return "Claude bars freeze in \(names)\(more): own status line"
    }

    static let headBytes = 256 * 1024

    public static func overrides(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date(), days: Int = 30, limit: Int = 200
    ) -> [Override] {
        let fileManager = FileManager.default
        let root = home.appendingPathComponent(".claude/projects")
        guard let folders = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        let oldest = now.addingTimeInterval(-Double(days) * 86_400)

        var seen = Set<String>()
        var found: [Override] = []
        for folder in folders.prefix(limit) {
            guard let project = recentProject(in: folder, since: oldest), project.path != home.path,
                  seen.insert(project.path).inserted,
                  let line = statusLine(of: project) else { continue }
            if let command = line["command"] as? String,
               command.contains("claude-statusline.sh") || command.contains("claude/statusline-wrapper.sh") { continue }
            found.append(Override(project: project, command: line["command"] as? String ?? ""))
        }
        return found.sorted { $0.project.path < $1.project.path }
    }

    /// The working directory of the newest transcript in `folder`, if it was touched since `date` and still exists.
    private static func recentProject(in folder: URL, since date: Date) -> URL? {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return nil }
        let newest = files.filter { $0.pathExtension == "jsonl" }
            .compactMap { file -> (URL, Date)? in
                guard let modified = try? file.resourceValues(forKeys: Set(keys)).contentModificationDate else { return nil }
                return (file, modified)
            }
            .max { $0.1 < $1.1 }
        guard let (file, modified) = newest, modified >= date,
              let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: headBytes)) ?? Data()
        for line in head.split(separator: UInt8(ascii: "\n")) {
            guard let object = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                  let cwd = object["cwd"] as? String else { continue }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: cwd, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            return URL(fileURLWithPath: cwd, isDirectory: true)
        }
        return nil
    }

    /// The status line in force in a project: the local file first, then the shared one.
    private static func statusLine(of project: URL) -> [String: Any]? {
        for name in ["settings.local.json", "settings.json"] {
            let file = project.appendingPathComponent(".claude").appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let value = object["statusLine"] else { continue }
            return value as? [String: Any] ?? [:]
        }
        return nil
    }
}
