{{/*
Expand the name of the chart.
*/}}
{{- define "paperless-ngx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "paperless-ngx.fullname" -}}
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
{{- define "paperless-ngx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "paperless-ngx.labels" -}}
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{ include "paperless-ngx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "paperless-ngx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}

{{/*
Name of the Secret every sensitive env var is read from: the external one when
paperless.existingSecret is set, otherwise the Secret this chart renders.
*/}}
{{- define "paperless-ngx.secretName" -}}
{{- .Values.paperless.existingSecret | default (include "paperless-ngx.fullname" .) }}
{{- end }}

{{/*
Key inside that Secret for one logical value. The chart's own Secret always uses the
default names; paperless.existingSecretKeys only overrides them for an external Secret.

  {{ include "paperless-ngx.secretKey" (dict "root" . "key" "adminPassword") }}
*/}}
{{- define "paperless-ngx.secretKey" -}}
{{- $defaults := dict
  "adminPassword" "admin-password"
  "secretKey" "secret-key"
  "dbPassword" "db-password"
  "socialaccountProviders" "socialaccount-providers" -}}
{{- $default := get $defaults .key -}}
{{- if .root.Values.paperless.existingSecret -}}
{{- get (.root.Values.paperless.existingSecretKeys | default dict) .key | default $default -}}
{{- else -}}
{{- $default -}}
{{- end -}}
{{- end }}

{{/*
The PAPERLESS_SOCIALACCOUNT_PROVIDERS document. It carries the OIDC client secret, so it
only ever goes into a Secret - never into an env value in the pod spec.
*/}}
{{- define "paperless-ngx.socialaccountProviders" -}}
{{- $serverUrl := .Values.paperless.authentik.oidcWellKnownUrl | default (printf "https://%s/application/o/%s/.well-known/openid-configuration"
  .Values.paperless.authentik.domain
  .Values.paperless.authentik.applicationSlug) -}}
{{- printf `{"openid_connect": {"OAUTH_PKCE_ENABLED": true, "APPS": [{"provider_id": "authentik", "name": "authentik", "client_id": "%s", "secret": "%s", "settings": {"server_url": "%s", "fetch_userinfo": true}}], "SCOPE": ["openid", "profile", "email"]}}` .Values.paperless.authentik.clientId .Values.paperless.authentik.clientSecret $serverUrl -}}
{{- end }}

