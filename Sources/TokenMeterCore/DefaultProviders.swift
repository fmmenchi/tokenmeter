/// The seed of `~/.tokenmeter/providers.json`: what the file holds the first time (ADR 0017, 0018).
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
            "timestamp": "timestamp"
          },
          "usage": {
            "mode": "cumulative",
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
}
