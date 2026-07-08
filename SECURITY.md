# Security Policy

## What this repository is

`claude-code-telemetry` is self-hosted usage analytics for
[Claude Code](https://code.claude.com) via OpenTelemetry. It ships two things: a
local `docker-compose` testbed (`local/`) and a self-contained Helm bundle
(`deploy-templates/`) of upstream OpenTelemetry Collector, Prometheus, Loki, and
Grafana subcharts. It contains configuration and dashboards — no runtime service
code of its own.

## Data handling and privacy

The collector pipeline is designed to capture **usage metadata only** — tokens,
cost, and the model / agent / skill / tool / command dimensions — attributed to
business dimensions (`project`, `jira.epic`, `jira.story`) and to native
identity attributes (`user.email`, `user.id`, `organization.id`).

By design it does **not** capture prompts, assistant responses, file contents, or
raw API bodies: the shipped `local/claude-settings.snippet.json` keeps
`OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_ASSISTANT_RESPONSES`, `OTEL_LOG_TOOL_CONTENT`,
and `OTEL_LOG_RAW_API_BODIES` **off**. If you deliberately enable those content
gates for a forensic session, the telemetry becomes privacy-sensitive — protect
the backends accordingly.

## Insecure local defaults — do not expose

The `local/` testbed trades security for convenience and **must stay on
localhost**: the OTLP endpoint is unauthenticated, Grafana runs with default
credentials, and no TLS is used. Do not point production Claude Code clients at
it or expose its ports beyond your machine.

For the Kubernetes bundle, authenticate the OTLP ingress
(`OTEL_EXPORTER_OTLP_HEADERS` / an `otelHeadersHelper`), set a strong Grafana
admin password, and place the endpoint behind TLS before any multi-user rollout.

## Reporting a vulnerability

- **A vulnerability in this repo** (e.g. a collector/dashboard config that leaks
  captured content, or an insecure default that could affect users following the
  README): please report it privately via
  [GitHub Security Advisories](https://github.com/KubeRocketCI/claude-code-telemetry/security/advisories/new)
  or by email to **SupportEPMD-EDP@epam.com**. Please do not open a public issue
  for undisclosed vulnerabilities.
- **A vulnerability in KubeRocketCI itself**: report it through the
  [KubeRocketCI project](https://docs.kuberocketci.io) channels.
- **A vulnerability in a bundled third-party component** (OpenTelemetry
  Collector, Prometheus, Loki, Grafana) or in Claude Code: report it to that
  project upstream.

We aim to acknowledge reports within 5 business days.

## Supported versions

Only the latest `main` is maintained; there are no backports. Bundled component
versions are pinned in `deploy-templates/Chart.yaml` / `Chart.lock` and
`local/docker-compose.yaml`.
