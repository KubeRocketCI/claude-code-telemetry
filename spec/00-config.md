# Config — Environment Variables

> Every knob Claude Code reads for OpenTelemetry. Set in shell env or the `env` block of
> `.claude/settings.json`. Managed (MDM) settings have highest precedence — users can't override.
> Source: <https://code.claude.com/docs/en/monitoring-usage> · snapshot 2026-07-10.

## Enablement

| Var                            | Value     | Default  | Description                                 |
|--------------------------------|-----------|----------|---------------------------------------------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1`       | disabled | **Master switch.** Required for any signal. |
| `DISABLE_ERROR_REPORTING`      | any value | unset    | Disables `internal_error` event emission.   |

## Exporter selection (which signals, which transport)

| Var                     | Values                                           | Default     | Description                                |
|-------------------------|--------------------------------------------------|-------------|--------------------------------------------|
| `OTEL_METRICS_EXPORTER` | `console` `otlp` `prometheus` `none` (comma-sep) | unset       | Metrics exporter(s).                       |
| `OTEL_LOGS_EXPORTER`    | `console` `otlp` `none` (comma-sep)              | unset       | Logs/events exporter(s).                   |
| `OTEL_TRACES_EXPORTER`  | `console` `otlp` `none` (comma-sep)              | unset (off) | Traces exporter(s). Needs beta flag below. |

## Protocol & endpoint

`OTEL_EXPORTER_OTLP_*` sets all signals; per-signal `*_METRICS_*` / `*_LOGS_*` / `*_TRACES_*` override it.

| Var                                   | Values                             | Default          | Description                    |
|---------------------------------------|------------------------------------|------------------|--------------------------------|
| `OTEL_EXPORTER_OTLP_PROTOCOL`         | `grpc` `http/json` `http/protobuf` | unset            | Protocol for all OTLP signals. |
| `OTEL_EXPORTER_OTLP_ENDPOINT`         | e.g. `http://localhost:4317`       | unset            | Endpoint for all OTLP signals. |
| `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL` | as above                           | inherits general | Metrics protocol override.     |
| `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` | e.g. `.../v1/metrics`              | inherits general | Metrics endpoint override.     |
| `OTEL_EXPORTER_OTLP_LOGS_PROTOCOL`    | as above                           | inherits general | Logs protocol override.        |
| `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`    | e.g. `.../v1/logs`                 | inherits general | Logs endpoint override.        |
| `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`  | as above                           | inherits general | Traces protocol override.      |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`  | e.g. `.../v1/traces`               | inherits general | Traces endpoint override.      |

> gRPC uses port `:4317`; HTTP uses `:4318` with `/v1/{metrics,logs,traces}` paths.

## Export intervals & temporality

| Var                                                 | Value (ms)           | Default        | Description                                                            |
|-----------------------------------------------------|----------------------|----------------|------------------------------------------------------------------------|
| `OTEL_METRIC_EXPORT_INTERVAL`                       | e.g. `5000`          | `60000` (60 s) | Metrics flush interval.                                                |
| `OTEL_LOGS_EXPORT_INTERVAL`                         | e.g. `1000`          | `5000` (5 s)   | Logs flush interval.                                                   |
| `OTEL_TRACES_EXPORT_INTERVAL`                       | e.g. `1000`          | `5000` (5 s)   | Span batch flush interval.                                             |
| `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE` | `delta` `cumulative` | `delta`        | Metrics temporality. Prometheus wants cumulative; delta for OTLP push. |

## Auth & headers

| Var                                                | Value                          | Default            | Description                                                                   |
|----------------------------------------------------|--------------------------------|--------------------|-------------------------------------------------------------------------------|
| `OTEL_EXPORTER_OTLP_HEADERS`                       | `Authorization=Bearer <token>` | unset              | Static OTLP headers (comma-sep `k=v`).                                        |
| `otelHeadersHelper` *(settings.json key, not env)* | path to script                 | unset              | Script emitting JSON headers; refreshed dynamically. `http/*` only, not gRPC. |
| `CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS`      | e.g. `900000`                  | `1740000` (29 min) | Dynamic-header refresh interval.                                              |

## mTLS (client certificates)

| Var                                                           | Protocol | Description                                     |
|---------------------------------------------------------------|----------|-------------------------------------------------|
| `CLAUDE_CODE_CLIENT_CERT`                                     | `http/*` | Client certificate file path.                   |
| `CLAUDE_CODE_CLIENT_KEY`                                      | `http/*` | Client key file path.                           |
| `CLAUDE_CODE_CLIENT_KEY_PASSPHRASE`                           | `http/*` | Passphrase for encrypted client key (optional). |
| `NODE_EXTRA_CA_CERTS`                                         | `http/*` | Trust the collector's CA.                       |
| `OTEL_EXPORTER_OTLP_CLIENT_KEY`                               | `grpc`   | Client key file path.                           |
| `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE`                       | `grpc`   | Client certificate file path.                   |
| `OTEL_EXPORTER_OTLP_CERTIFICATE`                              | `grpc`   | Trust the collector's CA.                       |
| `OTEL_EXPORTER_OTLP_{METRICS,LOGS,TRACES}_CLIENT_KEY`         | `grpc`   | Per-signal client key.                          |
| `OTEL_EXPORTER_OTLP_{METRICS,LOGS,TRACES}_CLIENT_CERTIFICATE` | `grpc`   | Per-signal client certificate.                  |

## Cardinality control (metrics only)

Toggle whether an attribute becomes a metric label. Trims Prometheus time-series explosion.

| Var                                        | Controls attribute                     | Default            | Set to flip                  |
|--------------------------------------------|----------------------------------------|--------------------|------------------------------|
| `OTEL_METRICS_INCLUDE_SESSION_ID`          | `session.id`                           | `true` (included)  | `false` to drop              |
| `OTEL_METRICS_INCLUDE_VERSION`             | `app.version`                          | `false` (excluded) | `true` to add                |
| `OTEL_METRICS_INCLUDE_ACCOUNT_UUID`        | `user.account_uuid`, `user.account_id` | `true`             | `false` to drop              |
| `OTEL_METRICS_INCLUDE_ENTRYPOINT`          | `app.entrypoint`                       | `false`            | `true` to add                |
| `OTEL_METRICS_INCLUDE_RESOURCE_ATTRIBUTES` | all `OTEL_RESOURCE_ATTRIBUTES` keys    | `true`             | `false` to drop from metrics |

> These gate **metric labels only** — the same attributes still ride on events/logs regardless.

## Content-capture flags (privacy gates — OFF by default)

| Var                            | Value               | Default                          | What it un-redacts                                                                                                                                                                           |
|--------------------------------|---------------------|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `OTEL_LOG_USER_PROMPTS`        | `1`                 | disabled                         | Prompt text on `user_prompt` event / `interaction` span.                                                                                                                                     |
| `OTEL_LOG_ASSISTANT_RESPONSES` | `1` / `0`           | inherits `OTEL_LOG_USER_PROMPTS` | Response text on `assistant_response`. *Requires v2.1.193+.*                                                                                                                                 |
| `OTEL_LOG_TOOL_DETAILS`        | `1`                 | disabled                         | Tool params/input, Bash commands, file paths, MCP/skill/agent/workflow names, plugin names.                                                                                                  |
| `OTEL_LOG_TOOL_CONTENT`        | `1`                 | disabled                         | Tool input+output bodies as span events (needs tracing; truncated 60 KB).                                                                                                                    |
| `OTEL_LOG_RAW_API_BODIES`      | `1` or `file:<dir>` | disabled                         | Full Messages API request/response JSON as `api_request_body`/`api_response_body`. `1` = inline (60 KB cap); `file:<dir>` = untruncated on disk + `body_ref`. Implies all three flags above. |

## Custom dimensions (attribution)

| Var                        | Value                 | Description                                                                                                                                                                              |
|----------------------------|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `OTEL_RESOURCE_ATTRIBUTES` | comma-sep `key=value` | Custom resource attributes on **every** metric/event. Read once at startup, static for the session. US-ASCII, no spaces/quotes/commas/semicolons/backslashes in values (percent-encode). |

## Distributed tracing (beta)

| Var                                           | Value    | Default  | Description                                                                                    |
|-----------------------------------------------|----------|----------|------------------------------------------------------------------------------------------------|
| `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA`         | `1`      | disabled | Enable span tracing. `ENABLE_ENHANCED_TELEMETRY_BETA` also accepted.                           |
| `CLAUDE_CODE_PROPAGATE_TRACEPARENT`           | `1`      | disabled | Send W3C `traceparent` on model + HTTP MCP requests when using custom `ANTHROPIC_BASE_URL`.    |
| `ENABLE_BETA_TRACING_DETAILED`                | `1`      | disabled | Enables `claude_code.hook` spans + content-bearing attrs (also needs `BETA_TRACING_ENDPOINT`). |
| `BETA_TRACING_ENDPOINT`                       | endpoint | unset    | Required with the detailed-tracing flag above.                                                 |
| `CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL` | set      | unset    | Emit `feedback_survey` events (sets `enabled_via_override=true`).                              |

## Managed settings (org-level, MDM)

`.claude/settings.json` distributed via MDM. High precedence, users can't override. Example:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.example.com:4317",
    "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=Bearer example-token"
  },
  "otelHeadersHelper": "/bin/generate_opentelemetry_headers.sh"
}
```

> **Subprocess isolation:** Claude Code does **not** pass `OTEL_*` to subprocesses (Bash tool, hooks,
> MCP servers, language servers). Only the CLI process is instrumented. (Exception: when tracing is on,
> `TRACEPARENT`/`TRACESTATE` *is* injected into Bash/PowerShell subprocesses — see `03-traces.md`.)
