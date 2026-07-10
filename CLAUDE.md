# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Self-hosted usage analytics for **Claude Code itself**, via OpenTelemetry. There is no application
code — the repo is two parallel deployments of the same observability stack (OTel Collector →
Prometheus for metrics + Loki for events → Grafana for dashboards):

- `local/` — a docker-compose testbed you iterate against real Claude Code traffic on your laptop.
- `deploy-templates/` — a self-contained Helm bundle of upstream subcharts for a team Kubernetes install.

The goal is attributing token/cost usage to business dimensions (`project`, `jira.epic`,
`jira.story`, `user.email`) **without** capturing prompts, responses, file contents, or raw API
bodies. `docs/analytics.md` is the authoritative design reference (metric/event catalog, attribution
model, cardinality rules, governance, rollout plan) — read it before changing the pipeline.

## The one rule that governs everything

**The collector pipeline and dashboards exist in two places and must be kept in sync — `local/` is
the source of truth you iterate on; `deploy-templates/` is the replication target.**

| Artifact           | Iterate here (source of truth)    | Replicate to (deployable)                                                  |
|--------------------|-----------------------------------|----------------------------------------------------------------------------|
| Collector pipeline | `local/otel-collector.yaml`       | `deploy-templates/values.yaml` → `opentelemetry-collector.alternateConfig` |
| Dashboards         | `local/grafana/dashboards/*.json` | `deploy-templates/config/grafana/dashboards/*.json`                        |

The two pipeline copies differ **only** in: `collector.env` value (`local-poc` vs `${env:COLLECTOR_ENV:-k8s}`),
the Loki endpoint (hardcoded vs `${env:LOKI_ENDPOINT:-...}`), and debug `verbosity`. Keep receivers,
processors, exporters, and service pipelines otherwise identical. Never edit `alternateConfig` as
the first move — validate in `local/` first, then port.

## Commands

```bash
# Local testbed
cd local
docker compose up -d                     # Grafana :3000 · Prometheus :9090 · Loki :3100 · OTLP :4317/:4318
docker compose logs -f otel-collector    # confirm data flows; discover exact attribute names
docker compose down                      # stop        (down -v also wipes volumes)

# Helm bundle — always validate before proposing a release
helm dependency update deploy-templates  # pull subchart .tgz into deploy-templates/charts/
helm lint deploy-templates
helm template ct deploy-templates        # render; check the collector ConfigMap + dashboard ConfigMaps
helm install claude-code-telemetry deploy-templates \
  -n claude-code-telemetry --create-namespace
```

Check the two collector-pipeline copies haven't drifted (only `collector.env`, the Loki endpoint,
and debug `verbosity` should differ):

```bash
diff <(yq '.["opentelemetry-collector"].alternateConfig' deploy-templates/values.yaml) local/otel-collector.yaml
```

To point Claude Code at the local stack: merge the `env` block from
`local/claude-settings.snippet.json` into `~/.claude/settings.json` and restart Claude Code.

## Things that are easy to get wrong

- **Metric/event names are fixed by Claude Code** — you cannot invent new ones. You *can* mandate
  new **dimensions** (resource attributes) and derive new metrics downstream via Prometheus
  recording rules or LogQL. See `docs/analytics.md` §2 for the exact metric/event catalog.
- **Cardinality**: Prometheus stores one time series per unique label combination. Low/bounded attrs
  (`model`, `agent.name`, `skill.name`, `project`, `jira.epic`) are safe as metric labels;
  high-cardinality attrs (`jira.story`, `session.id`, `prompt.id`) belong in **logs only** at team
  scale — drop them from the metrics pipeline in the collector. The local PoC keeps `session.id`/`jira.story`
  as labels for convenience.
- **Attribution is injected via `OTEL_RESOURCE_ATTRIBUTES`** (comma-separated `key=value`), read
  once at `claude` startup and static for the whole session — hence "one Jira ticket ≈ one session".
  User identity (`user.email`, `user.id`, `organization.id`) is native and needs no injection.
- **Prometheus exporter settings matter**: `add_metric_suffixes: false` keeps names predictable
  (`claude_code.token.usage` → `claude_code_token_usage`); `resource_to_telemetry_conversion` is what
  turns resource attributes into queryable Prometheus labels. Dashboards depend on both.
- **Datasource UIDs (`prometheus`, `loki`) are hardcoded** to match across `local/grafana/provisioning`
  and the Helm `grafana.datasources` — dashboard JSON references these UIDs, so don't rename them or
  dashboards break in one environment.
- **The Helm bundle is deliberately isolated**: its Prometheus scrapes exactly one static target
  (`otel-collector:8889`) with all cluster-discovery scrape jobs and cluster-monitoring extras
  (node-exporter, kube-state-metrics, alertmanager, pushgateway) disabled, and RBAC is
  namespace-scoped. Preserve this — do not add cluster-wide discovery or CRD/operator dependencies.
- **Version alignment**: the collector image (contrib `0.156.0`), Prometheus, Loki, and Grafana
  versions are intentionally kept close between `local/` and the Helm subcharts. When bumping one,
  check the other side.
