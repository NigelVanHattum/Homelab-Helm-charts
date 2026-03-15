# paperless-ngx

![Version: 1.1.2](https://img.shields.io/badge/Version-1.1.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.20.10](https://img.shields.io/badge/AppVersion-2.20.10-informational?style=flat-square)

A Helm chart for Paperless-ngx - A community-supported open-source document management system

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://apache.jfrog.io/artifactory/tika | tika | 3.2.2 |
| https://maikumori.github.io/helm-charts | gotenberg | 1.18.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| fullnameOverride | string | `""` |  |
| httpRoute | object | `{"annotations":{},"enabled":false,"hostnames":["chart-example.local"],"parentRefs":[{"name":"gateway","sectionName":"http"}],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]}` | Expose the service via gateway-api HTTPRoute Requires Gateway API resources and suitable controller installed within the cluster (see: https://gateway-api.sigs.k8s.io/guides/) |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/paperless-ngx/paperless-ngx"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.httpGet.path | string | `"/"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| paperless.authentik.allowSignups | bool | `true` |  |
| paperless.authentik.applicationSlug | string | `""` |  |
| paperless.authentik.autoSignup | bool | `true` |  |
| paperless.authentik.clientId | string | `""` |  |
| paperless.authentik.clientSecret | string | `""` |  |
| paperless.authentik.domain | string | `""` |  |
| paperless.authentik.enabled | bool | `false` |  |
| paperless.database.enabled | bool | `false` |  |
| paperless.database.host | string | `""` |  |
| paperless.database.name | string | `"paperless"` |  |
| paperless.database.password | string | `""` |  |
| paperless.database.port | int | `5432` |  |
| paperless.database.user | string | `"paperless"` |  |
| paperless.env.PAPERLESS_ADMIN_PASSWORD | string | `""` |  |
| paperless.env.PAPERLESS_ADMIN_USER | string | `"admin"` |  |
| paperless.env.PAPERLESS_OCR_LANGUAGE | string | `"eng"` |  |
| paperless.env.PAPERLESS_SECRET_KEY | string | `""` |  |
| paperless.env.PAPERLESS_TIME_ZONE | string | `"UTC"` |  |
| paperless.env.PAPERLESS_URL | string | `""` |  |
| paperless.extraEnv | list | `[]` |  |
| paperless.gotenberg.enabled | bool | `true` |  |
| paperless.gotenberg.url | string | `""` |  |
| paperless.persistence.consume.enabled | bool | `true` |  |
| paperless.persistence.consume.existingVolume | string | `""` |  |
| paperless.persistence.consume.matchExpressions | object | `{}` |  |
| paperless.persistence.consume.matchLabels | object | `{}` |  |
| paperless.persistence.consume.size | string | `"10Gi"` |  |
| paperless.persistence.consume.storageClass | string | `""` |  |
| paperless.persistence.consume.useExistingPvc | string | `""` |  |
| paperless.persistence.data.enabled | bool | `true` |  |
| paperless.persistence.data.existingVolume | string | `""` |  |
| paperless.persistence.data.matchExpressions | object | `{}` |  |
| paperless.persistence.data.matchLabels | object | `{}` |  |
| paperless.persistence.data.size | string | `"10Gi"` |  |
| paperless.persistence.data.storageClass | string | `""` |  |
| paperless.persistence.data.useExistingPvc | string | `""` |  |
| paperless.persistence.media.enabled | bool | `true` |  |
| paperless.persistence.media.existingVolume | string | `""` |  |
| paperless.persistence.media.matchExpressions | object | `{}` |  |
| paperless.persistence.media.matchLabels | object | `{}` |  |
| paperless.persistence.media.size | string | `"50Gi"` |  |
| paperless.persistence.media.storageClass | string | `""` |  |
| paperless.persistence.media.useExistingPvc | string | `""` |  |
| paperless.tika.enabled | bool | `true` |  |
| paperless.tika.url | string | `""` |  |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| readinessProbe.httpGet.path | string | `"/"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.port | int | `8000` |  |
| service.type | string | `"ClusterIP"` |  |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
