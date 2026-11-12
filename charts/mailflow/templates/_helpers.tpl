{{/*
Expand the name of the chart.
*/}}
{{- define "mailflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mailflow.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mailflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mailflow.labels" -}}
helm.sh/chart: {{ include "mailflow.chart" . }}
{{ include "mailflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mailflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mailflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of one component's workload and Service.

  {{ include "mailflow.componentName" (dict "root" . "component" "backend") }}
*/}}
{{- define "mailflow.componentName" -}}
{{- printf "%s-%s" (include "mailflow.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Selector labels for one component. The three workloads share the name and instance labels, so
the component label is what keeps their selectors apart.
*/}}
{{- define "mailflow.componentSelectorLabels" -}}
{{ include "mailflow.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Common labels for one component.
*/}}
{{- define "mailflow.componentLabels" -}}
{{ include "mailflow.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
The backend and frontend images: image.tag wins, else the chart appVersion. Both move
together because upstream releases them together.
*/}}
{{- define "mailflow.backendImage" -}}
{{- printf "%s:%s" .Values.backend.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end }}

{{- define "mailflow.frontendImage" -}}
{{- printf "%s:%s" .Values.frontend.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end }}

{{/*
Whether the Redis this chart deploys takes a requirepass. Empty output is false to `if`.
An external Redis (redis.enabled: false) carries its own credential in backend.redisUrl.
*/}}
{{- define "mailflow.redisAuth" -}}
{{- if and .Values.redis.enabled .Values.redis.auth.enabled -}}
yes
{{- end -}}
{{- end }}

{{- define "mailflow.redisSecretKey" -}}
{{- .Values.redis.auth.existingSecretKey | default "redis-password" -}}
{{- end }}

{{/*
Whether the backend gets REDIS_PASSWORD from the Secret. Independent of redis.enabled: an
external Redis needs the same escape from a literal password in the pod spec, and the chart
renders the variable ahead of REDIS_URL so $(REDIS_PASSWORD) works inside backend.redisUrl too.
Empty output is false to `if`.
*/}}
{{- define "mailflow.backendRedisPassword" -}}
{{- if and .Values.redis.auth.enabled .Values.redis.auth.existingSecret -}}
yes
{{- end -}}
{{- end }}

{{/*
REDIS_URL: the Redis this chart deploys, unless backend.redisUrl names another one.
$(REDIS_PASSWORD) is expanded by the kubelet from the env var declared before this one, so the
password reaches the URL without the Secret's value ever entering the pod spec.
*/}}
{{- define "mailflow.redisUrl" -}}
{{- if .Values.backend.redisUrl -}}
{{- .Values.backend.redisUrl -}}
{{- else -}}
{{- $host := include "mailflow.componentName" (dict "root" . "component" "redis") -}}
{{- if include "mailflow.backendRedisPassword" . -}}
{{- printf "redis://:$(REDIS_PASSWORD)@%s:%v" $host .Values.redis.service.port -}}
{{- else -}}
{{- printf "redis://%s:%v" $host .Values.redis.service.port -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
BACKEND_HOST: this release's backend Service, unless frontend.backendHost names another one.
*/}}
{{- define "mailflow.backendHost" -}}
{{- .Values.frontend.backendHost | default (include "mailflow.componentName" (dict "root" . "component" "backend")) -}}
{{- end }}

{{/*
Whether backend.env carries APP_URL, for the note that says what is missing without it.
Empty output is false to `if`.
*/}}
{{- define "mailflow.hasAppUrl" -}}
{{- range .Values.backend.env | default list -}}
{{- if eq (.name | default "") "APP_URL" -}}
yes
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Every guardrail that has to hold before anything renders. A duplicate name in a raw env list
would leave the winner to the kubelet, and a plain secret value would land in the workload
spec, which ClusterRole view reads. README: "Configuration" and "Secrets".
*/}}
{{- define "mailflow.validate" -}}
{{- $managed := dict
  "backend" (list "NODE_ENV" "PORT" "REDIS_URL" "REDIS_PASSWORD" "IMAGE_CACHE_DIR")
  "frontend" (list "NGINX_TLS" "TLS_MODE" "BACKEND_HOST" "BACKEND_PORT") -}}
{{- $hint := dict
  "NODE_ENV" "the chart pins it to production"
  "PORT" "backend.service.port"
  "REDIS_URL" "backend.redisUrl"
  "REDIS_PASSWORD" "redis.auth.existingSecret, which the chart renders ahead of REDIS_URL so $(REDIS_PASSWORD) resolves inside backend.redisUrl as well - an entry here would land after it and never expand"
  "IMAGE_CACHE_DIR" "imageCache.path"
  "NGINX_TLS" "frontend.nginxTls"
  "TLS_MODE" "frontend.tlsMode"
  "BACKEND_HOST" "frontend.backendHost"
  "BACKEND_PORT" "backend.service.port" -}}
{{- $secrets := list "SESSION_SECRET" "DB_PASSWORD" "ENCRYPTION_KEY" "VAPID_PRIVATE_KEY" "MS_CLIENT_SECRET" "GOOGLE_CLIENT_SECRET" -}}
{{- range $component := list "backend" "frontend" -}}
{{- range $entry := (index $.Values $component).env | default list -}}
{{- $name := $entry.name | default "" -}}
{{- if has $name (get $managed $component) -}}
{{- fail (printf "%s.env sets %s, which this chart derives: use %s" $component $name (get $hint $name)) -}}
{{- end -}}
{{- if and (has $name $secrets) (hasKey $entry "value") -}}
{{- fail (printf "%s.env sets %s as a plain value, which lands in the workload spec: use valueFrom.secretKeyRef, pointing at a Secret Terraform owns" $component $name) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and (not .Values.redis.enabled) (not .Values.backend.redisUrl) -}}
{{- fail "redis.enabled=false needs backend.redisUrl: MailFlow keeps sessions in Redis and will not start without it" -}}
{{- end -}}
{{- if and (contains "$(REDIS_PASSWORD)" (.Values.backend.redisUrl | toString)) (not (include "mailflow.backendRedisPassword" .)) -}}
{{- fail "backend.redisUrl references $(REDIS_PASSWORD) but nothing defines it: set redis.auth.existingSecret (and keep redis.auth.enabled), or the literal string reaches Redis as the password" -}}
{{- end -}}
{{- if and (include "mailflow.redisAuth" .) (not .Values.redis.auth.existingSecret) -}}
{{- fail "redis.auth.existingSecret is required: Redis holds MailFlow's sessions, a session is mailbox access, and nothing in front of port 6379 asks for a credential. Point it at a Secret carrying the password, or set redis.auth.enabled=false to accept an open Redis" -}}
{{- end -}}
{{- if not .Values.imageCache.path -}}
{{- fail "imageCache.path is required: it is both IMAGE_CACHE_DIR and the emptyDir mount path" -}}
{{- end -}}
{{- end }}
