# mailflow

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 4.4.0](https://img.shields.io/badge/AppVersion-4.4.0-informational?style=flat-square)

A Helm chart for MailFlow - a self-hosted, unified webmail client

MailFlow ships no upstream Helm chart. This one follows `docker-compose.ghcr.yml` and
`.env.example` of the `appVersion` it pins, with the compose file's PostgreSQL left out.

## Two workloads, and a third for a pin

| Component | Image | Port | Probe |
|---|---|---|---|
| `backend` | `ghcr.io/maathimself/mailflow-backend` | 3000 | `GET /api/health` |
| `frontend` | `ghcr.io/maathimself/mailflow-frontend` (Caddy) | 80 | `GET /` |
| `redis` | `redis`, pinned by tag and digest | 6379 | `redis-cli ping` |

One `image.tag` drives backend and frontend, because upstream releases them together; it
defaults to the chart `appVersion`. Each component gets its own Deployment, Service and
`resources`, and they share `podAnnotations`, `podLabels`, `nodeSelector`, `tolerations` and
`affinity`.

**Redis is off by default.** 4.4.0 moved sessions and short-lived keys to Postgres and ignores
`REDIS_URL`, so neither the workload, its Service nor the variable is rendered. It is kept, with
its own tag, for an `image.tag` pinned back to 4.3.x — upstream documents going back, and that
release does not start without a Redis.

A pin back carries the nginx frontend with it, so the chart refuses a pre-4.4.0 tag that is
missing any of the three things that release needs: a Redis (`redis.enabled` or
`backend.redisUrl`), `SETUID`/`SETGID` in `frontend.securityContext.capabilities.add`, and
`frontend.securityContext.readOnlyRootFilesystem: false`. Each refusal names the pod failure it
prevents. The recipe is under "The Redis password".

Upgrading from a 4.3.x release of this chart signs **everyone** out once, as the sessions move;
migrations 0076 and 0077 run on the backend's first start, which is what the `startupProbe`
covers.

The frontend proxies `/api/`, `/ws`, `/carddav` and the OAuth paths itself, so the ingress routes
every host to the frontend Service and the backend Service stays internal.

## Configuration

`backend.env` and `frontend.env` are raw env lists, appended verbatim, so a new MailFlow
variable needs no chart change. The variables 4.4.0 reads: `NODE_ENV`, `PORT`,
`SESSION_SECRET`, `APP_URL`, `FRONTEND_URL`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`,
`DB_PASSWORD`, `ENCRYPTION_KEY`, `FIRST_USER_REGISTRATION`, `VAPID_PUBLIC_KEY`,
`VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, `IMAP_MAX_PERSISTENT_PER_HOST`, `TRUST_PROXY_HOPS`,
`MS_BUILTIN_APP`, `MS_CLIENT_ID`, `MS_CLIENT_SECRET`, `MS_TENANT_ID`, `MS_REDIRECT_URI`,
`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`, `IMAGE_CACHE_DIR`,
`IMAGE_CACHE_MAX_MB`. `DOMAIN` and `ACME_EMAIL` go in `frontend.env`, for
`frontend.tlsMode: letsencrypt`.

**`TRUST_PROXY_HOPS: "2"` belongs in `backend.env` whenever `ingress.enabled`.** Two proxies
are in front of the backend then — the ingress, then this chart's frontend — and the backend
reads an empty value as one hop, which makes the client address it sees the ingress's for every
request. The login rate limit and Login Activity both come from that address, so one shared
bucket throttles every user when one account is attacked, and every sign-in is logged as the
ingress. `3` would let a client choose the address it is limited and logged under. The chart
cannot derive it — `backend.env` is a raw list and the proxy in front is not the chart's to
know — so `NOTES.txt` says so at install time when an ingress is enabled and the variable is
absent.

`FIRST_USER_REGISTRATION=false` works from 4.4.0 on: the first account to register is then an
ordinary one and registration starts closed. At 4.3.1 the variable did nothing and the first
registration took the admin account whatever the settings said, so an install that was open for
a moment could be taken over.

"Provider enforces MFA", also new in 4.4.0, is a per-provider setting in Settings → Single
Sign-On, not a chart value.

Eight variables are the chart's, because it derives them from values the workloads, Services
and mounts use as well. Setting one in a raw env list fails to render rather than leaving the
duplicate to the kubelet:

| Variable | Comes from |
|---|---|
| `NODE_ENV` | pinned to `production` |
| `PORT`, `BACKEND_PORT` | `backend.service.port` |
| `REDIS_URL` | the Redis this chart deploys, or `backend.redisUrl`; unset when there is neither |
| `IMAGE_CACHE_DIR` | `imageCache.path` |
| `BACKEND_HOST` | the backend Service, or `frontend.backendHost` |
| `TLS_MODE` | `frontend.tlsMode` |
| `NGINX_TLS` | `frontend.nginxTls` |

## Secrets

This chart renders no Secret and holds no credential default. `SESSION_SECRET`,
`DB_PASSWORD`, `ENCRYPTION_KEY`, `VAPID_PRIVATE_KEY`, `MS_CLIENT_SECRET` and
`GOOGLE_CLIENT_SECRET` belong in `backend.env` as a `valueFrom.secretKeyRef`, pointed at a
Secret something else owns (Terraform's `kubernetes_secret_v1`, a 1Password Connect item, an
ExternalSecret). A plain `value` for one of them fails to render: it would land in the workload
spec, which ClusterRole `view` reads.

```yaml
backend:
  env:
    - name: DB_HOST
      value: mailflow-rw.cnpg.svc.cluster.local
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mailflow-database
          key: password
```

## TLS on the frontend

The 4.4.0 frontend is Caddy, and `TLS_MODE` decides what it serves. **`off` is the only value
this chart renders**, and it always renders it. The other two serve HTTPS on **443**, which the
chart does not publish — it gives the frontend port 80 alone, because the ingress terminates
TLS — so both fail to render with that reason:

| `frontend.tlsMode` | Caddy site | Why the chart refuses it |
|---|---|---|
| `off` (the default) | `:80` | — |
| `self-signed` | `:443` + `:80` | 443 is not published, so the HTTPS listener is unreachable and the certificate it writes is pointless |
| `letsencrypt` | `{$DOMAIN}` only | nothing answers the pod IP: the kubelet's `GET /` matches no site and gets a 404, so liveness restarts the pod |

An empty or unknown value is refused too, because **the image reads an unset `TLS_MODE` as
`self-signed`**: behind an ingress that already terminates TLS that serves a certificate no
browser accepts, and HSTS from an earlier visit makes it unrecoverable without clearing it.

`NGINX_TLS` is inert at 4.4.0 — the image consults it only when `TLS_MODE` is empty, which this
chart never renders — and it is all a 4.3.x `image.tag` reads, so it stays at `off`: pinning back
is then a tag change. `frontend.nginxTls: ""` drops the variable. A custom `nginx.conf` mount and
`NGINX_BASE` no longer apply at all; `FRONTEND_BASE` replaced the latter, and it is a build
argument, not a runtime one.

The probe is `GET /` on port 80, not the image's own `/healthz`: Caddy binds that on
`127.0.0.1:2080`, which no kubelet reaches, and 4.3.x has no such location.

## Security contexts

Every container drops every capability and asks for the `RuntimeDefault` seccomp profile, the
`helm test` hook included. What each workload needs beyond that, the images decide, not a
preference:

- `frontend` runs with a **read-only root filesystem**. `TLS_MODE=off` writes no certificate,
  and the Caddyfile sets `admin off` and `persist_config off` and takes every setting from the
  environment, so nothing is written anywhere — which upstream keeps that way deliberately
  (upstream #453). A pre-4.4.0 `image.tag` is refused beside it: that nginx entrypoint rewrites
  `/etc/nginx/conf.d/default.conf` at boot and fails soft doing it, which would leave HTTPS on
  with no certificate and `/api/` pointed at nothing.
- `frontend` still runs as **root**, and adds `NET_BIND_SERVICE` alone — `SETUID`/`SETGID` went
  with nginx, which forked its workers as another user. Caddy listens on port 80, and
  `drop: [ALL]` takes the capability away from root as well. A pre-4.4.0 `image.tag` needs both
  capabilities back, and the chart refuses the pin without them: that nginx master is root and
  starts each worker with `setgid()`/`setuid()`, so beside `drop: [ALL]` every worker exits at
  init, the master respawns them forever and nothing is served. A non-root uid cannot have it
  instead: containerd grants no *ambient* capabilities, so a capability in the bounding set
  reaches a non-root process only if the binary carries it as a file capability, and
  `caddy:2-alpine` does not. A `restricted` namespace therefore waits on upstream serving the
  app from a port above 1024, not on a value here.
- `redis` runs as **uid 999 / gid 1000**, the image's `redis` user, with `fsGroup: 1000` for
  the `emptyDir`. At uid 0 the official entrypoint takes its root branch — `chown` of `/data`,
  then `gosu` — which `drop: [ALL]` forbids, and it runs under `set -e`, so the container
  exits before `redis-server` ever starts.
- `backend` runs as **uid/gid 1000**, the `node` user its image already uses. The uid is
  explicit because the image's `USER` is the name `node`, which the kubelet cannot check
  against `runAsNonRoot`. It also keeps a `startupProbe` in front of liveness: the backend
  reaches `httpServer.listen` only after the migrations, the contact-photo backfill and the
  credential re-encryption finish, so `/api/health` refuses connections for a while on a first
  install or an upgrade, and the kubelet's liveness default would restart the pod mid-migration.

`readOnlyRootFilesystem` is not set for the backend or Redis: not verified for either without
running the images.

The bundled Redis is pinned by tag **and** digest (`<tag>@<digest>`), as in
`charts/paperless-ngx`: a floating `7-alpine` with `IfNotPresent` would let a rescheduled pod
pull whatever the tag points at that day. Change `redis.image.tag` and `redis.image.digest`
together, or clear the digest to pull by tag.

## The Redis password

For a pre-4.4.0 `image.tag` only. A MailFlow session was mailbox access, and nothing in front of
`<release>-redis:6379` asks for a credential by itself, so the bundled Redis takes a
`requirepass` and the chart refuses to render it without one. `redis.auth.existingSecret` names
a Secret something else owns; the chart writes no Secret and carries no default.

One key reaches three places, each as a `secretKeyRef`:

| Where | How |
|---|---|
| `--requirepass` on the server | `args: [..., --requirepass, $(REDIS_PASSWORD)]`, expanded by the kubelet |
| the `redis-cli ping` probes | `REDISCLI_AUTH`, or both probes answer `NOAUTH` |
| the backend's `REDIS_URL` | `redis://:$(REDIS_PASSWORD)@host:port`, with `REDIS_PASSWORD` declared before it |

Nothing puts the value in the pod spec: `$(VAR)` is expanded at container start, not at render
time. The password has to be **URL-safe** (no `@ : / ? # % [ ]`), because it goes into
`REDIS_URL`.

An **external** Redis gets the same escape rather than a literal in the URL:
`redis.auth.existingSecret` is honoured whatever `redis.enabled` says, and `REDIS_PASSWORD`
still renders ahead of `REDIS_URL`, so reference it in `backend.redisUrl` yourself:

```yaml
image:
  tag: "4.3.1"
frontend:
  securityContext:
    readOnlyRootFilesystem: false
    capabilities:
      drop:
        - ALL
      add:
        - SETUID
        - SETGID
        - NET_BIND_SERVICE
redis:
  enabled: false
  auth:
    existingSecret: mailflow-redis-auth
backend:
  redisUrl: redis://:$(REDIS_PASSWORD)@redis.other.svc.cluster.local:6379
```

The chart refuses to render a `backend.redisUrl` that references `$(REDIS_PASSWORD)` with no
Secret behind it — unresolved, the literal string would become the password Redis is sent.

`redis.auth.enabled: false` accepts a Redis that asks for nothing — a decision, not a default,
and only reasonable where something else keeps other pods off port 6379. A NetworkPolicy is not
that something in a cluster running Cilium with `enable-policy = never`.

## Database

Nothing here deploys PostgreSQL. Point `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` and
`DB_PASSWORD` at one through `backend.env`. From 4.4.0 it also holds the sessions, so it is the
only thing MailFlow keeps state in.

## State

Neither the image cache nor Redis claims a PVC.

- `imageCache.path` is an `emptyDir` with `imageCache.sizeLimit`, mounted where
  `IMAGE_CACHE_DIR` points. Keep `IMAGE_CACHE_MAX_MB` (512 by default in the application)
  below that limit, or the kubelet evicts the pod before MailFlow prunes the cache itself.
- `redis.enabled` deploys the pinned `redis` image on an `emptyDir` at `/data`, with compose's
  `--save 60 1 --loglevel warning`. Sessions and cache only; they do not survive the pod.

The backend runs with `terminationGracePeriodSeconds: 30`, matching compose: upstream waits up
to 25 s for a send in flight to finish. Both the backend and Redis use `strategy: Recreate`,
so a rollout never runs two of either beside each other.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| backend.env | list | `[]` | Environment appended verbatim, the raw list `03_applications` wires: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `SESSION_SECRET`, `ENCRYPTION_KEY`, `APP_URL`, `FRONTEND_URL`, `FIRST_USER_REGISTRATION`, `TRUST_PROXY_HOPS`, `VAPID_*`, `IMAP_MAX_PERSISTENT_PER_HOST`, `IMAGE_CACHE_MAX_MB`, `MS_*`, `GOOGLE_*`. A sensitive one belongs here as a `valueFrom`; a plain value for one fails to render. `NODE_ENV`, `PORT`, `REDIS_URL` and `IMAGE_CACHE_DIR` are the chart's and are rejected here too.  **Set `TRUST_PROXY_HOPS: "2"` whenever `ingress.enabled`.** Two proxies sit in front of the backend there - the ingress, then this chart's frontend - and the backend reads an empty value as one hop, which makes `req.ip` the ingress for every request: one shared login rate-limit bucket, and every sign-in logged as the ingress. `3` would be client-spoofable. |
| backend.image.repository | string | `"ghcr.io/maathimself/mailflow-backend"` |  |
| backend.livenessProbe.httpGet.path | string | `"/api/health"` |  |
| backend.livenessProbe.httpGet.port | string | `"http"` |  |
| backend.podSecurityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | uid/gid 1000, the `node` user the image already runs as. The uid is explicit on purpose: the image's `USER` is the *name* `node`, which the kubelet cannot check against `runAsNonRoot`, so the pair without it fails with "image has non-numeric user". `fsGroup` is what makes the image-cache `emptyDir` writable for that gid. |
| backend.readinessProbe.httpGet.path | string | `"/api/health"` |  |
| backend.readinessProbe.httpGet.port | string | `"http"` |  |
| backend.redisUrl | string | `""` | `REDIS_URL`, for an `image.tag` pinned back before 4.4.0 only; 4.4.0 ignores it. Empty points at the Redis this chart deploys, when `redis.enabled`. The variable is not rendered at all while neither is set. |
| backend.resources | object | `{}` |  |
| backend.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| backend.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| backend.securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| backend.service.port | int | `3000` | One port for the container's `PORT`, the Service and the frontend's `BACKEND_PORT`, so the three cannot drift apart. |
| backend.service.type | string | `"ClusterIP"` |  |
| backend.startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/api/health","port":"http"},"periodSeconds":10}` | v4.3.1 reaches `httpServer.listen` only after Redis connects and the migrations, the contact-photo backfill and the credential re-encryption finish (`backend/src/index.js`), so `/api/health` refuses connections for a while on a first install. The kubelet's liveness default (3 x 10 s) would restart the pod mid-migration; this covers 300 s and holds liveness off until it passes once. Set it to `null` to drop the probe. |
| backend.terminationGracePeriodSeconds | int | `30` | Upstream waits up to 25 s for a send in flight to finish; compose gives it a 30 s `stop_grace_period`. |
| frontend.backendHost | string | `""` | `BACKEND_HOST`. Empty uses this release's backend Service. Never leave it at the image's compose default (`backend`), which resolves to nothing here (upstream #436). |
| frontend.env | list | `[]` | Environment appended verbatim. `NGINX_TLS`, `TLS_MODE`, `BACKEND_HOST` and `BACKEND_PORT` are the chart's and are rejected here. |
| frontend.image.repository | string | `"ghcr.io/maathimself/mailflow-frontend"` |  |
| frontend.livenessProbe | object | `{"httpGet":{"path":"/","port":"http"}}` | `GET /` on port 80, not the image's own `/healthz`: the Caddy frontend binds that one on `127.0.0.1:2080`, which no kubelet reaches, and 4.3.x has no such location at all. |
| frontend.nginxTls | string | `"off"` | `NGINX_TLS`. Inert at 4.4+ - the image reads it only when `TLS_MODE` is empty, which this chart never renders - and it is all a 4.3.x `image.tag` reads, so it stays at `off` to keep pinning back a tag change. Empty drops the variable. |
| frontend.podSecurityContext | object | `{}` | Root, still. `caddy:2-alpine` has no `USER`, and Caddy listens on port 80, which it can only do as a non-root uid if the runtime grants `NET_BIND_SERVICE` as an *ambient* capability - containerd does not. A `restricted` namespace therefore needs an upstream change to the listening port, not a value here. |
| frontend.readinessProbe.httpGet.path | string | `"/"` |  |
| frontend.readinessProbe.httpGet.port | string | `"http"` |  |
| frontend.resources | object | `{}` |  |
| frontend.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"add":["NET_BIND_SERVICE"],"drop":["ALL"]},"readOnlyRootFilesystem":true,"seccompProfile":{"type":"RuntimeDefault"}}` | `NET_BIND_SERVICE` is what lets port 80 be bound beside `drop: [ALL]`; `SETUID`/`SETGID` are gone with nginx and its workers. An `image.tag` pinned back before 4.4.0 needs both of them added again - that nginx master is root and each worker calls `setgid()`/`setuid()`, which `drop: [ALL]` forbids, so every worker dies at init and nothing is served - and the chart refuses the pin without them. `readOnlyRootFilesystem` holds because `TLS_MODE=off` writes no certificate and the Caddyfile sets `admin off` and `persist_config off`, so nothing is written at all - which upstream keeps that way on purpose (upstream #453). |
| frontend.service.port | int | `80` |  |
| frontend.service.type | string | `"ClusterIP"` |  |
| frontend.startupProbe | object | `{}` |  |
| frontend.tlsMode | string | `"off"` | `TLS_MODE`, how the 4.4+ Caddy frontend serves the app. `off` is the only value this chart renders: it publishes port 80 alone, for an ingress that terminates TLS, while the image's other two modes (`self-signed`, `letsencrypt`) serve HTTPS on 443. Always rendered, never empty, and the chart refuses anything else: an unset `TLS_MODE` means `self-signed` to the image, which behind Traefik serves a certificate no browser accepts. |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.tag | string | `""` | Tag for both MailFlow images. Upstream releases backend and frontend together, so one value moves both. Defaults to the chart `appVersion`. |
| imageCache | object | `{"path":"/var/cache/mailflow/images","sizeLimit":"1Gi"}` | `IMAGE_CACHE_DIR` and the `emptyDir` the backend mounts there, from one value so the variable and the mount path cannot drift apart. Keep `IMAGE_CACHE_MAX_MB` (512 by default in the application) below `imageCache.sizeLimit`, or the kubelet evicts the pod before MailFlow prunes the cache itself. |
| imagePullSecrets | list | `[]` |  |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | Routes to the frontend Service. Multi-host: MailFlow is reached on every host listed. |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | Annotations added to all three pods. |
| podLabels | object | `{}` | Labels added to all three pods. |
| redis.args[0] | string | `"--save"` |  |
| redis.args[1] | string | `"60"` |  |
| redis.args[2] | string | `"1"` |  |
| redis.args[3] | string | `"--loglevel"` |  |
| redis.args[4] | string | `"warning"` |  |
| redis.auth | object | `{"enabled":true,"existingSecret":"","existingSecretKey":"redis-password"}` | `requirepass` for the Redis this chart deploys, read from a Secret something else owns (Terraform's `kubernetes_secret_v1`). No default, and the chart renders no Secret: a password in values would land in the release. One key covers all three places it is needed - the server's `--requirepass`, `REDISCLI_AUTH` for the probes, and the password in the backend's `REDIS_URL` - and reaches each of them as a `secretKeyRef`, never a literal in the pod spec. The value has to be URL-safe (no `@ : / ? # % [ ]`): it goes into a URL. |
| redis.auth.enabled | bool | `true` | `false` accepts a Redis that asks for no password. Only reasonable where something else keeps every other pod off port 6379, which a NetworkPolicy is not in a cluster running Cilium with `enable-policy = never`. |
| redis.auth.existingSecret | string | `""` | Name of that Secret. Required while `redis.auth.enabled`. |
| redis.auth.existingSecretKey | string | `"redis-password"` | Key inside it. |
| redis.dataSizeLimit | string | `"1Gi"` | `emptyDir` at `/data`, never a PVC: nothing here survives the pod on purpose. |
| redis.enabled | bool | `false` | Only for an `image.tag` pinned back before 4.4.0, which is where MailFlow kept sessions and short-lived keys in Redis; 4.4.0 moved them to Postgres and ignores `REDIS_URL`. `true` deploys the Redis below and then also needs `redis.auth.existingSecret`; an external one goes in `backend.redisUrl` instead. The chart refuses to render a pre-4.4.0 tag with neither. |
| redis.image.digest | string | `"sha256:7f7d30b7fdd09467bac58198a1f166dd69789d348d4fe859cccb20e0cf287fbe"` | Digest `redis.image.tag` resolved to when it was pinned. Rendered as `<tag>@<digest>`, so the tag documents the version and the digest is what gets pulled. Change both together. Set to `""` to pull by tag instead. |
| redis.image.pullPolicy | string | `"IfNotPresent"` |  |
| redis.image.repository | string | `"redis"` |  |
| redis.image.tag | string | `"7.4.12-alpine3.22"` | A pinned patch release, not a moving `7-alpine`. |
| redis.livenessProbe.exec.command[0] | string | `"redis-cli"` |  |
| redis.livenessProbe.exec.command[1] | string | `"ping"` |  |
| redis.podSecurityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":999}` | uid 999 / gid 1000, the `redis` user in the image. Required, not hardening: at uid 0 the entrypoint takes its root branch and `chown`s `/data` then `gosu`s, both of which `drop: [ALL]` forbids, and it runs under `set -e`, so the container exits before `redis-server`. `fsGroup` is what makes the `emptyDir` writable for that gid. |
| redis.readinessProbe.exec.command[0] | string | `"redis-cli"` |  |
| redis.readinessProbe.exec.command[1] | string | `"ping"` |  |
| redis.resources | object | `{}` |  |
| redis.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| redis.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| redis.securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| redis.service.port | int | `6379` |  |
| redis.service.type | string | `"ClusterIP"` |  |
| redis.startupProbe | object | `{}` |  |
| tolerations | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| NigelVanHattum |  |  |
