# influxdb3-core

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.9.3](https://img.shields.io/badge/AppVersion-3.9.3-informational?style=flat-square)

A Helm chart for deploying InfluxDB 3 Core on Kubernetes

[InfluxDB 3 Core](https://docs.influxdata.com/influxdb3/core/) is the open source release of InfluxDB 3 — a single-node time series database that persists data as Parquet files in an object store (local filesystem, S3, Azure Blob Storage, or Google Cloud Storage).

This chart deploys InfluxDB 3 Core as a single-replica StatefulSet. For the distributed, multi-component version see the [influxdb3-enterprise](https://github.com/influxdata/helm-charts/tree/master/charts/influxdb3-enterprise) chart.

**Homepage:** <https://www.influxdata.com/products/influxdb/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| NigelVanHattum |  |  |

## Source Code

* <https://github.com/influxdata/influxdb>
* <https://docs.influxdata.com/influxdb3/core/>

## Installing

```sh
helm install influxdb3-core ./charts/influxdb3-core
```

By default data is stored on a PersistentVolumeClaim using the cluster's default StorageClass.

### Using S3 (or S3-compatible) object storage

```yaml
objectStorage:
  type: s3
  bucket: my-influxdb-bucket
  s3:
    region: us-east-1
    endpoint: ""                # set for MinIO etc., empty for AWS
    accessKeyId: my-key
    secretAccessKey: my-secret
    # or reference an existing secret with keys access-key-id / secret-access-key:
    # existingSecret: my-s3-secret
```

### Authentication

Authentication is enabled by default (the `/health` endpoint is exempted so Kubernetes probes work). Create an admin token after install:

```sh
kubectl exec -it <release-name>-influxdb3-core-0 -- influxdb3 create token --admin
```

Alternatively, provide an offline-generated admin token via `security.auth.adminToken.existingSecret` (secret key `admin-token.json`).

### Processing engine

The embedded Python processing engine can be enabled with `processingEngine.enabled: true`. Plugins are stored on a dedicated PersistentVolumeClaim and can be pre-installed via `processingEngine.initPlugins`.

Note: enabling the processing engine after the initial install adds a volumeClaimTemplate to the StatefulSet, which requires recreating it first:

```sh
kubectl delete statefulset <release-name>-influxdb3-core --cascade=orphan
```

### Web UI (InfluxDB 3 Explorer)

Core has no built-in UI. Enable the optional [InfluxDB 3 Explorer](https://docs.influxdata.com/influxdb3/explorer/) web app with `explorer.enabled: true`. It is deployed as its own single-replica StatefulSet (image `influxdata/influxdb3-ui`) with its own Service and optional Ingress, and is pre-wired to the in-cluster Core server.

Provide the API token Explorer uses to reach Core via `explorer.connection.token` (inline) or `explorer.connection.existingSecret` (a secret holding the raw `apiv3_...` token):

```yaml
explorer:
  enabled: true
  mode: admin                 # or "query" for read-only
  connection:
    enabled: true
    database: mydb
    existingSecret: influxdb-explorer-token   # key: token
  ingress:
    enabled: true
    className: nginx
    host: influxdb-explorer.example.com
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| annotations | object | `{}` | Annotations for the StatefulSet object itself (controller metadata, not the pods). Use for controllers that watch the workload object, e.g. the 1Password operator's operator.1password.io/item-path and item-name annotations. |
| caching | string | `nil` |  |
| explorer.affinity | object | `{}` |  |
| explorer.annotations | object | `{}` | Annotations for the Explorer StatefulSet object itself (controller metadata, not the pods), e.g. 1Password operator item-path/item-name. |
| explorer.connection.database | string | `""` | Default database to open (optional) |
| explorer.connection.enabled | bool | `true` |  |
| explorer.connection.existingSecret | string | `""` | Existing secret holding the raw API token (takes precedence over token) |
| explorer.connection.existingSecretKey | string | `"token"` |  |
| explorer.connection.server | string | `""` | Core server URL. Defaults to the in-cluster Core service when empty. |
| explorer.connection.serverName | string | `"InfluxDB 3 Core"` | Display name for the server in Explorer |
| explorer.connection.token | string | `""` |  |
| explorer.enabled | bool | `false` |  |
| explorer.image.pullPolicy | string | `"IfNotPresent"` |  |
| explorer.image.registry | string | `"docker.io"` |  |
| explorer.image.repository | string | `"influxdata/influxdb3-ui"` |  |
| explorer.image.tag | string | `"1.8.0"` | Explorer image tag. Pin a version; see https://hub.docker.com/r/influxdata/influxdb3-ui/tags |
| explorer.ingress.annotations | object | `{}` |  |
| explorer.ingress.className | string | `""` |  |
| explorer.ingress.enabled | bool | `false` |  |
| explorer.ingress.host | string | `"influxdb-explorer.example.com"` |  |
| explorer.ingress.tls | list | `[]` |  |
| explorer.mode | string | `"admin"` | UI mode: "admin" (full management) or "query" (read-only) |
| explorer.nodeSelector | object | `{}` |  |
| explorer.persistence.accessMode | string | `"ReadWriteOnce"` |  |
| explorer.persistence.enabled | bool | `true` |  |
| explorer.persistence.size | string | `"1Gi"` |  |
| explorer.persistence.storageClass | string | `""` |  |
| explorer.persistence.volumeName | string | `""` | Bind the PVC to a specific PersistentVolume (e.g. a pre-created static PV) |
| explorer.podAnnotations | object | `{}` |  |
| explorer.podLabels | object | `{}` |  |
| explorer.podSecurityContext | object | `{}` |  |
| explorer.priorityClassName | string | `""` |  |
| explorer.resources | object | `{}` |  |
| explorer.securityContext | object | `{}` |  |
| explorer.service.annotations | object | `{}` |  |
| explorer.service.port | int | `8080` |  |
| explorer.service.type | string | `"ClusterIP"` |  |
| explorer.sessionSecret.existingSecret | string | `""` |  |
| explorer.sessionSecret.existingSecretKey | string | `"session-secret"` |  |
| explorer.sessionSecret.value | string | `""` |  |
| explorer.tolerations | list | `[]` |  |
| extraEnv | list | `[]` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| http | string | `nil` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.registry | string | `"docker.io"` |  |
| image.repository | string | `"influxdb"` |  |
| image.tag | string | `""` | Optional explicit tag override. If empty, defaults to "<appVersion>-core". |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.host | string | `"influxdb.example.com"` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` |  |
| networkPolicy.egress.dns.namespace | string | `"kube-system"` |  |
| networkPolicy.egress.dns.namespaceLabel | string | `"kubernetes.io/metadata.name"` |  |
| networkPolicy.egress.dns.podLabelKey | string | `"k8s-app"` |  |
| networkPolicy.egress.dns.podLabelValue | string | `"kube-dns"` |  |
| networkPolicy.egress.objectStorageCidrs | list | `[]` |  |
| networkPolicy.egress.pluginEndpointCidrs | list | `[]` |  |
| networkPolicy.egress.toDns | bool | `true` |  |
| networkPolicy.egress.toObjectStorage | bool | `true` |  |
| networkPolicy.egress.toPluginEndpoints | bool | `true` |  |
| networkPolicy.enabled | bool | `false` |  |
| networkPolicy.ingress.fromIngressController | bool | `true` |  |
| networkPolicy.ingress.fromPrometheus | bool | `false` |  |
| networkPolicy.ingress.ingressController.namespace | string | `"ingress-nginx"` |  |
| networkPolicy.ingress.ingressController.namespaceLabel | string | `"kubernetes.io/metadata.name"` |  |
| networkPolicy.ingress.ingressController.podLabelKey | string | `"app.kubernetes.io/name"` |  |
| networkPolicy.ingress.ingressController.podLabelValue | string | `"ingress-nginx"` |  |
| networkPolicy.ingress.prometheus.namespace | string | `"monitoring"` |  |
| networkPolicy.ingress.prometheus.namespaceLabel | string | `"kubernetes.io/metadata.name"` |  |
| networkPolicy.ingress.prometheus.podLabelKey | string | `"app.kubernetes.io/name"` |  |
| networkPolicy.ingress.prometheus.podLabelValue | string | `"prometheus"` |  |
| networkPolicy.policyTypes[0] | string | `"Ingress"` |  |
| networkPolicy.policyTypes[1] | string | `"Egress"` |  |
| node.id | string | `""` | Node identifier, must be unique among hosts sharing the same object store. If empty, the pod hostname is used (stable for a StatefulSet). |
| nodeSelector | object | `{}` |  |
| objectStorage.azure.accessKey | string | `""` |  |
| objectStorage.azure.allowHttp | bool | `false` |  |
| objectStorage.azure.endpoint | string | `""` |  |
| objectStorage.azure.existingSecret | string | `""` |  |
| objectStorage.azure.storageAccount | string | `""` |  |
| objectStorage.bucket | string | `"influxdb3-core-data"` | Bucket/container name for storing data (s3, azure, google) |
| objectStorage.file.dataDir | string | `"/var/lib/influxdb3"` |  |
| objectStorage.file.persistence.accessMode | string | `"ReadWriteOnce"` |  |
| objectStorage.file.persistence.enabled | bool | `true` | Create a PVC for the data directory. When disabled, an emptyDir is used and all data is lost when the pod restarts. |
| objectStorage.file.persistence.size | string | `"50Gi"` |  |
| objectStorage.file.persistence.storageClass | string | `""` |  |
| objectStorage.file.persistence.volumeName | string | `""` | Bind the data PVC to a specific PersistentVolume (e.g. a pre-created static PV) |
| objectStorage.google.existingSecret | string | `""` |  |
| objectStorage.google.serviceAccountJson | string | `""` |  |
| objectStorage.s3.accessKeyId | string | `""` |  |
| objectStorage.s3.credentialsFile | string | `""` |  |
| objectStorage.s3.endpoint | string | `""` |  |
| objectStorage.s3.existingSecret | string | `""` |  |
| objectStorage.s3.region | string | `"us-east-1"` |  |
| objectStorage.s3.secretAccessKey | string | `""` |  |
| objectStorage.s3.sessionToken | string | `""` |  |
| objectStorage.type | string | `"file"` | Object store type: file, s3, azure, google, memory, memory-throttled |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.fsGroup | int | `1500` |  |
| podSecurityContext.runAsGroup | int | `1500` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `1500` |  |
| priorityClassName | string | `""` |  |
| probes.enabled | bool | `true` |  |
| probes.liveness.failureThreshold | int | `3` |  |
| probes.liveness.initialDelaySeconds | int | `0` |  |
| probes.liveness.periodSeconds | int | `10` |  |
| probes.liveness.timeoutSeconds | int | `5` |  |
| probes.readiness.failureThreshold | int | `3` |  |
| probes.readiness.initialDelaySeconds | int | `0` |  |
| probes.readiness.periodSeconds | int | `5` |  |
| probes.readiness.timeoutSeconds | int | `3` |  |
| probes.startup.failureThreshold | int | `12` |  |
| probes.startup.initialDelaySeconds | int | `10` |  |
| probes.startup.periodSeconds | int | `5` |  |
| probes.startup.timeoutSeconds | int | `5` |  |
| processingEngine.enabled | bool | `false` |  |
| processingEngine.initPlugins | list | `[]` |  |
| processingEngine.persistence.accessMode | string | `"ReadWriteOnce"` |  |
| processingEngine.persistence.enabled | bool | `true` |  |
| processingEngine.persistence.size | string | `"5Gi"` |  |
| processingEngine.persistence.storageClass | string | `""` |  |
| processingEngine.pluginDir | string | `"/plugins"` | Local directory that contains Python plugins and their test files (--plugin-dir) |
| resources | object | `{}` |  |
| security.auth.adminToken.existingSecret | string | `""` |  |
| security.auth.adminToken.file | string | `""` |  |
| security.auth.disableAuthz[0] | string | `"health"` |  |
| security.auth.disabled | bool | `false` |  |
| security.tls.cert | string | `""` |  |
| security.tls.certPath | string | `"/etc/influxdb/tls/tls.crt"` |  |
| security.tls.enabled | bool | `false` |  |
| security.tls.existingSecret | string | `""` |  |
| security.tls.key | string | `""` |  |
| security.tls.keyPath | string | `"/etc/influxdb/tls/tls.key"` |  |
| security.tls.minVersion | string | `"tls-1.2"` |  |
| securityContext | object | `{}` |  |
| service.annotations | object | `{}` |  |
| service.port | int | `8181` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| serviceMonitor.additionalLabels | object | `{}` |  |
| serviceMonitor.enabled | bool | `false` |  |
| serviceMonitor.interval | string | `"30s"` |  |
| serviceMonitor.namespace | string | `""` |  |
| serviceMonitor.scrapeTimeout | string | `"10s"` |  |
| tolerations | list | `[]` |  |
| updateStrategy.type | string | `"RollingUpdate"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
