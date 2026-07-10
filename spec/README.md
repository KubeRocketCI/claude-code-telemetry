# Claude Code OpenTelemetry Spec

> **Purpose:** a DRY, table-format **vocabulary** of *everything* Claude Code emits over
> OpenTelemetry — every config option, metric, event/log, span, and attribute — so we never
> re-discover it. Use it to design reports and to evaluate frameworks against a Claude Code baseline.
>
> **Not a design doc.** For *our* attribution model, cardinality strategy, governance, and rollout,
> see [`../docs/analytics.md`](../docs/analytics.md). This folder is the raw feature surface only.

## Files

| File | What it catalogs |
|------|------------------|
| [`00-config.md`](00-config.md)     | Every `CLAUDE_CODE_*` / `OTEL_*` env var: enablement, exporters, protocols, auth/mTLS, intervals, cardinality gates, content-capture flags, tracing, managed settings |
| [`01-metrics.md`](01-metrics.md)   | All 8 metrics — name, unit, semantics, per-metric attributes |
| [`02-events.md`](02-events.md)     | All log events — name, purpose, per-event attributes |
| [`03-traces.md`](03-traces.md)     | Beta span hierarchy — spans, attributes, GenAI semantic conventions, context propagation |
| [`04-attributes.md`](04-attributes.md) | Standard/global attributes (metrics + events), redaction rules, custom `OTEL_RESOURCE_ATTRIBUTES` |

## What is fixed vs. what we control

- **Metric names, event names, span names, and their built-in attributes are fixed by Claude Code.**
  You cannot invent new ones. New *metrics* are derived downstream (Prometheus recording rules / LogQL).
- **You control**: which signals/exporters are on, cardinality gates (`OTEL_METRICS_INCLUDE_*`),
  content-capture (`OTEL_LOG_*`), and **custom dimensions** via `OTEL_RESOURCE_ATTRIBUTES`.

## Signal support at a glance

| Signal | Env to enable | Exporters | Default state |
|--------|---------------|-----------|---------------|
| Metrics | `OTEL_METRICS_EXPORTER` | `console`, `otlp`, `prometheus`, `none` | off |
| Logs / events | `OTEL_LOGS_EXPORTER` | `console`, `otlp`, `none` | off |
| Traces / spans | `OTEL_TRACES_EXPORTER` + `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` | `console`, `otlp`, `none` | off (beta) |

All three require the master switch `CLAUDE_CODE_ENABLE_TELEMETRY=1`.

## Keeping this current

Upstream evolves (new events, version-gated attributes). Re-fetch and diff these sources:

- **Authoritative — Claude Code / Monitoring usage (OTEL):** <https://code.claude.com/docs/en/monitoring-usage>
  (redirected from `https://docs.claude.com/en/docs/claude-code/monitoring-usage`)
- **Grafana Cloud — Claude Code integration:** <https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-claude-code/>
- **OpenTelemetry env var spec (the `OTEL_*` names Claude Code honors):** <https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/>
- **OTel GenAI semantic conventions (the `gen_ai.*` span attributes):** <https://opentelemetry.io/docs/specs/semconv/gen-ai/>

> **Snapshot:** captured **2026-07-10** against Claude Code **v2.1.x**. Attributes tagged
> *"Requires vX.Y.Z"* below appear only on that version or later. When you refresh, bump this date and
> note added/removed rows.
