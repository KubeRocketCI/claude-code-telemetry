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
bodies. `spec/` is the DRY vocabulary of the full Claude Code OTEL surface (every config var, metric,
event, span, attribute; upstream links + snapshot date). `docs/analytics.md` is the design doc
(attribution, cardinality, governance, rollout) over the subset this stack uses — read it before
changing the pipeline.

## The one rule that governs everything

**The collector pipeline and dashboards exist in two places and must be kept in sync — `local/` is
the source of truth you iterate on; `deploy-templates/` is the replication target.**

| Artifact           | Iterate here (source of truth)    | Replicate to (deployable)                                                  |
|--------------------|-----------------------------------|----------------------------------------------------------------------------|
| Collector pipeline | `local/otel-collector.yaml`       | `deploy-templates/values.yaml` → `opentelemetry-collector.alternateConfig` |
| Dashboards         | `local/grafana/dashboards/<scope>/*.json` | `deploy-templates/config/grafana/dashboards/<scope>/*.json`        |

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
  recording rules or LogQL. Full catalog in `spec/`; `docs/analytics.md` §2 covers only the used subset.
- **Cardinality**: Prometheus stores one time series per unique label combination. Low/bounded attrs
  (`model`, `agent.name`, `skill.name`, `project`, `jira.epic`) are safe as metric labels;
  high-cardinality attrs (`jira.story`, `session.id`, `prompt.id`) belong in **logs only** at team
  scale — drop them from the metrics pipeline in the collector. The local PoC keeps `session.id`/`jira.story`
  as labels for convenience.
- **Attribution is injected via `OTEL_RESOURCE_ATTRIBUTES`** (comma-separated `key=value`), read
  once at `claude` startup and static for the whole session — hence "one Jira ticket ≈ one session".
  User identity (`user.email`, `user.id`, `organization.id`) is native and needs no injection.
- **Prometheus exporter settings matter**: Claude Code's metrics are OTel **counters**, so their
  Prometheus names carry the unit + `_total` suffix
  (`claude_code.token.usage` → `claude_code_token_usage_tokens_total`,
  `claude_code.cost.usage` → `claude_code_cost_usage_USD_total`, etc.); dashboards query these names.
  `resource_to_telemetry_conversion` turns resource attributes into queryable Prometheus labels.
  Dashboards depend on both.
- **Datasource UIDs (`prometheus`, `loki`) are hardcoded** to match across `local/grafana/provisioning`
  and the Helm `grafana.datasources` — dashboard JSON references these UIDs, so don't rename them or
  dashboards break in one environment.
- **Dashboards are organized by scope subdirectory → Grafana folder**: `claude-code/` (Claude Code
  usage) and `operational/` (collector health). Locally each subdir is a provisioning provider
  (`local/grafana/provisioning/dashboards/dashboards.yaml`); in Helm the subdir name maps to a folder
  via `dashboards.folders` + the sidecar `grafana_folder` annotation. Add a new scope in both places.
- **The Helm bundle is deliberately isolated**: its Prometheus scrapes exactly two static targets —
  `otel-collector:8889` (Claude Code data metrics, job `claude-code`) and `otel-collector:8888`
  (collector self-telemetry, job `otel-collector`) — with all cluster-discovery scrape jobs and
  cluster-monitoring extras (node-exporter, kube-state-metrics, alertmanager, pushgateway) disabled,
  and RBAC is namespace-scoped. Preserve this — do not add cluster-wide discovery or CRD/operator dependencies.
- **Version alignment**: the collector image (contrib `0.156.0`), Prometheus, Loki, and Grafana
  versions are intentionally kept close between `local/` and the Helm subcharts. When bumping one,
  check the other side.
