# Claude Code Usage Analytics

> Status: **Design / RFC** — for team review before any install.
> Goal: understand, at a low level, **for which project / story / epic** we spend
> Claude Code tokens and cost, and **which models, agents, skills, and tools** are involved —
> then aggregate it in a self-hosted observability stack (local → team → Kubernetes).

---

## 1. Summary

Claude Code has native **OpenTelemetry (OTEL)** support. It emits **metrics** (aggregatable
numbers) and **events/logs** (per-call detail) over standard OTLP to any collector. We attribute
usage to our own business dimensions — project, Jira epic, Jira story (user identity) — by injecting
**custom resource attributes** and enforcing them in an **OTel Collector**.

- **Metrics** → Prometheus → Grafana: "how much" dashboards (cost/tokens by model/agent/skill/project).
- **Events/logs** (full content) → Loki → Grafana: "what exactly happened" forensics and
  high-cardinality attribution (per-Jira-ticket cost, per-prompt breakdown).

---

## 2. What Claude Code emits

### 2.1 Enable (env vars — placed in `.claude/settings.json` `env` block)

| Var                            | Value                               | Purpose                                                  |
|--------------------------------|-------------------------------------|----------------------------------------------------------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1`                                 | Master switch                                            |
| `OTEL_METRICS_EXPORTER`        | `otlp`                              | Metrics transport                                        |
| `OTEL_LOGS_EXPORTER`           | `otlp`                              | Events/logs transport                                    |
| `OTEL_EXPORTER_OTLP_PROTOCOL`  | `grpc`                              | OTLP protocol (`grpc` \| `http/protobuf` \| `http/json`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT`  | `http://localhost:4317`             | Collector endpoint (local compose stack)                 |
| `OTEL_EXPORTER_OTLP_HEADERS`   | `Authorization=Bearer …`            | Auth (team stage)                                        |
| `OTEL_METRIC_EXPORT_INTERVAL`  | `10000`                             | Metrics flush (ms)                                       |
| `OTEL_LOGS_EXPORT_INTERVAL`    | `3000`                              | Logs flush (ms)                                          |

Content-capture gates — **PoC keeps prompts, responses, file contents, and raw API bodies OFF**
(privacy stance in the README). Only metadata is captured:
`OTEL_LOG_TOOL_DETAILS=1` (un-redacts skill/agent/MCP-tool names + bash commands and file paths),
while `OTEL_LOG_USER_PROMPTS=0`, `OTEL_LOG_ASSISTANT_RESPONSES=0`, `OTEL_LOG_TOOL_CONTENT=0`,
`OTEL_LOG_RAW_API_BODIES=0`. Flip these on only for a deliberate, isolated forensic session.

> **Note:** Claude Code does **not** propagate `OTEL_*` to subprocesses (Bash tool calls). Only the
> CLI process is instrumented.

### 2.2 Metrics (fixed names — cannot add new ones)

| Metric                                | Unit   | Key attributes                                                                                                                                            |
|---------------------------------------|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `claude_code.token.usage`             | tokens | `type` (input/output/cacheRead/cacheCreation), `model`, `agent.name`, `skill.name`, `mcp_server.name`, `mcp_tool.name`, `query_source`, `speed`, `effort` |
| `claude_code.cost.usage`              | USD    | same as above + `plugin.name`, `marketplace.name`                                                                                                         |
| `claude_code.session.count`           | count  | `start_type` (fresh/resume/continue/agents_view)                                                                                                          |
| `claude_code.lines_of_code.count`     | count  | `type` (added/removed), `model`                                                                                                                           |
| `claude_code.commit.count`            | count  | —                                                                                                                                                         |
| `claude_code.pull_request.count`      | count  | —                                                                                                                                                         |
| `claude_code.active_time.total`       | s      | `type` (user/cli)                                                                                                                                         |
| `claude_code.code_edit_tool.decision` | count  | `tool_name`, `decision` (accept/reject), `source`, `language`                                                                                             |

### 2.3 Events / logs (fixed names)

