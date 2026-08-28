{{/*
Expand the name of the chart.
*/}}
{{- define "paperclip.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "paperclip.fullname" -}}
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

{{- define "paperclip.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "paperclip.labels" -}}
helm.sh/chart: {{ include "paperclip.chart" . }}
{{ include "paperclip.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "paperclip.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperclip.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "paperclip.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "paperclip.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image reference. A digest always wins over a tag; the chart refuses to render
without one of the two (see paperclip.validate).
*/}}
{{- define "paperclip.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end }}

{{/*
Name of the chart-managed Secret holding inline sensitive values.
*/}}
{{- define "paperclip.secretName" -}}
{{ include "paperclip.fullname" . }}
{{- end }}

{{/* ------------------------------------------------------------------ */}}
{{/* Generic {value, existingSecret, existingSecretKey} plumbing         */}}
{{/* ------------------------------------------------------------------ */}}

{{/*
Render one env var from a {value, existingSecret, existingSecretKey} block.
Args (dict): "name", "cfg", "sensitive" bool, "secretName"/"secretKey" fallback
into the chart-managed Secret (only used when sensitive and no existingSecret).
*/}}
{{- define "paperclip.refEnv" -}}
{{- $cfg := .cfg -}}
- name: {{ .name }}
{{- if $cfg.existingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ $cfg.existingSecret }}
      key: {{ $cfg.existingSecretKey }}
{{- else if and .sensitive .secretName }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: {{ .secretKey }}
{{- else }}
  value: {{ $cfg.value | quote }}
{{- end }}
{{- end }}

{{/*
Validate a {value, existingSecret, existingSecretKey} block.
Args (dict): "field", "cfg", "required" bool.
*/}}
{{- define "paperclip.assertSecretRef" -}}
{{- $f := .field -}}
{{- $cfg := .cfg -}}
{{- if $cfg.existingSecret -}}
{{- if not $cfg.existingSecretKey -}}
{{- fail (printf "%s.existingSecretKey is required when %s.existingSecret is set" $f $f) -}}
{{- end -}}
{{- else if and .required (not $cfg.value) -}}
{{- fail (printf "%s.value or %s.existingSecret is required" $f $f) -}}
{{- end -}}
{{- end }}

{{/* ------------------------------------------------------------------ */}}
{{/* CloudNativePG                                                       */}}
{{/* ------------------------------------------------------------------ */}}

{{- define "paperclip.cnpg.clusterName" -}}
{{- if .Values.database.cnpg.clusterName -}}
{{ .Values.database.cnpg.clusterName }}
{{- else -}}
{{ include "paperclip.fullname" . }}-db
{{- end -}}
{{- end }}

{{/*
Secret CNPG generates for the application user. Contains username/password/
dbname/host/port plus a ready-made connection string under `uri`.
*/}}
{{- define "paperclip.cnpg.appSecretName" -}}
{{- if .Values.database.cnpg.appSecretName -}}
{{ .Values.database.cnpg.appSecretName }}
{{- else -}}
{{ include "paperclip.cnpg.clusterName" . }}-app
{{- end -}}
{{- end }}

{{- define "paperclip.cnpg.objectStoreName" -}}
{{- if .Values.database.cnpg.backups.objectStoreName -}}
{{ .Values.database.cnpg.backups.objectStoreName }}
{{- else -}}
{{ include "paperclip.cnpg.clusterName" . }}-backups
{{- end -}}
{{- end }}

{{- define "paperclip.cnpg.enabled" -}}
{{- if eq .Values.database.mode "cnpg" -}}true{{- end -}}
{{- end }}

{{/* ------------------------------------------------------------------ */}}
{{/* Database env                                                        */}}
{{/* ------------------------------------------------------------------ */}}

{{/*
External database is in component mode when neither a full url nor a full-url
existing secret is supplied, so DATABASE_URL is composed from the parts.
*/}}
{{- define "paperclip.externalDb.componentMode" -}}
{{- if and (not .Values.database.external.url) (not .Values.database.external.existingSecret) -}}
true
{{- end -}}
{{- end }}

{{- define "paperclip.database.secretName" -}}
{{- if .Values.database.external.existingSecret -}}
{{ .Values.database.external.existingSecret }}
{{- else -}}
{{ include "paperclip.secretName" . }}
{{- end -}}
{{- end }}

{{- define "paperclip.database.secretKey" -}}
{{- if .Values.database.external.existingSecret -}}
{{ .Values.database.external.existingSecretKey }}
{{- else -}}
database-url
{{- end -}}
{{- end }}

{{/*
DATABASE_URL, shared by the app container, the onboard init container and the
helm test pod. In component mode the URL is composed at runtime through $(VAR)
interpolation so a secret-sourced password is never written into the manifest.
*/}}
{{- define "paperclip.databaseEnv" -}}
{{- if include "paperclip.cnpg.enabled" . }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "paperclip.cnpg.appSecretName" . }}
      key: {{ .Values.database.cnpg.appSecretUriKey }}
{{- else if include "paperclip.externalDb.componentMode" . }}
{{- $db := .Values.database.external }}
{{- include "paperclip.refEnv" (dict "name" "PAPERCLIP_DB_HOST" "cfg" $db.host "sensitive" false) | nindent 0 }}
{{- include "paperclip.refEnv" (dict "name" "PAPERCLIP_DB_PORT" "cfg" $db.port "sensitive" false) | nindent 0 }}
{{- include "paperclip.refEnv" (dict "name" "PAPERCLIP_DB_NAME" "cfg" $db.database "sensitive" false) | nindent 0 }}
{{- include "paperclip.refEnv" (dict "name" "PAPERCLIP_DB_USER" "cfg" $db.username "sensitive" false) | nindent 0 }}
{{- include "paperclip.refEnv" (dict "name" "PAPERCLIP_DB_PASSWORD" "cfg" $db.password "sensitive" true "secretName" (include "paperclip.secretName" .) "secretKey" "database-password") | nindent 0 }}
- name: DATABASE_URL
  value: "postgresql://$(PAPERCLIP_DB_USER):$(PAPERCLIP_DB_PASSWORD)@$(PAPERCLIP_DB_HOST):$(PAPERCLIP_DB_PORT)/$(PAPERCLIP_DB_NAME)"
{{- else }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "paperclip.database.secretName" . }}
      key: {{ include "paperclip.database.secretKey" . }}
{{- end }}
{{- end }}

{{/* ------------------------------------------------------------------ */}}
{{/* Application env                                                     */}}
{{/* ------------------------------------------------------------------ */}}

{{/*
The app rejects requests whose Host header is not allow-listed in authenticated
mode. Always include the in-cluster Service DNS names and loopback so the helm
test pod and other in-cluster clients pass; ingress hosts are appended.
*/}}
{{- define "paperclip.allowedHostnames" -}}
{{- $fullname := include "paperclip.fullname" . -}}
{{- $ns := .Release.Namespace -}}
{{- $hosts := list "localhost" "127.0.0.1" $fullname (printf "%s.%s" $fullname $ns) (printf "%s.%s.svc" $fullname $ns) (printf "%s.%s.svc.cluster.local" $fullname $ns) -}}
{{- range .Values.ingress.hosts -}}
{{- $hosts = append $hosts .host -}}
{{- end -}}
{{- range .Values.deployment.allowedHostnames -}}
{{- $hosts = append $hosts . -}}
{{- end -}}
{{- $hosts | uniq | join "," -}}
{{- end }}

{{/*
Env shared by the app container and the onboard init container.
*/}}
{{- define "paperclip.appEnv" -}}
- name: PORT
  value: {{ .Values.service.port | quote }}
- name: PAPERCLIP_BIND
  value: "custom"
- name: PAPERCLIP_BIND_HOST
  value: "0.0.0.0"
- name: PAPERCLIP_HOME
  value: {{ .Values.persistence.mountPath | quote }}
- name: SERVE_UI
  value: "true"
- name: PAPERCLIP_DEPLOYMENT_MODE
  value: {{ .Values.deployment.mode | quote }}
- name: PAPERCLIP_DEPLOYMENT_EXPOSURE
  value: {{ .Values.deployment.exposure | quote }}
- name: PAPERCLIP_ALLOWED_HOSTNAMES
  value: {{ include "paperclip.allowedHostnames" . | quote }}
{{- with .Values.deployment.publicUrl }}
- name: PAPERCLIP_PUBLIC_URL
  value: {{ . | quote }}
{{- end }}
{{- if .Values.deployment.disableSignUp }}
- name: PAPERCLIP_AUTH_DISABLE_SIGN_UP
  value: "true"
{{- end }}
{{- include "paperclip.databaseEnv" . }}
{{- include "paperclip.refEnv" (dict "name" "BETTER_AUTH_SECRET" "cfg" .Values.auth.betterAuthSecret "sensitive" true "secretName" (include "paperclip.secretName" .) "secretKey" "BETTER_AUTH_SECRET") | nindent 0 }}
- name: PAPERCLIP_SECRETS_PROVIDER
  value: {{ .Values.secrets.provider | quote }}
{{- include "paperclip.refEnv" (dict "name" "PAPERCLIP_SECRETS_MASTER_KEY" "cfg" .Values.secrets.masterKey "sensitive" true "secretName" (include "paperclip.secretName" .) "secretKey" "PAPERCLIP_SECRETS_MASTER_KEY") | nindent 0 }}
{{- if .Values.secrets.strictMode }}
- name: PAPERCLIP_SECRETS_STRICT_MODE
  value: "true"
{{- end }}
{{- if not .Values.heartbeat.enabled }}
- name: HEARTBEAT_SCHEDULER_ENABLED
  value: "false"
{{- end }}
{{- if .Values.heartbeat.intervalMs }}
- name: HEARTBEAT_SCHEDULER_INTERVAL_MS
  value: {{ .Values.heartbeat.intervalMs | quote }}
{{- end }}
{{- range $key, $val := .Values.secretEnv }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ include "paperclip.secretName" $ }}
      key: {{ $key }}
{{- end }}
{{- range $key, $ref := .Values.secretEnvFrom }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ required (printf "secretEnvFrom.%s.existingSecret is required" $key) $ref.existingSecret }}
      key: {{ required (printf "secretEnvFrom.%s.key is required" $key) $ref.key }}
{{- end }}
{{- with .Values.extraEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Container command. The image ENTRYPOINT (docker-entrypoint.sh) gosu-drops to the
"node" user, which fails under runAsNonRoot + drop ALL; exec the server directly
instead. At replicas > 1 the ordinal wrapper pins the heartbeat scheduler to
pod-0, because the app has no lease-based leader election.
*/}}
{{- define "paperclip.serverCommand" -}}
{{- $script := printf "exec %s" .Values.entrypoint -}}
{{- if and .Values.heartbeat.enabled (gt (int .Values.replicaCount) 1) -}}
{{- $script = printf "case \"$HOSTNAME\" in *-0) export HEARTBEAT_SCHEDULER_ENABLED=true ;; *) export HEARTBEAT_SCHEDULER_ENABLED=false ;; esac; %s" $script -}}
{{- end -}}
{{ $script }}
{{- end }}

{{/*
Probes. /api/health returns 403 in authenticated mode, so an HTTP probe fails
permanently there; "auto" resolves to TCP for that mode.
*/}}
{{- define "paperclip.useTcpProbes" -}}
{{- if eq .Values.probes.type "tcp" -}}
true
{{- else if and (eq .Values.probes.type "auto") (eq .Values.deployment.mode "authenticated") -}}
true
{{- end -}}
{{- end }}

{{- define "paperclip.probeHandler" -}}
{{- if include "paperclip.useTcpProbes" . -}}
tcpSocket:
  port: http
{{- else -}}
httpGet:
  path: {{ .Values.probes.path }}
  port: http
  scheme: HTTP
{{- end -}}
{{- end }}

{{/*
Image for the wait-for-database init container. An empty tag follows the
PostgreSQL major the CloudNativePG cluster runs, so both move together.
*/}}
{{- define "paperclip.waitForDatabase.image" -}}
{{- $tag := .Values.waitForDatabase.image.tag | default .Values.database.cnpg.postgresqlVersion -}}
{{ .Values.waitForDatabase.image.repository }}:{{ $tag }}
{{- end }}
