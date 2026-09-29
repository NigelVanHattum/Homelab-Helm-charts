# paperless-ngx

![Version: 1.2.0](https://img.shields.io/badge/Version-1.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.20.10](https://img.shields.io/badge/AppVersion-2.20.10-informational?style=flat-square)

A Helm chart for Paperless-ngx - A community-supported open-source document management system

## Secrets

There are two paths, and they are mutually exclusive.

**Inline (the default).** Leave `paperless.existingSecret` empty and the chart renders a Secret
named after the release, from the values you pass it:

| Key | From |
|---|---|
| `admin-password` | `paperless.env.PAPERLESS_ADMIN_PASSWORD` |
| `secret-key` | `paperless.env.PAPERLESS_SECRET_KEY` |
| `db-password` | `paperless.database.password`, only when `paperless.database.enabled` is false |
| `authentik-client-secret` | `paperless.authentik.clientSecret`, only when `paperless.authentik.enabled` is true |
| `socialaccount-providers` | the `PAPERLESS_SOCIALACCOUNT_PROVIDERS` document the chart composes, only when `paperless.authentik.enabled` is true |

**External.** Set `paperless.existingSecret` to the name of a Secret in the release namespace
that you manage yourself — a 1Password Connect operator item, an ExternalSecret, anything. The
chart then renders no Secret at all and reads every sensitive env var from yours. The key names
default to the ones in the table above and are overridable per value under
`paperless.existingSecretKeys`, so an operator-delivered Secret can keep its own field names:

```yaml
paperless:
  existingSecret: paperless-ngx-credentials
  existingSecretKeys:
    adminPassword: admin-password
    secretKey: secret-key
    dbPassword: db-password
    socialaccountProviders: socialaccount-providers
```

The external Secret has to carry every key the release actually uses: `adminPassword` and
`secretKey` always, `dbPassword` unless `paperless.database.enabled` is true (that path takes
the password from the PostgreSQL subchart's own Secret), and `socialaccountProviders` when
`paperless.authentik.enabled` is true.

Usernames stay in values either way: `PAPERLESS_ADMIN_USER` and `PAPERLESS_DBUSER` are plain env
values, as are the host, port and database name.

## The OIDC provider document

Paperless takes its whole social-account configuration as one JSON env var,
`PAPERLESS_SOCIALACCOUNT_PROVIDERS`, and that document contains the OIDC client secret. An env
`value` would put it in the pod spec in cleartext, readable by anyone with `get pod`, so the
chart never renders it as one: the document goes into a Secret and the env var is a
`secretKeyRef`.

On the inline path the chart composes the document from `paperless.authentik.clientId`,
`clientSecret` and either `oidcWellKnownUrl` or `domain` + `applicationSlug`, and writes it to
its own Secret under `socialaccount-providers`. Nothing changes for you.

On the external path *you* supply the finished document under the `socialaccountProviders` key,
`server_url` included, and the chart ignores `paperless.authentik.clientId`, `clientSecret`,
`domain`, `applicationSlug` and `oidcWellKnownUrl`. The shape the chart itself produces, for
reference:

```json
{"openid_connect": {"OAUTH_PKCE_ENABLED": true, "APPS": [{"provider_id": "authentik", "name": "authentik", "client_id": "…", "secret": "…", "settings": {"server_url": "https://auth.example.com/application/o/paperless/.well-known/openid-configuration", "fetch_userinfo": true}}], "SCOPE": ["openid", "profile", "email"]}}
```

The remaining Authentik values — `logoutUrl`, `autoSignup`, `allowSignups` — are plain env vars
on both paths.

## Tika and Gotenberg

Both default to `enabled: true` and the chart deploys neither. The endpoints then point at
`<release>-tika` and `<release>-gotenberg`, Services this chart never creates. Either turn them
off, or run those workloads separately and point `paperless.tika.url` / `paperless.gotenberg.url`
at them.

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
| paperless.authentik.logoutUrl | string | `""` |  |
| paperless.authentik.oidcWellKnownUrl | string | `""` |  |
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
| paperless.existingSecret | string | `""` | Name of a Secret this chart does not own, holding every sensitive value. When set, the chart renders no Secret of its own and reads the admin password, `PAPERLESS_SECRET_KEY`, the database password and the whole `PAPERLESS_SOCIALACCOUNT_PROVIDERS` document from it through `secretKeyRef`. Leave empty for the default inline path, where the chart writes a Secret from the values below. See the "Secrets" section above. |
| paperless.existingSecretKeys | object | `{"adminPassword":"admin-password","dbPassword":"db-password","secretKey":"secret-key","socialaccountProviders":"socialaccount-providers"}` | Keys to read from `paperless.existingSecret`. Only used when that is set; the Secret the chart renders itself always uses these same names. |
| paperless.existingSecretKeys.adminPassword | string | `"admin-password"` | Key holding `PAPERLESS_ADMIN_PASSWORD`. |
| paperless.existingSecretKeys.dbPassword | string | `"db-password"` | Key holding `PAPERLESS_DBPASS`. Not read when `paperless.database.enabled` is true — that path takes the password from the PostgreSQL subchart's own Secret. |
| paperless.existingSecretKeys.secretKey | string | `"secret-key"` | Key holding `PAPERLESS_SECRET_KEY`. |
| paperless.existingSecretKeys.socialaccountProviders | string | `"socialaccount-providers"` | Key holding the complete `PAPERLESS_SOCIALACCOUNT_PROVIDERS` JSON document, client id, client secret and `server_url` included. Only read when `paperless.authentik.enabled` is true, and then `paperless.authentik.clientId`, `clientSecret`, `domain`, `applicationSlug` and `oidcWellKnownUrl` are all unused. |
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