`user_prompt`, `assistant_response`, `tool_result`, `tool_decision`, `api_request`, `api_error`,
`api_refusal`, `api_request_body`/`api_response_body`, `skill_activated`, `mcp_server_connection`,
`plugin_installed`/`plugin_loaded`, `hook_*`, `compaction`, `at_mention`, `permission_mode_changed`,
`auth`, `feedback_survey`, `internal_error`.

Attribution-relevant:

- `api_request` → `model`, `cost_usd`, `input_tokens`, `output_tokens`, `cache_read_tokens`,
  `cache_creation_tokens`, `request_id`, `agent.name`, `skill.name`, `mcp_*`, correlated by `prompt.id`.
- `skill_activated` → `skill.name`, `invocation_trigger` (user-slash/claude-proactive/nested-skill),
  `skill.source`, `skill.kind`, `plugin.name`.
- `tool_decision` / `tool_result` → `tool_name`, `decision`, `duration_ms`, `success`, `error_type`.
- `workspace.host_paths` → host workspace directories (closest built-in "which repo" signal).

> Skills, subagents, and MCP tools are each **distinctly identifiable** — `skill.name`, `agent.name`,
> `mcp_server.name`/`mcp_tool.name`. Beta tracing adds a parent/child span tree for subagents.

---

## 3. Attribution model (the core design)

We enrich Claude Code telemetry with **custom business dimensions**. The only client injection
channel is `OTEL_RESOURCE_ATTRIBUTES` (comma-separated `key=value`), which is **read once at
`claude` startup and static for the whole session**. Discipline: **one Jira ticket ≈ one session**.

### 3.1 Custom attribute schema

Exactly three business dimensions as starting point:

| Key          | Example         | Source | Cardinality          | Home                                  |
|--------------|-----------------|--------|----------------------|---------------------------------------|
| `project`    | `krci-portal`   | manual | low                  | **metric**                            |
| `jira.epic`  | `EPMDEDP-15000` | manual | medium               | **metric**                            |
| `jira.story` | `EPMDEDP-17147` | manual | **high (unbounded)** | **logs** (drop from metrics at scale) |

`project` is the git repository name (a KRCI Codebase).

### 3.2 Cardinality rule (the "scalarity" concern)

In Prometheus every **unique label-value combination = one stored time series**. Cardinality grows
down the hierarchy: `project → jira.epic → jira.story`.

- **Low/bounded** (`model`, `type`, `agent.name`, `skill.name`, `tool_name`, `project`,
  `jira.epic`) → safe as **metric labels** → fast Grafana breakdowns.
- **High/unbounded** (`jira.story`, `session.id`, `prompt.id`) →
  **logs/events only**; derive per-story cost in **LogQL** over `api_request` events.

> PoC compromise: for the local single-user stack `jira.story` is kept as a metric label too (it's
> convenient and low-volume). For the team/K8s stage, drop it from the metrics pipeline in the
> collector (keep it only in logs) to bound Prometheus cardinality.

Control built-in cardinality with the include-gates:
`OTEL_METRICS_INCLUDE_SESSION_ID=false` (drop from metrics; keep on logs),
`OTEL_METRICS_INCLUDE_ACCOUNT_UUID`, `OTEL_METRICS_INCLUDE_ENTRYPOINT`,
`OTEL_METRICS_INCLUDE_VERSION`, `OTEL_METRICS_INCLUDE_RESOURCE_ATTRIBUTES`.

### 3.3 Running Claude Code with attribution (manual for now)

Set `OTEL_RESOURCE_ATTRIBUTES` before starting a session, then run `claude` as usual:

```bash
export OTEL_RESOURCE_ATTRIBUTES="project=krci-portal,jira.epic=EPMDEDP-15000,jira.story=EPMDEDP-17147"
claude
```

Use `none` for a dimension that doesn't apply (e.g. exploratory work with no story). Discipline:
one Jira ticket ≈ one session — the attributes are read once at startup and stay static.

