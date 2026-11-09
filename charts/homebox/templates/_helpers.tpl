{{/*
Expand the name of the chart.
*/}}
{{- define "homebox.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "homebox.fullname" -}}
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
{{- define "homebox.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "homebox.labels" -}}
helm.sh/chart: {{ include "homebox.chart" . }}
{{ include "homebox.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "homebox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homebox.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
The container image: image.tag wins, else the appVersion with the variant suffix.
*/}}
{{- define "homebox.image" -}}
{{- $tag := .Values.image.tag | default (printf "%s%s" .Chart.AppVersion .Values.image.variant) -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/*
Name of the Secret every sensitive env var is read from: the external one when
homebox.existingSecret is set, otherwise the Secret this chart renders.
*/}}
{{- define "homebox.secretName" -}}
{{- .Values.homebox.existingSecret | default (include "homebox.fullname" .) }}
{{- end }}

{{/*
Key inside that Secret for one logical value. The chart's own Secret always uses the
default names; homebox.existingSecretKeys only overrides them for an external Secret.

  {{ include "homebox.secretKey" (dict "root" . "key" "apiKeyPepper") }}
*/}}
{{- define "homebox.secretKey" -}}
{{- $defaults := dict
  "apiKeyPepper" "api-key-pepper"
  "databasePassword" "database-password"
  "oidcClientSecret" "oidc-client-secret"
  "mailerPassword" "mailer-password"
  "s3AccessKeyId" "s3-access-key-id"
  "s3SecretAccessKey" "s3-secret-access-key" -}}
{{- $default := get $defaults .key -}}
{{- if .root.Values.homebox.existingSecret -}}
{{- get (.root.Values.homebox.existingSecretKeys | default dict) .key | default $default -}}
{{- else -}}
{{- $default -}}
{{- end -}}
{{- end }}

{{/*
Every guardrail that has to hold before anything renders. The application exits on a
pepper shorter than 32 bytes and on a postgres driver without a host, so the chart
refuses to render those instead of shipping a CrashLoopBackOff.
*/}}
{{- define "homebox.validate" -}}
{{- $db := .Values.homebox.database -}}
{{- $data := .Values.homebox.persistence.data -}}
{{- if not (has .Values.type (list "Deployment" "StatefulSet")) -}}
{{- fail (printf "type must be Deployment or StatefulSet, got %q" .Values.type) -}}
{{- end -}}
{{- if and (eq .Values.type "Deployment") $data.enabled (not $data.useExistingPvc) -}}
{{- fail "type=Deployment cannot claim a volume: set homebox.persistence.data.useExistingPvc, or disable homebox.persistence.data.enabled (postgres plus S3 storage)" -}}
{{- end -}}
{{- $reserved := list "HBOX_AUTH_API_KEY_PEPPER" "HBOX_DATABASE_PASSWORD" "HBOX_OIDC_CLIENT_SECRET" "HBOX_MAILER_PASSWORD" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" -}}
{{- range $key := keys (.Values.homebox.config | default dict) -}}
{{- if has $key $reserved -}}
{{- fail (printf "homebox.config.%s is a secret the chart reads through secretKeyRef: a plain value there lands in the workload spec; use the homebox.* value or homebox.existingSecret" $key) -}}
{{- end -}}
{{- end -}}
{{- $conn := toString (index .Values.homebox.config "HBOX_STORAGE_CONN_STRING" | default "") -}}
{{- $s3 := .Values.homebox.storage.s3 -}}
{{- if and (hasPrefix "s3://" $conn) (not .Values.homebox.existingSecret) (or (not $s3.accessKeyId) (not $s3.secretAccessKey)) -}}
{{- fail "an s3:// HBOX_STORAGE_CONN_STRING needs homebox.storage.s3.accessKeyId and secretAccessKey, or homebox.existingSecret carrying them" -}}
{{- end -}}
{{- $remoteStorage := false -}}
{{- range $scheme := list "s3://" "gcs://" "azblob://" -}}
{{- if hasPrefix $scheme $conn -}}
{{- $remoteStorage = true -}}
{{- end -}}
{{- end -}}
{{- if not $data.enabled -}}
{{- if eq $db.driver "sqlite3" -}}
{{- fail "homebox.persistence.data.enabled=false needs homebox.database.driver=postgres: the sqlite database lives under /data, which nothing mounts then, on a read-only root filesystem" -}}
{{- end -}}
{{- if not $remoteStorage -}}
{{- fail "homebox.persistence.data.enabled=false needs an s3://, gcs:// or azblob:// HBOX_STORAGE_CONN_STRING: file:// storage writes under /data, which nothing mounts then, on a read-only root filesystem" -}}
{{- end -}}
{{- end -}}
{{- if not (has $db.driver (list "sqlite3" "postgres")) -}}
{{- fail (printf "homebox.database.driver must be sqlite3 or postgres, got %q" $db.driver) -}}
{{- end -}}
{{- if and (eq $db.driver "postgres") (not $db.host) -}}
{{- fail "homebox.database.driver=postgres needs homebox.database.host" -}}
{{- end -}}
{{- if not .Values.homebox.existingSecret -}}
{{- $pepper := .Values.homebox.auth.apiKeyPepper -}}
{{- if not $pepper -}}
{{- fail "homebox.auth.apiKeyPepper is required: set it (at least 32 bytes, `openssl rand -base64 48`) or point homebox.existingSecret at a Secret holding it" -}}
{{- end -}}
{{- if lt (len $pepper) 32 -}}
{{- fail (printf "homebox.auth.apiKeyPepper must be at least 32 bytes, got %d: Homebox refuses to start on a shorter one" (len $pepper)) -}}
{{- end -}}
{{- end -}}
{{- end }}
