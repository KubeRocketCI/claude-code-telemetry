# claude-code-telemetry

Self-hosted usage analytics for [Claude Code](https://code.claude.com) via OpenTelemetry:
**how many tokens / how much cost, broken down by model, agent, skill, tool, command, and bash
usage** — attributed to `organization`, `project`, `jira.epic`, `jira.story` — **without** capturing
prompts, assistant responses, file contents, or raw API bodies.

Two use-cases:

```txt
   local/  (self-contained testbed)          deploy-templates/  (all-in-one Helm bundle)
   docker compose: Collector + Prometheus    upstream subcharts: opentelemetry-collector
   + Loki + Grafana — iterate here           + prometheus + loki + grafana — team install,
                └── validate, then replicate ────────────▲
                    (collector pipeline, dashboards)
```

1. **Local development** — run the docker-compose stack on your laptop, point Claude Code at it,
   iterate on the collector pipeline and dashboards.
2. **Team / Kubernetes** — deploy the Helm bundle to a cluster; everyone pushes metrics/events to
   the centralized stack. The bundle is **fully isolated**: its Prometheus scrapes only this
   bundle's collector (one static target, no cluster-wide discovery, no RBAC), and no
   cluster-monitoring extras (node-exporter, kube-state-metrics, alertmanager, pushgateway) are
   installed.

Everything a datapoint carries includes a `collector.env` resource attribute (`local-poc` vs
`k8s`), so sources stay distinguishable if both feed shared dashboards.

## Layout

| Path                                                                       | Purpose                                                                            |
|----------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `local/docker-compose.yaml`                                                | Self-contained debug stack (Collector + Prometheus + Loki + Grafana)               |
| `local/otel-collector.yaml`                                                | Local collector pipeline — hardcoded for the compose stack, **iterate here**       |
| `local/grafana/dashboards/*.json`                                          | Local dashboards — **iterate here**                                                |
| `local/{prometheus.yml,loki.yaml,grafana/provisioning}`                    | Local-only backend config                                                          |
| `local/claude-settings.snippet.json`                                       | `env` block to enable telemetry in `~/.claude/settings.json`                       |
| `deploy-templates/`                                                        | Helm chart — all-in-one bundle of upstream subcharts                               |
| `deploy-templates/values.yaml` → `opentelemetry-collector.alternateConfig` | **The deployable collector pipeline** — replicated from `local/` after validation  |
| `deploy-templates/config/grafana/dashboards/*.json`                        | Dashboard artifacts — shipped as sidecar ConfigMaps; replicated from `local/`      |
| `docs/analytics.md`                                                        | Design & capability reference (metrics, events, attribution, cardinality, rollout) |

## Use-case 1: local development

```bash
cd local
docker compose up -d          # Grafana :3000 · Prometheus :9090 · Loki :3100 · OTLP :4317
docker compose logs -f otel-collector
```

Then merge `local/claude-settings.snippet.json`'s `env` block into `~/.claude/settings.json` and
restart Claude Code. Dashboard: *Grafana → Claude Code — Usage Audit*.

Component versions (kept aligned with the Helm bundle where it matters):
otel-collector-contrib 0.156.0 · Prometheus v3.13.1 · Loki 3.6.7 · Grafana 13.1.0.

## Use-case 2: team Kubernetes bundle

One chart, four upstream subcharts — deployable on any cluster:

| Subchart                                 | Version                                   | Role                                                                 |
|------------------------------------------|-------------------------------------------|----------------------------------------------------------------------|
| `open-telemetry/opentelemetry-collector` | 0.164.1 (image pinned to contrib 0.156.0) | OTLP ingest + fan-out, plain Deployment                              |
| `prometheus-community/prometheus`        | 29.14.0                                   | metrics, 30d retention, PVC — scrapes **only** `otel-collector:8889` |
| `grafana/loki`                           | 7.0.0 (Loki 3.6.7)                        | events, SingleBinary + PVC, OTLP ingest                              |
| `grafana/grafana`                        | 10.5.15                                   | dashboards (sidecar-provisioned) + datasources                       |

```bash
helm dependency update deploy-templates
helm install claude-code-telemetry deploy-templates \
  -n claude-code-telemetry --create-namespace
```

Post-install NOTES print the OTLP endpoints, a port-forward quick-test, and how to fetch the
Grafana admin password. For laptops outside the cluster enable an OTLP entry point:

```yaml
ingress:
  http:              # plain HTTP :4318 — no TLS needed; clients set
    enabled: true    # OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
    host: otel.<your-domain>
  # grpc: ...        # gRPC :4317 — requires TLS + nginx GRPC backend-protocol
```

Every component can be toggled (`opentelemetry-collector.enabled`, `prometheus.enabled`,
`grafana.enabled`, `loki.enabled`) if you want to wire parts into an existing observability
stack instead.

## Change workflow

1. Iterate pipeline/dashboards in `local/` against real Claude Code traffic.
2. Replicate validated changes: pipeline → `deploy-templates/values.yaml`
   (`opentelemetry-collector.alternateConfig`); dashboards →
   `deploy-templates/config/grafana/dashboards/`.
3. `helm lint deploy-templates && helm template ct deploy-templates` — then release.

See `docs/analytics.md` for the full attribution model, cardinality guidance, and rollout plan.
