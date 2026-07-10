# Standard & Custom Attributes

> Attributes attached to **every** metric and event (and inherited by spans), plus correlation IDs
> and the custom-dimension channel. Source: <https://code.claude.com/docs/en/monitoring-usage> · snapshot 2026-07-10.

## Standard attributes (all metrics + all events)

| Attribute                                | Meaning                                                               | On metrics gated by                                     | Notes                                                     |
|------------------------------------------|-----------------------------------------------------------------------|---------------------------------------------------------|-----------------------------------------------------------|
| `session.id`                             | unique session id                                                     | `OTEL_METRICS_INCLUDE_SESSION_ID` (default on)          | UUID v4                                                   |
| `app.version`                            | Claude Code version                                                   | `OTEL_METRICS_INCLUDE_VERSION` (default off)            | semver                                                    |
| `app.entrypoint`                         | launch method                                                         | `OTEL_METRICS_INCLUDE_ENTRYPOINT` (default off)         | `cli` · `sdk-cli` · `sdk-ts` · `sdk-py` · `claude-vscode` |
| `organization.id`                        | org UUID                                                              | always when available                                   |                                                           |
| `user.account_uuid`                      | account UUID                                                          | `OTEL_METRICS_INCLUDE_ACCOUNT_UUID` (default on)        |                                                           |
| `user.account_id`                        | tagged account id, e.g. `user_01BWBeN28…`                             | `OTEL_METRICS_INCLUDE_ACCOUNT_UUID`                     |                                                           |
| `user.id`                                | anonymous id (persisted in `~/.claude.json`); on gateway: IdP subject | always                                                  |                                                           |
| `user.email`                             | OAuth/gateway email                                                   | always when available                                   | **key attribution dimension**                             |
| `terminal.type`                          | terminal, e.g. `iTerm.app` · `vscode` · `cursor` · `tmux`             | always when detected                                    |                                                           |
| `identity.source`                        | `gateway-oidc` on gateway sessions                                    | always on gateway                                       |                                                           |
| `user.groups`                            | IdP groups, CSV (gateway only)                                        | always on gateway                                       |                                                           |
| *(keys from `OTEL_RESOURCE_ATTRIBUTES`)* | custom dimensions                                                     | `OTEL_METRICS_INCLUDE_RESOURCE_ATTRIBUTES` (default on) | see below                                                 |

## Event-only attributes (in addition to standard)

| Attribute              | Meaning                                                                                 |
|------------------------|-----------------------------------------------------------------------------------------|
| `prompt.id`            | UUID v4 linking **all events from one user prompt** — the primary event correlation key |
| `event.name`           | event type name                                                                         |
| `event.timestamp`      | ISO 8601                                                                                |
| `event.sequence`       | monotonic counter for ordering within a session                                         |
| `workspace.host_paths` | host workspace dirs (desktop app) — closest built-in "which repo" signal                |
| `workflow.run_id`      | `wf_`-prefixed workflow run id *(v2.1.202+)*                                            |
| `workflow.name`        | workflow `meta.name` (→ `custom` unless `OTEL_LOG_TOOL_DETAILS=1`)                      |

## Custom dimensions — `OTEL_RESOURCE_ATTRIBUTES`

The **only** client injection channel. Comma-separated `key=value`, read once at `claude` startup,
**static for the whole session** → discipline: *one Jira ticket ≈ one session*.

- Rides on every metric (as a label, if `OTEL_METRICS_INCLUDE_RESOURCE_ATTRIBUTES=true`) and every event.
- Value rules: US-ASCII, no spaces/quotes/commas/semicolons/backslashes (percent-encode).
- In Prometheus, `resource_to_telemetry_conversion` turns these into queryable labels.

```bash
export OTEL_RESOURCE_ATTRIBUTES="project=krci-portal,jira.epic=EPMDEDP-15000,jira.story=EPMDEDP-17147"
```

> Our attribution schema, cardinality strategy (which of these stay metric labels vs. logs-only), and
> governance live in [`../docs/analytics.md`](../docs/analytics.md) — not here.

## Attribution-name redaction (applies wherever `agent.name`/`skill.name`/`plugin.name`/`mcp_*` appear)

| Origin                                              | Emitted as                                           | Un-redact                 |
|-----------------------------------------------------|------------------------------------------------------|---------------------------|
| Built-in / official-marketplace / official-registry | verbatim                                             | (always visible)          |
| User-configured MCP · custom subagent               | `custom`                                             | never                     |
| Third-party plugin / plugin skill                   | `third-party` (`custom_skill` for `skill_activated`) | `OTEL_LOG_TOOL_DETAILS=1` |

## Cardinality quick-reference (safe as metric labels vs. logs-only)

| Bounded → safe as metric label                                                                     | High-cardinality → logs/events only       |
|----------------------------------------------------------------------------------------------------|-------------------------------------------|
| `model`, `type`, `start_type`, `decision`, `source`, `language`, `query_source`, `speed`, `effort` | `session.id`, `prompt.id`, `request_id`   |
| `agent.name`, `skill.name`, `plugin.name`, `marketplace.name`, `mcp_server.name`, `mcp_tool.name`  | `workspace.host_paths`                    |
| `user.email`, `organization.id`, `terminal.type`, `app.entrypoint`                                 | custom unbounded dims (e.g. `jira.story`) |
| bounded custom dims (`project`, `jira.epic`)                                                       |                                           |
