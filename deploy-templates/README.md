# claude-code-telemetry

![Version: 0.1.0-SNAPSHOT](https://img.shields.io/badge/Version-0.1.0--SNAPSHOT-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0-SNAPSHOT](https://img.shields.io/badge/AppVersion-0.1.0--SNAPSHOT-informational?style=flat-square)

Claude Code usage-audit telemetry — self-contained bundle of OTel Collector, Prometheus, Loki, and Grafana with usage dashboards

**Homepage:** <https://docs.kuberocketci.io/>

## Overview

A self-contained telemetry bundle for [Claude Code](https://code.claude.com) usage analytics:
an OpenTelemetry Collector receives OTLP from Claude Code sessions and fans metrics out to a
bundled Prometheus and events/logs to a bundled Loki, with Grafana dashboards provisioned on top.

The bundle is deliberately isolated: Prometheus scrapes exactly two static targets (the collector's
Claude Code data metrics and its self-telemetry), all cluster-wide discovery and cluster-monitoring
extras are disabled, and RBAC is namespace-scoped. It brings no operator or CRD dependencies.

## Prerequisites

1. Linux machine or Windows Subsystem for Linux instance with [Helm 3](https://helm.sh/docs/intro/install/) installed;
2. Access to a Kubernetes cluster with permissions to create a namespace.

## Installation Using Helm Chart

To install the bundle, follow the steps below:

1. Pull the subchart dependencies:

    ```bash
    helm dependency update deploy-templates
    ```

2. Install the bundle into its own namespace:

    ```bash
    helm install claude-code-telemetry deploy-templates \
      --namespace claude-code-telemetry --create-namespace
    ```

3. Check the `claude-code-telemetry` namespace: the `otel-collector`, `prometheus-server`,
   `loki` and `grafana` workloads should reach the ready state.

## Quick Start

1. Expose the collector's OTLP endpoint to clients — either enable one of the ingresses
   (`ingress.grpc` / `ingress.http`) or port-forward for a quick check:

    ```bash
    kubectl -n claude-code-telemetry port-forward svc/otel-collector 4318:4318
    ```

2. Point Claude Code at the collector by merging the telemetry `env` block into
   `~/.claude/settings.json` (see `local/claude-settings.snippet.json` in the repository)
   with `OTEL_EXPORTER_OTLP_ENDPOINT` set to the endpoint above, then restart Claude Code.

3. Open Grafana and log in with the generated admin password:

    ```bash
    kubectl -n claude-code-telemetry port-forward svc/grafana 3000:80
    kubectl -n claude-code-telemetry get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d
    ```

    Dashboards are auto-provisioned by the sidecar into the `Claude Code`, `Governance` and
    `Operational` folders.

## Local Development

The collector pipeline and dashboards are iterated on in the repository's `local/` docker-compose
stack first, then replicated into this chart (`values.yaml` → `opentelemetry-collector.alternateConfig`
and `config/grafana/dashboards/`). See the repository root `README.md` for the full workflow.

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| epmd-edp | <SupportEPMD-EDP@epam.com> | <https://solutionshub.epam.com/solution/kuberocketci> |

## Source Code

* <https://github.com/KubeRocketCI/claude-code-telemetry>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.external-secrets.io/ | external-secrets | 2.7.0 |
| https://grafana.github.io/helm-charts | grafana | 10.5.15 |
| https://grafana.github.io/helm-charts | loki | 7.0.0 |
| https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-collector | 0.164.1 |
| https://prometheus-community.github.io/helm-charts | prometheus | 29.14.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| dashboards.annotations | object | `{}` |  |
| dashboards.enabled | bool | `true` |  |
| dashboards.folderAnnotation | string | `"grafana_folder"` |  |
| dashboards.folders.claude-code | string | `"Claude Code"` |  |
| dashboards.folders.governance | string | `"Governance"` |  |
| dashboards.folders.operational | string | `"Operational"` |  |
| dashboards.label | string | `"grafana_dashboard"` |  |
| dashboards.labelValue | string | `"1"` |  |
| eso.apiVersion | string | `"external-secrets.io/v1"` | API version for the SecretStore/ExternalSecret resources. Match the CRD version served by the ESO controller in the target cluster (`external-secrets.io/v1` for ESO >= 0.10, or `external-secrets.io/v1beta1` for older installs). |
| eso.aws | object | `{"region":"eu-central-1","roleArn":"arn:aws:iam::012345678910:role/AWSIRSA_Shared_ExternalSecretOperatorAccess"}` | AWS configuration (if provider is `aws`). |
| eso.aws.region | string | `"eu-central-1"` | AWS region. |
| eso.aws.roleArn | string | `"arn:aws:iam::012345678910:role/AWSIRSA_Shared_ExternalSecretOperatorAccess"` | AWS role ARN for the ExternalSecretOperator to assume. |
| eso.enabled | bool | `false` | Render the SecretStore/ExternalSecret resources. |
| eso.generic.secretStore.providerConfig | object | `{}` | Defines SecretStore provider configuration. |
| eso.provider | string | `"generic"` | Defines provider type. One of `aws`, `generic`, or `vault`. |
| eso.secretPath | string | `"/infra/claude-code-telemetry"` | Defines the path to the secret in the provider. If provider is `vault`, the path must be prefixed with `secret/`. |
| eso.vault | object | `{"mountPath":"core","role":"claude-code-telemetry","server":"http://vault.vault:8200"}` | Vault configuration (if provider is `vault`). |
| eso.vault.mountPath | string | `"core"` | Mount path for the Kubernetes authentication method. |
| eso.vault.role | string | `"claude-code-telemetry"` | Vault role for the Kubernetes authentication method. |
| eso.vault.server | string | `"http://vault.vault:8200"` | Vault server URL. |
| external-secrets.enabled | bool | `false` |  |
| external-secrets.installCRDs | bool | `true` |  |
| external-secrets.scopedNamespace | string | `"claude-code-telemetry"` |  |
| external-secrets.scopedRBAC | bool | `true` |  |
| fullnameOverride | string | `"claude-code-telemetry"` |  |
| grafana."grafana.ini"."auth.generic_oauth".allow_sign_up | bool | `true` |  |
| grafana."grafana.ini"."auth.generic_oauth".api_url | string | `"https://keycloak.example.com/realms/main/protocol/openid-connect/userinfo"` |  |
| grafana."grafana.ini"."auth.generic_oauth".auth_url | string | `"https://keycloak.example.com/realms/main/protocol/openid-connect/auth"` |  |
| grafana."grafana.ini"."auth.generic_oauth".auto_login | bool | `false` |  |
| grafana."grafana.ini"."auth.generic_oauth".client_id | string | `"grafana-claude-code-telemetry"` |  |
| grafana."grafana.ini"."auth.generic_oauth".email_attribute_path | string | `"email"` |  |
| grafana."grafana.ini"."auth.generic_oauth".enabled | bool | `false` |  |
| grafana."grafana.ini"."auth.generic_oauth".groups_attribute_path | string | `"groups"` |  |
| grafana."grafana.ini"."auth.generic_oauth".name | string | `"SSO"` |  |
| grafana."grafana.ini"."auth.generic_oauth".role_attribute_path | string | `"contains(roles[*], 'administrator') && 'Admin' || contains(roles[*], 'developer') && 'Editor' || 'Viewer'"` |  |
| grafana."grafana.ini"."auth.generic_oauth".scopes | string | `"openid profile email roles groups"` |  |
| grafana."grafana.ini"."auth.generic_oauth".token_url | string | `"https://keycloak.example.com/realms/main/protocol/openid-connect/token"` |  |
| grafana."grafana.ini".analytics.check_for_updates | bool | `false` |  |
| grafana."grafana.ini".server.root_url | string | `"https://grafana.example.com"` |  |
| grafana.datasources."datasources.yaml".apiVersion | int | `1` |  |
| grafana.datasources."datasources.yaml".datasources[0].access | string | `"proxy"` |  |
| grafana.datasources."datasources.yaml".datasources[0].isDefault | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[0].name | string | `"Prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].uid | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://prometheus-server"` |  |
| grafana.datasources."datasources.yaml".datasources[1].access | string | `"proxy"` |  |
| grafana.datasources."datasources.yaml".datasources[1].name | string | `"Loki"` |  |
| grafana.datasources."datasources.yaml".datasources[1].type | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[1].uid | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[1].url | string | `"http://loki:3100"` |  |
| grafana.enabled | bool | `true` |  |
| grafana.fullnameOverride | string | `"grafana"` |  |
| grafana.ingress.annotations | object | `{}` |  |
| grafana.ingress.enabled | bool | `false` |  |
| grafana.ingress.hosts[0] | string | `"grafana.example.com"` |  |
| grafana.ingress.path | string | `"/"` |  |
| grafana.ingress.pathType | string | `"Prefix"` |  |
| grafana.ingress.tls | list | `[]` |  |
| grafana.rbac.namespaced | bool | `true` |  |
| grafana.sidecar.dashboards.enabled | bool | `true` |  |
| grafana.sidecar.dashboards.folderAnnotation | string | `"grafana_folder"` |  |
| grafana.sidecar.dashboards.label | string | `"grafana_dashboard"` |  |
| grafana.sidecar.dashboards.labelValue | string | `"1"` |  |
| grafana.sidecar.dashboards.provider.foldersFromFilesStructure | bool | `true` |  |
| grafana.testFramework.enabled | bool | `false` |  |
| ingress.grpc.annotations."nginx.ingress.kubernetes.io/backend-protocol" | string | `"GRPC"` |  |
| ingress.grpc.enabled | bool | `false` |  |
| ingress.grpc.host | string | `"otel.example.com"` |  |
| ingress.grpc.tls | list | `[]` |  |
| ingress.http.annotations | object | `{}` |  |
| ingress.http.enabled | bool | `false` |  |
| ingress.http.host | string | `"otel-http.example.com"` |  |
| ingress.http.tls | list | `[]` |  |
| keycloakClient.clientId | string | `"grafana"` | OAuth client ID; keep in sync with grafana.grafana\.ini.auth\.generic_oauth.client_id. |
| keycloakClient.create | bool | `false` | Render a KeycloakClient CR for Grafana SSO via the KubeRocketCI keycloak-operator. |
| keycloakClient.grafanaUrl | string | `"https://grafana.example.com"` | Grafana external URL (OAuth redirect base); keep in sync with grafana ingress host and server.root_url. |
| keycloakClient.realmRef | object | `{"kind":"ClusterKeycloakRealm","name":"main"}` | Keycloak realm the client is created in. |
| loki.backend.replicas | int | `0` |  |
| loki.chunksCache.enabled | bool | `false` |  |
| loki.deploymentMode | string | `"SingleBinary"` |  |
| loki.enabled | bool | `true` |  |
| loki.fullnameOverride | string | `"loki"` |  |
| loki.gateway.enabled | bool | `false` |  |
| loki.loki.auth_enabled | bool | `false` |  |
| loki.loki.commonConfig.replication_factor | int | `1` |  |
| loki.loki.limits_config.allow_structured_metadata | bool | `true` |  |
| loki.loki.limits_config.retention_period | string | `"720h"` |  |
| loki.loki.schemaConfig.configs[0].from | string | `"2024-04-01"` |  |
| loki.loki.schemaConfig.configs[0].index.period | string | `"24h"` |  |
| loki.loki.schemaConfig.configs[0].index.prefix | string | `"loki_index_"` |  |
| loki.loki.schemaConfig.configs[0].object_store | string | `"filesystem"` |  |
| loki.loki.schemaConfig.configs[0].schema | string | `"v13"` |  |
| loki.loki.schemaConfig.configs[0].store | string | `"tsdb"` |  |
| loki.loki.storage.type | string | `"filesystem"` |  |
| loki.lokiCanary.enabled | bool | `false` |  |
| loki.monitoring.selfMonitoring.enabled | bool | `false` |  |
| loki.monitoring.selfMonitoring.grafanaAgent.installOperator | bool | `false` |  |
| loki.rbac.namespaced | bool | `true` |  |
| loki.read.replicas | int | `0` |  |
| loki.resultsCache.enabled | bool | `false` |  |
| loki.singleBinary.persistence.enabled | bool | `true` |  |
| loki.singleBinary.persistence.size | string | `"10Gi"` |  |
| loki.singleBinary.replicas | int | `1` |  |
| loki.test.enabled | bool | `false` |  |
| loki.write.replicas | int | `0` |  |
| nameOverride | string | `""` |  |
| opentelemetry-collector.alternateConfig.exporters.debug.verbosity | string | `"${env:DEBUG_VERBOSITY:-basic}"` |  |
| opentelemetry-collector.alternateConfig.exporters.otlphttp/loki.endpoint | string | `"${env:LOKI_ENDPOINT:-http://loki:3100/otlp}"` |  |
| opentelemetry-collector.alternateConfig.exporters.prometheus.endpoint | string | `"0.0.0.0:8889"` |  |
| opentelemetry-collector.alternateConfig.exporters.prometheus.resource_to_telemetry_conversion.enabled | bool | `true` |  |
| opentelemetry-collector.alternateConfig.extensions.health_check.endpoint | string | `"0.0.0.0:13133"` |  |
| opentelemetry-collector.alternateConfig.processors.batch.timeout | string | `"5s"` |  |
| opentelemetry-collector.alternateConfig.processors.resource.attributes[0].action | string | `"upsert"` |  |
| opentelemetry-collector.alternateConfig.processors.resource.attributes[0].key | string | `"collector.env"` |  |
| opentelemetry-collector.alternateConfig.processors.resource.attributes[0].value | string | `"${env:COLLECTOR_ENV:-k8s}"` |  |
| opentelemetry-collector.alternateConfig.receivers.otlp.protocols.grpc.endpoint | string | `"0.0.0.0:4317"` |  |
| opentelemetry-collector.alternateConfig.receivers.otlp.protocols.http.endpoint | string | `"0.0.0.0:4318"` |  |
| opentelemetry-collector.alternateConfig.service.extensions[0] | string | `"health_check"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.logs.exporters[0] | string | `"otlphttp/loki"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.logs.exporters[1] | string | `"debug"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.logs.processors[0] | string | `"resource"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.logs.processors[1] | string | `"batch"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.logs.receivers[0] | string | `"otlp"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.metrics.exporters[0] | string | `"prometheus"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.metrics.exporters[1] | string | `"debug"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.metrics.processors[0] | string | `"resource"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.metrics.processors[1] | string | `"batch"` |  |
| opentelemetry-collector.alternateConfig.service.pipelines.metrics.receivers[0] | string | `"otlp"` |  |
| opentelemetry-collector.alternateConfig.service.telemetry.logs.level | string | `"info"` |  |
| opentelemetry-collector.alternateConfig.service.telemetry.metrics.level | string | `"detailed"` |  |
| opentelemetry-collector.alternateConfig.service.telemetry.metrics.readers[0].pull.exporter.prometheus.host | string | `"0.0.0.0"` |  |
| opentelemetry-collector.alternateConfig.service.telemetry.metrics.readers[0].pull.exporter.prometheus.port | int | `8888` |  |
| opentelemetry-collector.enabled | bool | `true` |  |
| opentelemetry-collector.fullnameOverride | string | `"otel-collector"` |  |
| opentelemetry-collector.image.repository | string | `"otel/opentelemetry-collector-contrib"` |  |
| opentelemetry-collector.image.tag | string | `"0.156.0"` |  |
| opentelemetry-collector.mode | string | `"deployment"` |  |
| opentelemetry-collector.ports.jaeger-compact.enabled | bool | `false` |  |
| opentelemetry-collector.ports.jaeger-grpc.enabled | bool | `false` |  |
| opentelemetry-collector.ports.jaeger-thrift.enabled | bool | `false` |  |
| opentelemetry-collector.ports.metrics.containerPort | int | `8888` |  |
| opentelemetry-collector.ports.metrics.enabled | bool | `true` |  |
| opentelemetry-collector.ports.metrics.protocol | string | `"TCP"` |  |
| opentelemetry-collector.ports.metrics.servicePort | int | `8888` |  |
| opentelemetry-collector.ports.promexporter.containerPort | int | `8889` |  |
| opentelemetry-collector.ports.promexporter.enabled | bool | `true` |  |
| opentelemetry-collector.ports.promexporter.protocol | string | `"TCP"` |  |
| opentelemetry-collector.ports.promexporter.servicePort | int | `8889` |  |
| opentelemetry-collector.ports.zipkin.enabled | bool | `false` |  |
| opentelemetry-collector.replicaCount | int | `1` |  |
| opentelemetry-collector.resources.limits.memory | string | `"512Mi"` |  |
| opentelemetry-collector.resources.requests.cpu | string | `"50m"` |  |
| opentelemetry-collector.resources.requests.memory | string | `"128Mi"` |  |
| prometheus.alertmanager.enabled | bool | `false` |  |
| prometheus.enabled | bool | `true` |  |
| prometheus.fullnameOverride | string | `"prometheus"` |  |
| prometheus.kube-state-metrics.enabled | bool | `false` |  |
| prometheus.prometheus-node-exporter.enabled | bool | `false` |  |
| prometheus.prometheus-pushgateway.enabled | bool | `false` |  |
| prometheus.rbac.create | bool | `false` |  |
| prometheus.scrapeConfigs.claude-code.enabled | bool | `true` |  |
| prometheus.scrapeConfigs.claude-code.honor_labels | bool | `true` |  |
| prometheus.scrapeConfigs.claude-code.static_configs[0].targets[0] | string | `"otel-collector:8889"` |  |
| prometheus.scrapeConfigs.kubernetes-api-servers.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-nodes-cadvisor.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-nodes.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-pods-slow.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-pods.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-service-endpoints-slow.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-service-endpoints.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.kubernetes-services.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.otel-collector.enabled | bool | `true` |  |
| prometheus.scrapeConfigs.otel-collector.static_configs[0].targets[0] | string | `"otel-collector:8888"` |  |
| prometheus.scrapeConfigs.prometheus-pushgateway.enabled | bool | `false` |  |
| prometheus.scrapeConfigs.prometheus.enabled | bool | `false` |  |
| prometheus.server.fullnameOverride | string | `"prometheus-server"` |  |
| prometheus.server.persistentVolume.enabled | bool | `true` |  |
| prometheus.server.persistentVolume.size | string | `"20Gi"` |  |
| prometheus.server.retention | string | `"365d"` |  |