> `OTEL_RESOURCE_ATTRIBUTES` value rules: comma-separated `key=value`, US-ASCII, no
> spaces/quotes/commas/semicolons/backslashes in values (percent-encode).

Automating this (a launcher wrapper deriving `project`/`jira.story` from git and resolving
`jira.epic` via Jira) is deliberately **out of scope for now** — a later phase.

### 3.4 User identity — native, no injection needed

Claude Code emits user identity as **standard attributes on every metric and event**, so we do
**not** define a custom metric or attribute for it:

| Attribute           | What it is                                | Availability                                                |
|---------------------|-------------------------------------------|-------------------------------------------------------------|
| `user.email`        | OAuth email (e.g. `jane_doe@example.com`) | when OAuth-authenticated                                    |
| `user.id`           | stable hashed user / IdP subject id       | always                                                      |
| `user.account_uuid` | Anthropic account UUID                    | gated by `OTEL_METRICS_INCLUDE_ACCOUNT_UUID` (default true) |
| `organization.id`   | org id                                    | when authenticated                                          |

These already flow into Prometheus labels (via `resource_to_telemetry_conversion`) and Loki, so
tokens/cost break down by `user_email` out of the box — no launcher change. Only inject a custom
identity attribute if you need a *different* identifier than the auth email (e.g. an internal LDAP
uid); then add `user.ldap=<uid>` to `OTEL_RESOURCE_ATTRIBUTES` alongside the others.

> **DAU/WAU/MAU depend on `user_email` staying a metric label.** The Operations & Adoption
> dashboard counts active users with
> `count(count by (user_email) (present_over_time(claude_code_session_count[<window>])))`.
> Note `present_over_time`, *not* `increase(...) > 0`: `session_count` carries `session.id`, so each
> session is a distinct flat series whose `increase()` is always 0. If `user_email` is ever demoted
> to logs-only for cardinality reasons, move this count to LogQL over the session events instead.

---

## 4. Governance — making attributes mandatory

Claude Code **cannot** refuse to start without a given attribute. Enforcement is layered:

1. **Launcher wrapper** (later phase) — always populates every key (sentinel default). Ensures *presence*.
2. **OTel Collector — the authoritative enforcement point** (server-side, users cannot bypass):
   - `resource` / `transform` processor → inject defaults for missing keys.
   - `filter` processor → **drop or route** telemetry missing required keys (e.g. no `project`).
   - `attributes` processor → validate/normalize values (regex `^[A-Z]+-[0-9]+$` for `jira.story`/`jira.epic`).
   - Also the single place to strip `session.id` from metrics, cap label sets, and redact content.
3. **Managed `settings.json`** (MDM, highest precedence) — pins telemetry ON, endpoint, auth, and the
   static baseline (`team`); users can't unset it.

> We cannot define **new metric names**, but we *can* mandate **dimensions** and derive new metrics
> downstream (Prometheus recording rules, LogQL).

---

## 5. Rollout path

1. **Local PoC** — collector + Prometheus + Loki + Grafana as a docker-compose stack (`local/`);
   single client; validate slicing by model/agent/skill/project/ticket; iterate dashboards.
2. **Team** — ship `env` block + launcher via **managed `.claude/settings.json`**; standardize the
   attribute schema; auth the OTLP endpoint (`OTEL_EXPORTER_OTLP_HEADERS` / `otelHeadersHelper`,
   refreshed ~29 min); enforce required attributes in the collector.
3. **Kubernetes target state** — the self-contained Helm bundle (`deploy-templates/`): upstream
   collector + prometheus + loki + grafana subcharts, plain Deployments, **no operator/CRD or
   cluster-wide monitoring prerequisites**; add longer retention, PVCs, OTLP auth, and multi-tenancy
   by `team`. A later step can graduate it into `edp-cluster-add-ons` as a first-class KRCI add-on.

---

## References

- Claude Code — Monitoring usage (OTEL): <https://code.claude.com/docs/en/monitoring-usage>
- Grafana Cloud Claude Code integration: <https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-claude-code/>
