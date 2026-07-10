# Metrics

> All 8 metrics Claude Code emits. Names are **fixed** — derive new metrics downstream via Prometheus
> recording rules / LogQL. Every metric also carries the [standard attributes](04-attributes.md).
> Prometheus name = OTEL name with `.` → `_` (with `add_metric_suffixes: false`, so
> `claude_code.token.usage` → `claude_code_token_usage`). Source: <https://code.claude.com/docs/en/monitoring-usage> · snapshot 2026-07-10.

## Catalog

| Metric                                | Unit   | Kind                        | Description                          |
|---------------------------------------|--------|-----------------------------|--------------------------------------|
| `claude_code.session.count`           | count  | gauge (inc at start)        | CLI sessions started.                |
| `claude_code.lines_of_code.count`     | count  | gauge                       | Lines of code modified.              |
| `claude_code.pull_request.count`      | count  | gauge                       | Pull requests created.               |
| `claude_code.commit.count`            | count  | gauge                       | Git commits created.                 |
| `claude_code.cost.usage`              | USD    | gauge (inc per API request) | Estimated session cost.              |
| `claude_code.token.usage`             | tokens | gauge (inc per API request) | Tokens used.                         |
| `claude_code.code_edit_tool.decision` | count  | gauge                       | Code-edit tool permission decisions. |
| `claude_code.active_time.total`       | s      | gauge                       | Total active time.                   |

## Per-metric attributes (beyond standard)

### `claude_code.session.count`

| Attr         | Values                                                                                  |
|--------------|-----------------------------------------------------------------------------------------|
| `start_type` | `fresh` · `resume` · `continue` · `agents_view` (the `claude agents` dashboard process) |

### `claude_code.lines_of_code.count`

| Attr    | Values                                        |
|---------|-----------------------------------------------|
| `type`  | `added` · `removed`                           |
| `model` | e.g. `claude-sonnet-5` *(Requires v2.1.172+)* |

### `claude_code.pull_request.count`

| Attr | Values                   |
|------|--------------------------|
| —    | standard attributes only |

### `claude_code.commit.count`

| Attr | Values                   |
|------|--------------------------|
| —    | standard attributes only |

### `claude_code.cost.usage`

| Attr               | Values                                                                                               |
|--------------------|------------------------------------------------------------------------------------------------------|
| `model`            | e.g. `claude-sonnet-5`                                                                               |
| `query_source`     | `main` · `subagent` · `auxiliary`                                                                    |
| `speed`            | `fast` (absent when normal)                                                                          |
| `effort`           | `low` · `medium` · `high` · `xhigh` · `max` (absent if model has no effort)                          |
| `agent.name`       | subagent type (built-in/official verbatim; custom → `custom`)                                        |
| `skill.name`       | active skill (built-in/bundled verbatim; 3rd-party → `third-party` unless `OTEL_LOG_TOOL_DETAILS=1`) |
| `plugin.name`      | owning plugin (official verbatim; 3rd-party → `third-party`)                                         |
| `marketplace.name` | marketplace (official-marketplace only)                                                              |
| `mcp_server.name`  | MCP server (built-in/official verbatim; user-configured → `custom`)                                  |
| `mcp_tool.name`    | MCP tool (same redaction as `mcp_server.name`)                                                       |

### `claude_code.token.usage`

| Attr                                                                                              | Values                                             |
|---------------------------------------------------------------------------------------------------|----------------------------------------------------|
| `type`                                                                                            | `input` · `output` · `cacheRead` · `cacheCreation` |
| `model`, `query_source`, `speed`, `effort`                                                        | same as cost.usage                                 |
| `agent.name`, `skill.name`, `plugin.name`, `marketplace.name`, `mcp_server.name`, `mcp_tool.name` | same redaction as cost.usage                       |

### `claude_code.code_edit_tool.decision`

| Attr        | Values                                                                                 |
|-------------|----------------------------------------------------------------------------------------|
| `tool_name` | `Edit` · `Write` · `NotebookEdit`                                                      |
| `decision`  | `accept` · `reject`                                                                    |
| `source`    | `config` · `hook` · `user_permanent` · `user_temporary` · `user_abort` · `user_reject` |
| `language`  | `TypeScript` · `Python` · `JavaScript` · `Markdown` · … · `unknown`                    |

### `claude_code.active_time.total`

| Attr   | Values                                                    |
|--------|-----------------------------------------------------------|
| `type` | `user` (keyboard) · `cli` (tool execution + AI responses) |

## Attribution redaction (applies to `agent.name` / `skill.name` / `plugin.name` / `mcp_*`)

| Source                                              | Emitted as    | Un-redact with                  |
|-----------------------------------------------------|---------------|---------------------------------|
| Built-in / official-marketplace / official-registry | verbatim name | (always)                        |
| User-configured MCP / custom subagent               | `custom`      | — (never un-redacted for these) |
| Third-party plugin skill / plugin                   | `third-party` | `OTEL_LOG_TOOL_DETAILS=1`       |
