<a name="unreleased"></a>
## [Unreleased]


<a name="v0.1.0"></a>
## v0.1.0 - 2026-07-11
### Features

- add role-audit Wave 1 widgets for delivery, safety, and session diagnostics
- add adoption, efficiency, and plugin governance panels
- add Session Explorer dashboard and security audit panels
- add Efficiency & ROI and Governance & Security dashboards
- add spec/ vocabulary of full Claude Code OTEL surface
- add Operations & Adoption dashboard for DAU/WAU/MAU and API health

### Bug Fixes

- pin prometheus server service name so the Grafana datasource resolves
- enable health_check extension so collector liveness probes pass on Kubernetes
- render audit bar charts as one bar per category instead of timestamp series
- align dashboards with OTel counter metric names and add collector health dashboard

### Documentation

- Update documentation

### Routine

- bootstrap claude-code-telemetry (local testbed + self-contained Helm bundle)


[Unreleased]: https://github.com/KubeRocketCI/claude-code-telemetry/compare/v0.1.0...HEAD
