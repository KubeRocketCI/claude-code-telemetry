# Claude Code Telemetry

![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-Collector-425CC7?logo=opentelemetry&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-metrics-E6522C?logo=prometheus&logoColor=white)
![Loki](https://img.shields.io/badge/Loki-events-F5A800?logo=grafana&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-dashboards-F46800?logo=grafana&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-bundle-0F1689?logo=helm&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker%20Compose-testbed-2496ED?logo=docker&logoColor=white)

Self-hosted usage analytics for [Claude Code](https://code.claude.com), via OpenTelemetry.

## Why this exists

Claude Code emits rich OpenTelemetry metrics and events, but nothing to look at them with. This
repo is the missing back end: a small observability stack that answers **how many tokens and how
much cost** — broken down by model, agent, skill, tool, command, and bash usage — and attributes
it to business dimensions like `organization`, `project`, `jira.epic`, and `jira.story`.

It does this **without** capturing prompts, assistant responses, file contents, or raw API bodies.
Only aggregate counters and structured events cross the wire.

## What's in the box

A single pipeline — **OTel Collector → Prometheus (metrics) + Loki (events) → Grafana
(dashboards)** — packaged two ways so the same config runs on a laptop and in a cluster.

| Layer      | Role                                         |
|------------|----------------------------------------------|
| Collector  | OTLP ingest, attribution enrichment, fan-out |
| Prometheus | token/cost metrics, low-cardinality labels   |
| Loki       | high-cardinality events                      |
| Grafana    | pre-built usage & cost dashboards            |

Every datapoint carries a `collector.env` attribute (`local-poc` vs `k8s`), so both flavors can
safely feed shared dashboards without mixing sources.

## Use cases

**1 · Local development** — run the docker-compose testbed on your machine, point Claude Code at
it, and iterate on the collector pipeline and dashboards against real traffic.

```bash
cd local
docker compose up -d
# merge local/claude-settings.snippet.json into ~/.claude/settings.json, restart Claude Code
# open Grafana → "Claude Code — Usage Audit"
```

**2 · Team / Kubernetes** — deploy the Helm bundle to a cluster and let everyone push metrics and
events to one centralized stack.

```bash
helm dependency update deploy-templates
helm install claude-code-telemetry deploy-templates \
  -n claude-code-telemetry --create-namespace
```

The bundle is **deliberately isolated**: its Prometheus scrapes only this bundle's collector — no
cluster-wide discovery, no cluster-monitoring extras (node-exporter, kube-state-metrics,
alertmanager, pushgateway), namespace-scoped RBAC. Any component can be toggled off
(`grafana.enabled`, `prometheus.enabled`, …) to wire parts into an existing observability stack.

## Working on it

`local/` is the **source of truth** you iterate on; `deploy-templates/` is the replication target.
Validate a change locally, then port it to the Helm bundle and `helm lint` / `helm template`
before releasing.

| Artifact           | Iterate here (source of truth)    | Replicate to                                        |
|--------------------|-----------------------------------|-----------------------------------------------------|
| Collector pipeline | `local/otel-collector.yaml`       | `deploy-templates/values.yaml` → `alternateConfig`  |
| Dashboards         | `local/grafana/dashboards/*.json` | `deploy-templates/config/grafana/dashboards/*.json` |

See [`docs/analytics.md`](docs/analytics.md) for the attribution model, cardinality guidance, and
rollout plan, and [`spec/`](spec/) for the full Claude Code OTEL vocabulary.
