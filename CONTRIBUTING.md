# Contributing to claude-code-telemetry

Thanks for your interest in improving **claude-code-telemetry** — self-hosted
[Claude Code](https://code.claude.com) usage analytics for the
[KubeRocketCI](https://docs.kuberocketci.io) platform! Contributions of all
kinds are welcome: bug reports, collector-pipeline fixes, dashboard
improvements, Helm bundle changes, and documentation.

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## What this repo is

This repo is **configuration, dashboards, and packaging** — it has no runtime
service code of its own. It carries two deployment surfaces that must stay in
sync:

| Path                                            | What lives here                                                             |
|-------------------------------------------------|-----------------------------------------------------------------------------|
| `local/docker-compose.yaml`                     | Self-contained testbed (Collector + Prometheus + Loki + Grafana)            |
| `local/otel-collector.yaml`                     | Local collector pipeline — **iterate here first**                           |
| `local/grafana/dashboards/*.json`               | Local dashboards — **iterate here first**                                   |
| `local/claude-settings.snippet.json`            | `env` block that enables telemetry in `~/.claude/settings.json`             |
| `deploy-templates/`                             | Helm bundle — upstream collector/prometheus/loki/grafana subcharts          |
| `deploy-templates/values.yaml`                  | `opentelemetry-collector.alternateConfig` — the **deployable** pipeline     |
| `deploy-templates/config/grafana/dashboards/`   | Dashboard artifacts shipped as sidecar ConfigMaps                           |
| `docs/analytics.md`                             | Design & capability reference (metrics, events, attribution, cardinality)   |

## Privacy guardrail

This stack captures **usage metadata only** — never prompts, assistant
responses, file contents, or raw API bodies. Do not add attributes, log records,
or defaults that capture message content without an explicit, documented opt-in.
See [SECURITY.md](SECURITY.md).

## Ways to contribute

- **Report a bug** — open an [issue](https://github.com/KubeRocketCI/claude-code-telemetry/issues/new/choose)
  with your OS, `docker`/`helm` versions, the relevant collector logs, and the
  failing command.
- **Fix the pipeline or dashboards** — change `local/` first, validate against
  real Claude Code traffic, then replicate into `deploy-templates/`.
- **Improve docs** — `README.md` and `docs/analytics.md` are first-class; keep
  them aligned with the actual shipped config.

## Development workflow

1. **Fork** the repo and create a topic branch off `main`.
2. **Iterate locally** against real Claude Code traffic:

   ```bash
   cd local
   docker compose up -d
   docker compose logs -f otel-collector
   ```
   Merge `local/claude-settings.snippet.json`'s `env` block into
   `~/.claude/settings.json` and restart Claude Code.
3. **Replicate validated changes** into the Helm bundle:
   - pipeline → `deploy-templates/values.yaml`
     (`opentelemetry-collector.alternateConfig`)
   - dashboards → `deploy-templates/config/grafana/dashboards/`
4. **Validate the chart:**

   ```bash
   helm dependency update deploy-templates
   helm lint deploy-templates
   helm template ct deploy-templates
   ```
5. **Keep versions consistent.** Component versions in
   `local/docker-compose.yaml`, `deploy-templates/Chart.yaml` / `Chart.lock`,
   and the README tables must agree.
6. **Update docs.** If you change the pipeline, attribution model, or layout,
   update `README.md` and `docs/analytics.md`.

## Pull requests

- Keep PRs focused; one logical change per PR.
- Use clear, imperative commit messages (Conventional Commits style is
  appreciated, e.g. `feat:`, `fix:`, `docs:`, `chore:`).
- Describe how you validated (compose logs, `helm template` output, dashboard
  screenshots).
- By submitting a contribution you agree it is licensed under the
  [Apache License 2.0](LICENSE), consistent with the rest of this project.

## Reporting security issues

Please do **not** file public issues for vulnerabilities. Follow the
[Security Policy](SECURITY.md) instead.

## Questions

Open an [issue](https://github.com/KubeRocketCI/claude-code-telemetry/issues),
or learn more about the platform at <https://docs.kuberocketci.io>.
