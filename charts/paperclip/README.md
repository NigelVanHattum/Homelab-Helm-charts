# paperclip

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v2026.824.1](https://img.shields.io/badge/AppVersion-v2026.824.1-informational?style=flat-square)

Paperclip - run teams of AI agents as a company. Deploys the app with its own CloudNativePG cluster.

## What this chart does

Deploys the Paperclip server as a StatefulSet, with a dedicated CloudNativePG
`Cluster` for its database. It is a hand-rolled alternative to the
`paperclipinc/paperclip-operator`: no CRD of its own, no cluster-scoped RBAC.

The chart owns the application's environment contract directly. Notable
non-obvious pieces, all of them required for the app to run at all:

- The image ENTRYPOINT is overridden. `docker-entrypoint.sh` gosu-drops to the
  `node` user, which fails under `runAsNonRoot` with all capabilities dropped.
- A `wait-for-db` init container runs `SELECT 1` over `DATABASE_URL` until it
  succeeds, so onboarding never starts its migrations against a database that
  is not up yet. It proves three things at once: the host answers, the role
  authenticates, and the database exists.
- An `onboard` init container then writes the instance config and applies the
  database migrations. `paperclipai onboard` also starts a server, so the
  container waits for the config file and then kills the process tree.
- Probes are TCP in `authenticated` mode: `/api/health` answers 403 there, so an
  HTTP probe would fail forever.
- `shareProcessNamespace` is on so the pause container reaps the zombies left by
  agent-spawned git and shell processes; Node never calls `waitpid()`.
- `terminationGracePeriodSeconds` defaults to 30 minutes so a rollout does not
  SIGKILL a multi-minute agent run.

## Scheduler and replicas

The app has no lease-based scheduler leader election
([paperclipai/paperclip#9005](https://github.com/paperclipai/paperclip/pull/9005)
is unmerged), so `heartbeat.schedulerGating` only accepts `ordinal`: the
entrypoint wrapper enables the scheduler on pod-0 only. There is no failover.
Above one replica the chart refuses to render until
`heartbeat.acknowledgeMultiReplica` is set, because all replicas also share one
ReadWriteOnce data volume.

## Secrets

Every sensitive value takes a `{value, existingSecret, existingSecretKey}` block.
Inline values land in a chart-managed Secret; `existingSecret` references one you
manage yourself. `secretEnvFrom` maps arbitrary environment variables onto keys
in existing secrets.

`checksum/secret` only covers the Secret this chart renders. A value rotated in
an external secret store, or in the CloudNativePG app secret, does not roll the
pods on its own.

## Database

`database.mode: cnpg` (default) creates a `Cluster` and reads `DATABASE_URL`
straight from the app secret CloudNativePG generates for it, so no connection
string has to be assembled or stored anywhere.

`database.mode: external` either takes a whole connection string, or composes one
at runtime from host/port/database/username/password, each of which can come from
its own secret.

In `cnpg` mode the pod cannot start at all until CloudNativePG has created the
app secret, because every container references it: expect
`CreateContainerConfigError` on a first install until the cluster is up. Once the
secret exists, `wait-for-db` covers the rest of the gap while PostgreSQL
finishes bootstrapping.

Backups use the barman-cloud CNPG-I plugin and need
`plugin-barman-cloud` in the cluster. Unlike the upstream
`cloudnative-pg/cluster` chart, the `ObjectStore` here is a plain resource rather
than a Helm hook, so GitOps controllers reconcile it normally.

## First admin

At `deployment.exposure: public` the app disables the browser-based claim on
purpose, and it ships no way to seed an admin declaratively. Someone has to mint
a one-time invite and accept it in a browser.

By hand, once:

```bash
kubectl exec -n <namespace> <release>-0 -c paperclip -- \
  sh -c 'cd /app && pnpm paperclipai auth bootstrap-ceo --data-dir /paperclip'
```

Or set `bootstrap.enabled: true` for a post-sync hook Job that runs the same
command and prints the invite URL to its log. `auth bootstrap-ceo`
short-circuits once an instance admin exists, so the Job is a no-op on every
sync after the first. It is off by default because the invite token then lands
in a Job log, readable by anyone with access to pod logs in that namespace until
the invite is used or expires.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| argocd.syncWaves | object | `{"database":"-1","enabled":true,"objectStore":"-2"}` | Emit `argocd.argoproj.io/sync-wave` annotations on the database objects. Argo CD ships a health check for postgresql.cnpg.io/Cluster, so an earlier wave makes it wait until PostgreSQL is Healthy before it creates the server workload. Without it the first sync spends minutes in CreateContainerConfigError while the app secret does not exist yet. Harmless outside Argo CD: it is only an annotation. |
| auth.betterAuthSecret | object | `{"existingSecret":"","existingSecretKey":"","value":""}` | BETTER_AUTH_SECRET. Required: the app refuses to boot without it. Rotating it invalidates every session. |
| bootstrap.attempts | int | `60` | Attempts to find the instance config written by the onboard container before giving up. |
| bootstrap.backoffLimit | int | `3` |  |
| bootstrap.enabled | bool | `false` | Run a hook Job after each sync that mints the one-time first-admin invite URL and prints it to the Job log. At public exposure the app disables the browser claim on purpose and ships no way to seed an admin declaratively, so an invite has to be created and then accepted by a human. `auth bootstrap-ceo` short-circuits once an instance_admin exists, so this is a no-op on every sync after the first.  Off by default: the invite token lands in the Job log, so anyone who can read pod logs in this namespace can claim the instance until the invite is used or expires. Running the command by hand keeps the token in your terminal instead. |
| bootstrap.expiresHours | string | `""` | Invite lifetime in hours. Empty uses the CLI default of 72. |
| bootstrap.force | bool | `false` | Mint a new invite even when an instance admin already exists. Only for recovering a lost admin; it removes the short-circuit that makes this Job idempotent. |
| bootstrap.hookDeletePolicy | string | `"before-hook-creation"` | Helm hook delete policy. The default keeps the finished Job, and with it the invite URL in its log, until the next sync replaces it. Adding `hook-succeeded` deletes the Job as soon as it succeeds, which also discards the only copy of the token: the invite row stores a hash, so the URL cannot be recovered from the database. |
| bootstrap.intervalSeconds | int | `5` | Seconds between those attempts. |
| bootstrap.ttlSecondsAfterFinished | int | `86400` | How long the finished Job is kept. This is what eventually cleans it up, since the delete policy no longer does. |
| config.extraEnv | object | `{}` | Extra NON-sensitive environment variables, rendered into the ConfigMap. |
| config.logLevel | string | `"info"` | Log level: debug, info, warn or error. |
| database.cnpg.affinity | object | `{"topologyKey":"kubernetes.io/hostname"}` | Cluster affinity, passed through verbatim. |
| database.cnpg.annotations | object | `{}` | Extra annotations on the Cluster object. |
| database.cnpg.appSecretName | string | `""` | Secret holding the application credentials. Defaults to `<clusterName>-app`, which CloudNativePG generates. |
| database.cnpg.appSecretUriKey | string | `"uri"` | Key inside that secret holding the full connection string. |
| database.cnpg.backups.create | bool | `true` | Create the ObjectStore object. Set false to reference one that already exists. |
| database.cnpg.backups.data.compression | string | `"gzip"` |  |
| database.cnpg.backups.data.encryption | string | `""` |  |
| database.cnpg.backups.data.jobs | int | `2` |  |
| database.cnpg.backups.destinationPath | string | `""` | Destination, e.g. `s3://paperclip-backups/`. |
| database.cnpg.backups.enabled | bool | `false` | Back the cluster up to S3-compatible storage with the barman-cloud plugin. Requires the plugin-barman-cloud operator in the cluster. |
| database.cnpg.backups.endpointURL | string | `""` | S3 endpoint, e.g. `http://rustfs.example.internal:9000`. |
| database.cnpg.backups.instanceSidecarConfiguration | object | `{}` | Resources for the barman sidecar. It idles small but gzip during a backup is CPU-bound; requests == limits keeps the pod Guaranteed. |
| database.cnpg.backups.objectStoreName | string | `""` | ObjectStore name. Defaults to `<clusterName>-backups`. |
| database.cnpg.backups.retentionPolicy | string | `"21d"` | Barman retention policy. |
| database.cnpg.backups.scheduledBackups | list | `[{"backupOwnerReference":"self","name":"daily","schedule":"0 45 4 * * *"}]` | ScheduledBackup objects. Schedules are six-field cron (with seconds). |
| database.cnpg.backups.secretName | string | `""` | Secret with ACCESS_KEY_ID and ACCESS_SECRET_KEY. Not created by this chart: the credentials belong to whatever provisions the bucket. |
| database.cnpg.backups.wal.compression | string | `"gzip"` |  |
| database.cnpg.backups.wal.encryption | string | `""` |  |
| database.cnpg.backups.wal.maxParallel | int | `2` |  |
| database.cnpg.clusterName | string | `""` | Cluster name. Defaults to `<fullname>-db`. |
| database.cnpg.create | bool | `true` | Create the Cluster object. Set false to reuse an existing Cluster and only consume its app secret. |
| database.cnpg.database | string | `"paperclip"` | Application database name. |
| database.cnpg.enablePDB | bool | `false` | Create a PodDisruptionBudget for the cluster. Off by default: at a single instance CloudNativePG's PDB is minAvailable 1, which leaves zero allowed disruptions and blocks every node drain. Turn it on once the cluster runs more than one instance. |
| database.cnpg.enableSuperuserAccess | bool | `false` | Allow the postgres superuser to log in. |
| database.cnpg.imageName | string | `""` | Explicit image, overriding `postgresqlVersion`. |
| database.cnpg.instances | int | `1` | Number of PostgreSQL instances. |
| database.cnpg.logLevel | string | `"info"` | Instance log level: error, warning, info, debug or trace. |
| database.cnpg.monitoring.enablePodMonitor | bool | `false` | Create a PodMonitor. Needs the Prometheus Operator CRDs. |
| database.cnpg.owner | string | `"paperclip"` | Owner role of the application database. |
| database.cnpg.parameters | object | `{}` | postgresql.conf parameters. |
| database.cnpg.plugins | list | `[]` | Extra CNPG-I plugins, appended to the barman-cloud plugin when backups are enabled. |
| database.cnpg.postgresqlVersion | string | `"18"` | Major PostgreSQL version, used to pick the operator's default image. |
| database.cnpg.primaryUpdateMethod | string | `"switchover"` |  |
| database.cnpg.primaryUpdateStrategy | string | `"unsupervised"` |  |
| database.cnpg.resources | object | `{}` | Compute resources for the PostgreSQL instances. |
| database.cnpg.storage.size | string | `"10Gi"` |  |
| database.cnpg.storage.storageClass | string | `""` |  |
| database.cnpg.superuserSecret | string | `""` | Secret holding the superuser password, when superuser access is on. |
| database.cnpg.walStorage.enabled | bool | `false` |  |
| database.cnpg.walStorage.size | string | `"5Gi"` |  |
| database.cnpg.walStorage.storageClass | string | `""` |  |
| database.external.database.existingSecret | string | `""` |  |
| database.external.database.existingSecretKey | string | `""` |  |
| database.external.database.value | string | `""` |  |
| database.external.existingSecret | string | `""` | Secret already holding a full connection string. |
| database.external.existingSecretKey | string | `""` |  |
| database.external.host | object | `{"existingSecret":"","existingSecretKey":"","value":""}` | Component mode: used only when neither `url` nor `existingSecret` is set. DATABASE_URL is then composed at runtime from these parts, so a secret-sourced password never lands in the manifest. |
| database.external.password.existingSecret | string | `""` |  |
| database.external.password.existingSecretKey | string | `""` |  |
| database.external.password.value | string | `""` |  |
| database.external.port.existingSecret | string | `""` |  |
| database.external.port.existingSecretKey | string | `""` |  |
| database.external.port.value | string | `"5432"` |  |
| database.external.url | string | `""` | Full connection string, inline. Stored in the chart-managed Secret. |
| database.external.username.existingSecret | string | `""` |  |
| database.external.username.existingSecretKey | string | `""` |  |
| database.external.username.value | string | `""` |  |
| database.mode | string | `"cnpg"` | `cnpg` provisions a dedicated CloudNativePG Cluster and reads DATABASE_URL from the Cluster's generated app secret. `external` points at a database you manage yourself. |
| deployment.allowedHostnames | list | `[]` | Extra hostnames added to PAPERCLIP_ALLOWED_HOSTNAMES. The Service DNS names, loopback and every `ingress.hosts[].host` are added automatically. |
| deployment.disableSignUp | bool | `true` | Disable public self-service sign-up. |
| deployment.exposure | string | `"private"` | `private` (ClusterIP only) or `public`. `public` requires `publicUrl`. |
| deployment.mode | string | `"authenticated"` | `authenticated` (login required) or `local_trusted` (no auth at all). `local_trusted` requires `exposure: private`. |
| deployment.publicUrl | string | `""` | Externally reachable URL. Required when `exposure: public`. |
| drain.enabled | bool | `true` | preStop hook that holds the container briefly before SIGTERM, so the pod leaves the Service endpoints before it starts draining. |
| drain.timeoutSeconds | int | `15` |  |
| entrypoint | string | `"node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js"` | Server entrypoint. The image ENTRYPOINT is deliberately overridden: it gosu-drops to the "node" user, which fails under runAsNonRoot + drop ALL. |
| extraEnv | list | `[]` | Extra env entries appended verbatim to the container spec. |
| extraInitContainers | list | `[]` | Extra init containers, appended after the onboard container. |
| extraVolumeMounts | list | `[]` | Extra volume mounts on the app container. |
| extraVolumes | list | `[]` | Extra volumes on the pod. |
| fullnameOverride | string | `""` | Override the fully qualified release name. |
| heartbeat.acknowledgeMultiReplica | bool | `false` | Acknowledge that `replicaCount > 1` pins the scheduler to pod-0 with no failover, and that all replicas share one RWO data volume. Required to render with more than one replica. |
| heartbeat.enabled | bool | `true` | Run the agent heartbeat scheduler. |
| heartbeat.intervalMs | int | `60000` | Scheduler interval in milliseconds. |
| heartbeat.schedulerGating | string | `"ordinal"` | Must stay `ordinal`. The app has no lease-based leader election (paperclipai/paperclip#9005 is still open), so any other value would let every replica run the scheduler. |
| image.digest | string | `"sha256:bdc256b2b289c4085d27625d8915b665c509297b526201bfcea5114634ce2548"` | Image digest. Wins over `tag`. Default is the digest behind release v2026.824.1 (commit 8e6edcd). One of `tag` or `digest` is required. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.repository | string | `"ghcr.io/paperclipai/paperclip"` | Application image repository. |
| image.tag | string | `""` | Image tag. The registry publishes no version tags, only `sha-<commit>` and mutable pointers (latest/canary/nightly/beta), so prefer `digest`. |
| imagePullSecrets | list | `[]` | Image pull secrets. |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts | list | `[]` | Hosts. Every entry is also added to PAPERCLIP_ALLOWED_HOSTNAMES. |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Override the chart name. |
| networkPolicy.egress.database | bool | `true` | Allow 5432/tcp to the CNPG cluster pods. |
| networkPolicy.egress.dns | bool | `true` | Allow DNS to any destination. |
| networkPolicy.egress.extra | list | `[]` | Extra egress rules, appended verbatim. Git over SSH (22/tcp) and in-cluster services on other ports need an entry here. |
| networkPolicy.egress.https | bool | `true` | Allow 443/tcp out (LLM APIs, git over HTTPS, npm). |
| networkPolicy.enabled | bool | `false` | Create a NetworkPolicy. Needs a CNI that enforces them; Flannel does not. |
| networkPolicy.ingress.allowAll | bool | `true` | Allow any source on the service port. Narrow this with `from` below. |
| networkPolicy.ingress.extra | list | `[]` | Extra ingress rules, appended verbatim. |
| networkPolicy.policyTypes[0] | string | `"Ingress"` |  |
| networkPolicy.policyTypes[1] | string | `"Egress"` |  |
| nodeSelector | object | `{}` |  |
| onboard.enabled | bool | `true` | Run the onboarding init container. It creates `<mountPath>/instances/default/config.json` and applies the database migrations; without it the server does not start on an empty volume. |
| onboard.timeoutSeconds | int | `120` | Seconds to wait for the config file to appear before failing. |
| persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| persistence.enabled | bool | `true` | Persist the Paperclip data directory. Disabled means emptyDir and losing agent workspaces on restart. |
| persistence.mountPath | string | `"/paperclip"` | Data directory. Also becomes PAPERCLIP_HOME. |
| persistence.size | string | `"20Gi"` |  |
| persistence.storageClass | string | `""` |  |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.fsGroup | int | `1000` |  |
| podSecurityContext.runAsGroup | int | `1000` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `1000` |  |
| priorityClassName | string | `""` |  |
| probes.liveness.failureThreshold | int | `6` |  |
| probes.liveness.initialDelaySeconds | int | `15` |  |
| probes.liveness.periodSeconds | int | `20` |  |
| probes.liveness.successThreshold | int | `1` |  |
| probes.liveness.timeoutSeconds | int | `5` |  |
| probes.path | string | `"/api/health"` |  |
| probes.readiness.failureThreshold | int | `3` |  |
| probes.readiness.initialDelaySeconds | int | `5` |  |
| probes.readiness.periodSeconds | int | `10` |  |
| probes.readiness.successThreshold | int | `1` |  |
| probes.readiness.timeoutSeconds | int | `3` |  |
| probes.startup.failureThreshold | int | `60` |  |
| probes.startup.initialDelaySeconds | int | `10` |  |
| probes.startup.periodSeconds | int | `10` |  |
| probes.startup.successThreshold | int | `1` |  |
| probes.startup.timeoutSeconds | int | `5` |  |
| probes.type | string | `"auto"` | `auto`, `http` or `tcp`. `auto` uses TCP in authenticated mode, where /api/health answers 403 without credentials. |
| replicaCount | int | `1` | Number of server replicas. Above 1 you must also set `heartbeat.acknowledgeMultiReplica` — see that field. |
| resources | object | `{}` |  |
| secretEnv | object | `{}` | Sensitive environment variables, inline. Written into the chart-managed Secret, one key per variable. Anything sourced from an external secret store belongs in `secretEnvFrom` instead. |
| secretEnvFrom | object | `{}` | Sensitive environment variables mapped onto keys in secrets you manage yourself, e.g. one produced by a OnePasswordItem. Example:   ANTHROPIC_API_KEY:     existingSecret: paperclip-litellm     key: ANTHROPIC_API_KEY |
| secrets.masterKey | object | `{"existingSecret":"","existingSecretKey":"","value":""}` | PAPERCLIP_SECRETS_MASTER_KEY. Required. Everything the app stores under `local_encrypted` is encrypted with this key: rotating it is data loss. |
| secrets.provider | string | `"local_encrypted"` | Secrets backend. Only `local_encrypted` is wired by this chart. |
| secrets.strictMode | bool | `false` | Require encrypted references for all sensitive values. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}` | readOnlyRootFilesystem is deliberately absent: the app writes node_modules and agent workspaces outside the data volume. |
| service.annotations | object | `{}` |  |
| service.port | int | `3100` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automountServiceAccountToken | bool | `false` | The app needs no Kubernetes API access in this chart's supported modes. |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| serviceMonitor.enabled | bool | `false` | Create a ServiceMonitor. Needs the Prometheus Operator CRDs. Grafana Alloy scrapes the prometheus.io/* pod annotations instead. |
| serviceMonitor.interval | string | `"30s"` |  |
| shareProcessNamespace | bool | `true` | Share the PID namespace so the pause container reaps the zombies left by agent-spawned git, shell and plugin processes. Node never calls waitpid(). |
| sidecars | list | `[]` | Extra sidecar containers. |
| terminationGracePeriodSeconds | int | `1800` | Ceiling for SIGTERM to SIGKILL. The server soft-drains in-flight agent runs in this window; the default is deliberately long so a rollout does not cut a multi-minute run short. |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` |  |
| waitForDatabase.attempts | int | `60` | Connection attempts before giving up. |
| waitForDatabase.connectTimeoutSeconds | int | `5` | libpq connect timeout per attempt, so a blackholed host fails fast instead of hanging the whole init. |
| waitForDatabase.enabled | bool | `true` | Block startup on an init container that proves the database is reachable AND accepts these credentials, before onboarding runs its migrations. Without it a database that is not up yet surfaces as a failed onboard and a pod restart loop. |
| waitForDatabase.image.pullPolicy | string | `"IfNotPresent"` |  |
| waitForDatabase.image.repository | string | `"ghcr.io/cloudnative-pg/postgresql"` |  |
| waitForDatabase.image.tag | string | `""` | Tag. Empty follows `database.cnpg.postgresqlVersion`. |
| waitForDatabase.intervalSeconds | int | `2` | Seconds between attempts. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| NigelVanHattum |  |  |
