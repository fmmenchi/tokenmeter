import Foundation

/// The seed of `~/.tokenmeter/providers.json`: what the file holds the first time (ADR 0003).
/// A string constant rather than a resource: nothing to lose in the widget bundle.
enum DefaultProviders {
    static let json = #"""
    {
      "version": 1,
      "providers": [
        {
          "id": "claude",
          "title": "Claude",
          "windows": [300, 10080],
          "setupHint": "Claude quota: status line has not run yet",
          "integration": "claude-status-line",
          "log": {
            "root": "~/.claude/projects",
            "contains": "\"usage\":",
            "where": { "type": "assistant" },
            "timestamp": "timestamp"
          },
          "usage": {
            "mode": "perEvent",
            "dedupeBy": ["message.id", "requestId"],
            "model": "message.model",
            "families": [
              { "contains": "fable", "family": "Fable" },
              { "contains": "sonnet", "family": "Sonnet" },
              { "contains": "opus", "family": "Opus" },
              { "contains": "haiku", "family": "Haiku" }
            ],
            "tokens": {
              "input": "message.usage.input_tokens",
              "output": "message.usage.output_tokens",
              "cacheRead": "message.usage.cache_read_input_tokens",
              "cacheWrite": "message.usage.cache_creation_input_tokens"
            }
          },
          "quota": {
            "file": "~/.tokenmeter/claude-statusline.json",
            "windows": [
              { "at": "rate_limits.five_hour", "minutes": 300, "usedPercent": "used_percentage", "resetsAt": "resets_at", "existsIf": { "file": "~/.claude.json", "each": "cachedUsageUtilization.utilization.limits", "where": { "kind": "session" }, "observedAt": "cachedUsageUtilization.fetchedAtMs", "observedAtFormat": "epochMilliseconds" } },
              { "at": "rate_limits.seven_day", "minutes": 10080, "usedPercent": "used_percentage", "resetsAt": "resets_at" },
              { "file": "~/.claude.json", "each": "cachedUsageUtilization.utilization.limits", "where": { "kind": "weekly_scoped" }, "scope": "scope.model.display_name", "minutes": 10080, "usedPercent": "percent", "resetsAt": "resets_at", "resetsAtFormat": "iso8601", "observedAt": "cachedUsageUtilization.fetchedAtMs", "observedAtFormat": "epochMilliseconds" }
            ]
          },
          "plan": {
            "file": "~/.claude.json",
            "path": "oauthAccount.organizationType",
            "stripPrefix": "claude_",
            "labels": [
              { "path": "oauthAccount.organizationRateLimitTier", "contains": "max_20x", "label": "Ultra" },
              { "path": "oauthAccount.organizationRateLimitTier", "contains": "max_5x", "label": "Max 5x" },
              { "equals": "claude_max", "label": "Max" },
              { "equals": "claude_pro", "label": "Pro" },
              { "equals": "claude_team", "label": "Team" },
              { "equals": "claude_enterprise", "label": "Enterprise" }
            ]
          }
        },
        {
          "id": "chatgpt",
          "title": "ChatGPT",
          "windows": [300, 10080],
          "log": {
            "root": "~/.codex/sessions",
            "contains": "\"token_count\"",
            "where": { "type": "event_msg", "payload.type": "token_count" },
            "timestamp": "timestamp",
            "context": { "contains": "\"turn_context\"", "where": { "type": "turn_context" }, "model": "payload.model" }
          },
          "usage": {
            "mode": "cumulative",
            "families": [{ "contains": "gpt", "family": "GPT" }],
            "tokens": {
              "input": {
                "path": "payload.info.total_token_usage.input_tokens",
                "minus": "payload.info.total_token_usage.cached_input_tokens"
              },
              "output": "payload.info.total_token_usage.output_tokens",
              "cacheRead": "payload.info.total_token_usage.cached_input_tokens",
              "cacheWrite": "payload.info.total_token_usage.cache_write_input_tokens"
            }
          },
          "quota": {
            "windows": [
              { "at": "payload.rate_limits.primary", "minutesPath": "window_minutes", "usedPercent": "used_percent", "resetsAt": "resets_at" },
              { "at": "payload.rate_limits.secondary", "minutesPath": "window_minutes", "usedPercent": "used_percent", "resetsAt": "resets_at" }
            ]
          },
          "plan": { "path": "payload.rate_limits.plan_type" }
        }
      ]
    }
    """#

    /// The seed entry of `tool` as an account's entry (ADR 0014): `id`, `title` and `home` set, and every path of the
    /// default folder moved to `home`; Claude's `~/.claude.json` follows the folder too, and its status line file is
    /// named by the id. The seed id in the default folder is the seed entry itself.
    static func template(for tool: AccountTool, id: String, title: String, home: String) -> [String: Any] {
        var entry = seedEntry(tool.seedID)
        entry["id"] = id
        entry["title"] = title
        guard id != tool.seedID || home != tool.defaultHome else { return entry }
        entry["home"] = home
        return rewrite(entry, tool: tool, id: id, home: home) as! [String: Any]
    }

    /// The same, for a folder that is not the default: what `template` would give, so a writer can tell a path the
    /// template gave from one the person wrote (ADR 0014).
    static func derivedPath(_ path: String, tool: AccountTool, id: String, home: String) -> String {
        switch tool {
        case .claudeCode where path == "~/.tokenmeter/claude-statusline.json":
            return "~/.tokenmeter/\(id)-statusline.json"
        case .claudeCode where path == "~/.claude.json":
            return "\(home)/.claude.json"
        default:
            let prefix = tool.defaultHome + "/"
            return path.hasPrefix(prefix) ? home + "/" + path.dropFirst(prefix.count) : path
        }
    }

    private static func rewrite(_ value: Any, tool: AccountTool, id: String, home: String) -> Any {
        switch value {
        case let object as [String: Any]:
            return object.mapValues { rewrite($0, tool: tool, id: id, home: home) }
        case let list as [Any]:
            return list.map { rewrite($0, tool: tool, id: id, home: home) }
        case let path as String:
            return derivedPath(path, tool: tool, id: id, home: home)
        default:
            return value
        }
    }

    /// The seed entry with this id, as JSON. A constant checked by the seed's own test.
    static func seedEntry(_ id: String) -> [String: Any] {
        let object = try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        return (object["providers"] as! [[String: Any]]).first { $0["id"] as? String == id }!
    }

    /// What the migration adds to a file that exists: the path of the model and the family rules, by provider id (ADR 0010).
    /// The same as the seed holds; a test says so.
    static let usageFacts: [String: (model: String?, families: [[String: String]])] = [
        "claude": ("message.model", [
            ["contains": "fable", "family": "Fable"], ["contains": "sonnet", "family": "Sonnet"],
            ["contains": "opus", "family": "Opus"], ["contains": "haiku", "family": "Haiku"],
        ]),
        "chatgpt": (nil, [["contains": "gpt", "family": "GPT"]]),
    ]

    /// The line that names the model of a Codex turn, added to the `log` of an existing file (ADR 0010).
    static func logContext(for id: String) -> [String: Any]? {
        id == "chatgpt" ? ["contains": "\"turn_context\"", "where": ["type": "turn_context"], "model": "payload.model"] : nil
    }
}
