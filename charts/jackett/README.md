# jackett

![Version: 0.1.6](https://img.shields.io/badge/Version-0.1.6-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

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
| jackett.PGID | string | `"1001"` |  |
| jackett.PUID | string | `"1001"` |  |
| jackett.autoUpdate | string | `"true"` |  |
| jackett.persistence.config.existingVolume | string | `""` |  |
| jackett.persistence.config.matchExpressions | object | `{}` |  |
| jackett.persistence.config.matchLabels | object | `{}` |  |
| jackett.persistence.config.size | string | `"1Gi"` |  |
| jackett.persistence.config.storageClassName | string | `""` |  |
| jackett.persistence.config.useExistingPvc | string | `""` |  |
| jackett.persistence.downloads.enabled | bool | `false` |  |
| jackett.persistence.downloads.existingVolume | string | `""` |  |
| jackett.persistence.downloads.matchExpressions | object | `{}` |  |
| jackett.persistence.downloads.matchLabels | object | `{}` |  |
| jackett.persistence.downloads.size | string | `"1Gi"` |  |
| jackett.persistence.downloads.storageClassName | string | `""` |  |
| jackett.persistence.downloads.useExistingPvc | string | `""` |  |
| jackett.runOpts | string | `""` |  |
| jackett.timezone | string | `"Etc/UTC"` |  |
| nameOverride | string | `"jackett"` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.port | int | `9117` |  |
| service.type | string | `"ClusterIP"` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.13.1](https://github.com/norwoodj/helm-docs/releases/v1.13.1)