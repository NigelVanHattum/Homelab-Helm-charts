# sonarr

![Version: 0.1.2](https://img.shields.io/badge/Version-0.1.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

A Helm chart for Kubernetes

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.tag | string | `"latest"` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `"sonarr"` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.port | int | `8989` |  |
| service.type | string | `"ClusterIP"` |  |
| sonarr.PGID | string | `"1001"` |  |
| sonarr.PUID | string | `"1001"` |  |
| sonarr.persistence.config.existingVolume | string | `""` |  |
| sonarr.persistence.config.matchExpressions | object | `{}` |  |
| sonarr.persistence.config.matchLabels | object | `{}` |  |
| sonarr.persistence.config.size | string | `"1Gi"` |  |
| sonarr.persistence.config.storageClassName | string | `""` |  |
| sonarr.persistence.config.useExistingPvc | string | `""` |  |
| sonarr.persistence.extraVolumes | list | `[]` |  |
| sonarr.timezone | string | `"Etc/UTC"` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.13.1](https://github.com/norwoodj/helm-docs/releases/v1.13.1)
