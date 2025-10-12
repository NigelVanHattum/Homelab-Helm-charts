# kasm-single-zone

![Version: 1.17.0-develop](https://img.shields.io/badge/Version-1.17.0--develop-informational?style=flat-square) ![AppVersion: 1.17.0](https://img.shields.io/badge/AppVersion-1.17.0-informational?style=flat-square)

Kasm is a platform specializing in providing secure browser-based workspaces for a wide range of applications and industries. Its main goal is to provide isolated and secure environments that can be accessed via web browsers, ensuring that users can perform tasks without risking the security of their local systems.

**Homepage:** <https://kasmweb.com>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Kasm Technologies, Inc. |  | <https://github.com/kasmtech/kasm-helm> |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.altHostnames | list | `[]` |  |
| global.clusterDomain | string | `"cluster.local"` |  |
| global.hostname | string | `""` |  |
| global.image.pullCredentials | object | `{}` |  |
| global.image.pullPolicy | string | `"IfNotPresent"` |  |
| global.image.pullSecrets | string | `""` |  |
| global.image.restartPolicy | string | `"Always"` |  |
| global.ingressClassName | string | `""` |  |
| global.kasmPasswords.adminPassword | string | `""` |  |
| global.kasmPasswords.dbPassword | string | `""` |  |
| global.kasmPasswords.managerToken | string | `""` |  |
| global.kasmPasswords.redisPassword | string | `""` |  |
| global.kasmPasswords.serviceToken | string | `""` |  |
| global.kasmPasswords.userPassword | string | `""` |  |
| global.namespace | string | `""` |  |
| kasmApp.applyHardening | bool | `true` |  |
| kasmApp.deploymentSize | string | `"small"` |  |
| kasmApp.name | string | `"kasm"` |  |
| kasmApp.servicesToDeploy.db.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.db.image | string | `"kasmweb/postgres"` |  |
| kasmApp.servicesToDeploy.db.name | string | `"kasm-db"` |  |
| kasmApp.servicesToDeploy.db.persistentVolumeClaimRetentionPolicy.enabled | bool | `false` |  |
| kasmApp.servicesToDeploy.db.persistentVolumeClaimRetentionPolicy.whenDeleted | string | `"Retain"` |  |
| kasmApp.servicesToDeploy.db.persistentVolumeClaimRetentionPolicy.whenScaled | string | `"Retain"` |  |
| kasmApp.servicesToDeploy.db.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.db.storageClassName | string | `""` |  |
| kasmApp.servicesToDeploy.db.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.kasmApi.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmApi.image | string | `"kasmweb/api"` |  |
| kasmApp.servicesToDeploy.kasmApi.name | string | `"kasm-api"` |  |
| kasmApp.servicesToDeploy.kasmApi.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.kasmApi.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.kasmApi.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.kasmGuac.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmGuac.deploy | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmGuac.image | string | `"kasmweb/kasm-guac"` |  |
| kasmApp.servicesToDeploy.kasmGuac.name | string | `"kasm-guac"` |  |
| kasmApp.servicesToDeploy.kasmGuac.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.kasmGuac.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.kasmGuac.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.kasmManager.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmManager.image | string | `"kasmweb/manager"` |  |
| kasmApp.servicesToDeploy.kasmManager.name | string | `"kasm-manager"` |  |
| kasmApp.servicesToDeploy.kasmManager.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.kasmManager.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.kasmManager.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.kasmProxy.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmProxy.image | string | `"kasmweb/proxy"` |  |
| kasmApp.servicesToDeploy.kasmProxy.name | string | `"kasm-proxy"` |  |
| kasmApp.servicesToDeploy.kasmProxy.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.kasmProxy.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.kasmProxy.serviceKeepalive | int | `16` |  |
| kasmApp.servicesToDeploy.kasmProxy.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.kasmRedis.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmRedis.deploy | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmRedis.image | string | `"redis"` |  |
| kasmApp.servicesToDeploy.kasmRedis.name | string | `"kasm-redis"` |  |
| kasmApp.servicesToDeploy.kasmRedis.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.kasmRedis.tag | string | `"5-alpine"` |  |
| kasmApp.servicesToDeploy.kasmShare.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmShare.deploy | bool | `true` |  |
| kasmApp.servicesToDeploy.kasmShare.image | string | `"kasmweb/share"` |  |
| kasmApp.servicesToDeploy.kasmShare.name | string | `"kasm-share"` |  |
| kasmApp.servicesToDeploy.kasmShare.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.kasmShare.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.kasmShare.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.rdpGateway.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.rdpGateway.deploy | bool | `true` |  |
| kasmApp.servicesToDeploy.rdpGateway.image | string | `"kasmweb/rdp-gateway"` |  |
| kasmApp.servicesToDeploy.rdpGateway.name | string | `"rdp-gateway"` |  |
| kasmApp.servicesToDeploy.rdpGateway.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.rdpGateway.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.rdpGateway.tag | string | `"1.17.0"` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.addHealthChecks | bool | `true` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.deploy | bool | `true` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.image | string | `"kasmweb/rdp-https-gateway"` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.name | string | `"rdp-https-gw"` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.replicas | string | `nil` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.resources | object | `{}` |  |
| kasmApp.servicesToDeploy.rdpHttpsGateway.tag | string | `"1.17.0"` |  |
| kasmApp.zoneName | string | `"default"` |  |
| kasmCerts.db.cert | string | `"######  Place Postgres DB SSL Cert here  ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.db.create | bool | `true` |  |
| kasmCerts.db.key | string | `"######   Place Postgres DB SSL Key here  ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.db.name | string | `"kasm-db-cert"` |  |
| kasmCerts.ingress.cert | string | `"######    Place public SSL Cert here     ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.ingress.create | bool | `true` |  |
| kasmCerts.ingress.key | string | `"######    Place public SSL Key here      ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.ingress.name | string | `"kasm-ingress-cert"` |  |
| kasmCerts.kasmProxy.cert | string | `"######  Place nginx Proxy SSL Cert here  ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.kasmProxy.create | bool | `true` |  |
| kasmCerts.kasmProxy.key | string | `"######   Place nginx Proxy SSL Key here  ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.kasmProxy.name | string | `"kasm-nginx-proxy-cert"` |  |
| kasmCerts.rdpGateway.cert | string | `"######   Place RDP Proxy SSL Cert here   ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.rdpGateway.create | bool | `true` |  |
| kasmCerts.rdpGateway.key | string | `"######   Place RDP Proxy SSL Key here    ######\n######  Leave empty for Helm to generate ######"` |  |
| kasmCerts.rdpGateway.name | string | `"kasm-rdpproxy-cert"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
