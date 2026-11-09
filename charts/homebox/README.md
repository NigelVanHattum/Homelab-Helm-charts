# homebox

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.27.1](https://img.shields.io/badge/AppVersion-0.27.1-informational?style=flat-square)

A Helm chart for Homebox - a self-hosted home inventory management system

## The API key pepper

`HBOX_AUTH_API_KEY_PEPPER` is required: Homebox exits on a value shorter than 32 bytes, and
rotating it invalidates every API key the instance has issued. The chart therefore refuses to
render unless `homebox.auth.apiKeyPepper` is set or `homebox.existingSecret` points at a Secret
that carries it. Generate one with `openssl rand -base64 48`.

## Secrets

Two mutually exclusive paths, as in `paperless-ngx`.

**Inline (the default).** The chart renders a Secret named after the release, holding only the
keys the release uses:

| Key | From | Rendered when |
|---|---|---|
| `api-key-pepper` | `homebox.auth.apiKeyPepper` | always |
| `database-password` | `homebox.database.password` | `homebox.database.driver` is `postgres` and the password is set |
| `s3-access-key-id` | `homebox.storage.s3.accessKeyId` | the value is set |
| `s3-secret-access-key` | `homebox.storage.s3.secretAccessKey` | the value is set |
| `oidc-client-secret` | `homebox.oidc.clientSecret` | the value is set |
| `mailer-password` | `homebox.mailer.password` | the value is set |

**External.** Set `homebox.existingSecret` to a Secret you manage yourself (1Password Connect
operator item, ExternalSecret, …). The chart then renders no Secret at all and reads each value
through `secretKeyRef`, with the key names above overridable per value under
`homebox.existingSecretKeys`. Only `apiKeyPepper` has to be present; the S3, OIDC and mailer refs
are `optional: true`, and the database password ref is only rendered on the `postgres` driver.

## Configuration

Every Homebox setting with a documented default is a key in `homebox.config`, rendered as a
quoted environment variable. Remove a key to fall back to the application's own default, and use
`homebox.extraEnv` for the settings that have no default (mailer host, OIDC issuer and client id,
barcode tokens, …) or that need a `valueFrom`. The exceptions, which have their own values
because the chart derives more than one thing from them, are the API key pepper, the database
block, the S3 credentials and the two other secrets. A secret-bearing key put in `homebox.config`
fails to render: a plain value there would land in the workload spec, which `view` can read.

Two defaults deliberately differ from upstream, both hardening:

| Key | Upstream | Here |
|---|---|---|
| `HBOX_OPTIONS_ALLOW_REGISTRATION` | `true` | `false` |
| `HBOX_NOTIFIER_BLOCK_LOCAL_NETS` | `false` | `true` |

## Image and security context

The default image is the `-rootless` flavour (`<appVersion>-rootless`), which runs as uid 65532 —
the uid `podSecurityContext` pins. Switching `image.variant` to `""` (the regular image, which
runs as root) means emptying `podSecurityContext` too. The container filesystem is read-only;
Homebox writes to its data volume and to `/tmp`, which the chart mounts as an `emptyDir`.

## Database

`sqlite3` on the data volume by default. `postgres` needs `homebox.database.host`, and the chart
fails to render without it. Nothing in the chart deploys PostgreSQL.

## Workload kind and storage

`type` picks `StatefulSet` (the default, which claims the data volume through a
`volumeClaimTemplate`) or `Deployment` (`strategy: Recreate`, no claim of its own: either
`homebox.persistence.data.useExistingPvc` or `homebox.persistence.data.enabled: false`, else the
chart fails to render). Both run exactly one replica: `HBOX_DATABASE_PUB_SUB_CONN_STRING` is
`mem://`, so replicas would not see each other's events.

Stateless needs both stores outside the pod:

```yaml
type: Deployment
homebox:
  database:
    driver: postgres
    host: homebox-rw.cnpg.svc.cluster.local
    password: ...
  storage:
    s3:
      accessKeyId: ...
      secretAccessKey: ...
  config:
    HBOX_STORAGE_CONN_STRING: s3://homebox?endpoint=http://10.0.0.1:9000&disable_https=true&use_path_style=true
  persistence:
    data:
      enabled: false
```

The credentials render as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` through `secretKeyRef`;
an `s3://` connection string without both of them (and without `homebox.existingSecret`) fails to
render, and so does `persistence.data.enabled: false` while the sqlite database or `file://`
storage still points at `/data`.
`use_path_style=true` and `disable_https=true` are what a plain-HTTP IP endpoint such as RustFS
needs. `AWS_SESSION_TOKEN`, `gcs://` and `azblob://` are `homebox.extraEnv` territory.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| fullnameOverride | string | `""` |  |
| homebox.auth.apiKeyPepper | string | `""` | `HBOX_AUTH_API_KEY_PEPPER`. Required: Homebox refuses to start on anything shorter than 32 bytes, and rotating it invalidates every issued API key. Generate with `openssl rand -base64 48`. Unset and without `homebox.existingSecret`, the chart fails to render. |
| homebox.config | object | `{"HBOX_AUTH_RATE_LIMIT_BASE_BACKOFF":"10s","HBOX_AUTH_RATE_LIMIT_ENABLED":true,"HBOX_AUTH_RATE_LIMIT_MAX_ATTEMPTS":5,"HBOX_AUTH_RATE_LIMIT_MAX_BACKOFF":"5m","HBOX_AUTH_RATE_LIMIT_WINDOW":"1m","HBOX_DATABASE_PUB_SUB_CONN_STRING":"mem://{{ .Topic }}","HBOX_DATABASE_SQLITE_PATH":"/data/homebox.db?_pragma=busy_timeout=2000&_pragma=journal_mode=WAL&_fk=1&_time_format=sqlite","HBOX_DEBUG_ENABLED":false,"HBOX_DEBUG_PORT":4000,"HBOX_DEMO":false,"HBOX_LABEL_MAKER_DYNAMIC_LENGTH":true,"HBOX_LABEL_MAKER_FONT_SIZE":32,"HBOX_LABEL_MAKER_HEIGHT":200,"HBOX_LABEL_MAKER_MARGIN":32,"HBOX_LABEL_MAKER_PADDING":32,"HBOX_LABEL_MAKER_WIDTH":526,"HBOX_LOG_FORMAT":"text","HBOX_LOG_LEVEL":"info","HBOX_MODE":"production","HBOX_NOTIFIER_BLOCK_BOGON_NETS":true,"HBOX_NOTIFIER_BLOCK_CLOUD_METADATA":true,"HBOX_NOTIFIER_BLOCK_LOCALHOST":true,"HBOX_NOTIFIER_BLOCK_LOCAL_NETS":true,"HBOX_NOTIFIER_DNS64_NETS":"64:ff9b::/96;64:ff9b:1::/48","HBOX_OIDC_AUTO_REDIRECT":false,"HBOX_OIDC_BUTTON_TEXT":"Sign in with OIDC","HBOX_OIDC_EMAIL_CLAIM":"email","HBOX_OIDC_EMAIL_VERIFIED_CLAIM":"email_verified","HBOX_OIDC_ENABLED":false,"HBOX_OIDC_GROUP_CLAIM":"groups","HBOX_OIDC_NAME_CLAIM":"name","HBOX_OIDC_REQUEST_TIMEOUT":"30s","HBOX_OIDC_SCOPE":"openid profile email","HBOX_OIDC_STATE_EXPIRY":"10m","HBOX_OIDC_VERIFY_EMAIL":false,"HBOX_OPTIONS_ALLOW_ANALYTICS":false,"HBOX_OPTIONS_ALLOW_LOCAL_LOGIN":true,"HBOX_OPTIONS_ALLOW_REGISTRATION":false,"HBOX_OPTIONS_AUTO_INCREMENT_ASSET_ID":true,"HBOX_OPTIONS_GITHUB_RELEASE_CHECK":true,"HBOX_OPTIONS_TRUST_PROXY":false,"HBOX_OTEL_ENABLED":false,"HBOX_OTEL_ENABLE_DATABASE_TRACING":true,"HBOX_OTEL_ENABLE_HTTP_TRACING":true,"HBOX_OTEL_ENABLE_LOGGING":true,"HBOX_OTEL_ENABLE_METRICS":true,"HBOX_OTEL_EXPORTER":"otlp","HBOX_OTEL_INSECURE":false,"HBOX_OTEL_METRICS_INTERVAL":"15s","HBOX_OTEL_PROTOCOL":"grpc","HBOX_OTEL_PROXY_ENABLED":true,"HBOX_OTEL_SAMPLE_RATE":1,"HBOX_OTEL_SERVICE_NAME":"homebox","HBOX_SEARCH_DRIVER":"database","HBOX_SEARCH_MEILISEARCH_HOST":"http://localhost:7700","HBOX_SEARCH_MEILISEARCH_INDEX":"homebox_entities","HBOX_SEARCH_MEILISEARCH_MAX_HITS":1000,"HBOX_STORAGE_CONN_STRING":"file:///?no_tmp_dir=true","HBOX_STORAGE_PREFIX_PATH":"data","HBOX_THUMBNAIL_ENABLED":true,"HBOX_THUMBNAIL_HEIGHT":500,"HBOX_THUMBNAIL_WIDTH":500,"HBOX_WEB_IDLE_TIMEOUT":"30s","HBOX_WEB_MAX_UPLOAD_SIZE":10,"HBOX_WEB_PORT":7745,"HBOX_WEB_READ_TIMEOUT":"10s","HBOX_WEB_WRITE_TIMEOUT":"10s"}` | Every Homebox setting that has a documented default, as a plain env map: the key is the variable name, the value is rendered quoted. Removing a key leaves the application default in place; a variable not listed here (no documented default) goes in the same map or in `homebox.extraEnv`. Database, pepper, the S3 credentials and the two other secrets are not here — they have their own values above, and a secret-bearing key placed here fails to render. |
| homebox.config.HBOX_NOTIFIER_BLOCK_LOCAL_NETS | bool | `true` | Upstream defaults this to `false`. Notifiers reaching RFC1918 addresses from inside the cluster is SSRF reach; set it back to `false` to notify something on the LAN. |
| homebox.config.HBOX_OPTIONS_ALLOW_REGISTRATION | bool | `false` | Upstream defaults this to `true`; a homelab instance behind an ingress does not want open registration. |
| homebox.database.database | string | `"homebox"` |  |
| homebox.database.driver | string | `"sqlite3"` | `HBOX_DATABASE_DRIVER`: `sqlite3` (on the data volume) or `postgres`. |
| homebox.database.host | string | `""` | `HBOX_DATABASE_HOST`. Required when `homebox.database.driver` is `postgres`. |
| homebox.database.password | string | `""` | `HBOX_DATABASE_PASSWORD`, written to the chart's Secret on the inline path. |
| homebox.database.port | int | `5432` |  |
| homebox.database.sslMode | string | `"require"` | `HBOX_DATABASE_SSL_MODE`: `disable`, `require`, `verify-ca` or `verify-full`. |
| homebox.database.username | string | `"homebox"` |  |
| homebox.existingSecret | string | `""` | Name of a Secret this chart does not own, holding every sensitive value. When set, the chart renders no Secret of its own and reads the API key pepper, the database password, the OIDC client secret and the mailer password from it through `secretKeyRef`. Leave empty for the inline path, where the chart writes a Secret from the values below. |
| homebox.existingSecretKeys | object | `{"apiKeyPepper":"api-key-pepper","databasePassword":"database-password","mailerPassword":"mailer-password","oidcClientSecret":"oidc-client-secret","s3AccessKeyId":"s3-access-key-id","s3SecretAccessKey":"s3-secret-access-key"}` | Keys to read from `homebox.existingSecret`. Only used when that is set; the Secret the chart renders itself always uses these same names. |
| homebox.extraEnv | list | `[]` | Extra environment variables, appended verbatim: anything `homebox.config` cannot express, a `valueFrom` in particular. |
| homebox.mailer.password | string | `""` | `HBOX_MAILER_PASSWORD`. The rest of the mailer settings have no upstream default and go in `homebox.config` or `homebox.extraEnv`. |
| homebox.oidc.clientSecret | string | `""` | `HBOX_OIDC_CLIENT_SECRET`. The rest of the OIDC settings are plain `homebox.config` entries. |
| homebox.persistence.data.enabled | bool | `true` | The sqlite database, and attachments while `HBOX_STORAGE_CONN_STRING` is `file://`. Both on an external service (postgres plus `s3://`): set this `false` and the pod keeps no state. |
| homebox.persistence.data.existingVolume | string | `""` | Bind the claim to an existing volume. |
| homebox.persistence.data.matchExpressions | object | `{}` |  |
| homebox.persistence.data.matchLabels | object | `{}` |  |
| homebox.persistence.data.size | string | `"5Gi"` |  |
| homebox.persistence.data.storageClass | string | `""` |  |
| homebox.persistence.data.useExistingPvc | string | `""` | Mount an existing PVC instead of letting the StatefulSet claim one. |
| homebox.storage.s3 | object | `{"accessKeyId":"","secretAccessKey":""}` | Credentials for an S3-compatible `HBOX_STORAGE_CONN_STRING` (`s3://<bucket>?endpoint=http://10.0.0.1:9000&disable_https=true&use_path_style=true` for RustFS on the NAS). Rendered as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` through `secretKeyRef`; the chart fails to render on an `s3://` connection string without them. `AWS_SESSION_TOKEN` and the other backends (gcs, azblob) go in `homebox.extraEnv`. |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/sysadminsmedia/homebox"` |  |
| image.tag | string | `""` | Overrides the image tag, whose default is `<appVersion><image.variant>`. Set it and `image.variant` is unused. |
| image.variant | string | `"-rootless"` | Image flavour appended to the tag: `""` (regular, runs as root), `-rootless` or `-hardened` (both run as uid 65532). Moves together with `podSecurityContext`. |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.httpGet.path | string | `"/api/v1/status"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{"fsGroup":65532,"runAsGroup":65532,"runAsNonRoot":true,"runAsUser":65532}` | Matches the uid/gid of the `-rootless` and `-hardened` images. The regular image runs as root and needs this emptied. |
| readinessProbe.httpGet.path | string | `"/api/v1/status"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| resources | object | `{}` |  |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Homebox writes only to its data volume and to `/tmp`, which the chart mounts as an emptyDir, so the root filesystem can stay read-only. |
| service.port | int | `7745` |  |
| service.type | string | `"ClusterIP"` |  |
| tolerations | list | `[]` |  |
| type | string | `"StatefulSet"` | Workload kind: `Deployment` or `StatefulSet`. A Deployment gets `strategy: Recreate` and claims no volume, so it needs either `homebox.persistence.data.useExistingPvc` or `homebox.persistence.data.enabled: false` (postgres plus S3 storage). Both run one replica. |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| NigelVanHattum |  |  |
