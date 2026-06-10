{{/*
Expand the name of the chart.
*/}}
{{- define "influxdb3-core.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "influxdb3-core.fullname" -}}
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
{{- define "influxdb3-core.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "influxdb3-core.labels" -}}
helm.sh/chart: {{ include "influxdb3-core.chart" . }}
{{ include "influxdb3-core.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "influxdb3-core.selectorLabels" -}}
app.kubernetes.io/name: {{ include "influxdb3-core.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Server (core) selector labels - selectorLabels plus a component label so the
Core Service does not also match the Explorer pods (same name/instance).
Used for the Service/ServiceMonitor/NetworkPolicy selectors and the pod labels.
NOTE: deliberately NOT used for the StatefulSet .spec.selector, which is
immutable - existing installs upgrade with a rolling restart (the pod just
gains the component label) instead of requiring a recreate.
*/}}
{{- define "influxdb3-core.server.selectorLabels" -}}
{{ include "influxdb3-core.selectorLabels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Service account name
*/}}
{{- define "influxdb3-core.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "influxdb3-core.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Object storage secret name
*/}}
{{- define "influxdb3-core.objectStorageSecretName" -}}
{{- $type := .Values.objectStorage.type | default "file" -}}
{{- $defaultSecret := printf "%s-object-storage" (include "influxdb3-core.fullname" .) -}}
{{- if eq $type "s3" -}}
{{- $s3 := .Values.objectStorage.s3 | default dict -}}
{{- get $s3 "existingSecret" | default $defaultSecret -}}
{{- else if eq $type "azure" -}}
{{- $azure := .Values.objectStorage.azure | default dict -}}
{{- get $azure "existingSecret" | default $defaultSecret -}}
{{- else if eq $type "google" -}}
{{- $google := .Values.objectStorage.google | default dict -}}
{{- get $google "existingSecret" | default $defaultSecret -}}
{{- else -}}
{{- $defaultSecret -}}
{{- end -}}
{{- end }}

{{/*
Validate object storage type
*/}}
{{- define "influxdb3-core.validateObjectStorageType" -}}
{{- $type := default "file" .Values.objectStorage.type -}}
{{- $valid := list "s3" "azure" "google" "file" "memory" "memory-throttled" -}}
{{- if not (has $type $valid) -}}
{{- fail (printf "Invalid objectStorage.type: %s. Must be one of: %s" $type (join ", " $valid)) -}}
{{- end -}}
{{- end }}

{{/*
Validate Azure object storage auth config
*/}}
{{- define "influxdb3-core.validateAzureObjectStorageAuth" -}}
{{- if eq .Values.objectStorage.type "azure" -}}
{{- $azure := .Values.objectStorage.azure | default dict -}}
{{- $existingSecret := get $azure "existingSecret" | default "" -}}
{{- $storageAccount := get $azure "storageAccount" | default "" -}}
{{- $accessKey := get $azure "accessKey" | default "" -}}
{{- if not $existingSecret -}}
{{- if not (and $storageAccount $accessKey) -}}
{{- fail "When objectStorage.type=azure and objectStorage.azure.existingSecret is not set, both objectStorage.azure.storageAccount and objectStorage.azure.accessKey must be set." -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate S3 object storage auth config
*/}}
{{- define "influxdb3-core.validateS3ObjectStorageAuth" -}}
{{- if eq .Values.objectStorage.type "s3" -}}
{{- $s3 := .Values.objectStorage.s3 | default dict -}}
{{- $existingSecret := get $s3 "existingSecret" | default "" -}}
{{- $accessKeyID := get $s3 "accessKeyId" | default "" -}}
{{- $secretAccessKey := get $s3 "secretAccessKey" | default "" -}}
{{- $sessionToken := get $s3 "sessionToken" | default "" -}}
{{- if and (not $existingSecret) (or (and $accessKeyID (not $secretAccessKey)) (and (not $accessKeyID) $secretAccessKey)) -}}
{{- fail "When objectStorage.type=s3, objectStorage.s3.accessKeyId and objectStorage.s3.secretAccessKey must be set together." -}}
{{- end -}}
{{- if and (not $existingSecret) $sessionToken (not (and $accessKeyID $secretAccessKey)) -}}
{{- fail "When objectStorage.type=s3 and objectStorage.s3.sessionToken is set, both objectStorage.s3.accessKeyId and objectStorage.s3.secretAccessKey must also be set." -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate Google object storage auth config
*/}}
{{- define "influxdb3-core.validateGoogleObjectStorageAuth" -}}
{{- if eq .Values.objectStorage.type "google" -}}
{{- $google := .Values.objectStorage.google | default dict -}}
{{- $existingSecret := get $google "existingSecret" | default "" -}}
{{- $serviceAccountJSON := get $google "serviceAccountJson" | default "" -}}
{{- if not (or $existingSecret $serviceAccountJSON) -}}
{{- fail "When objectStorage.type=google, set either objectStorage.google.existingSecret or objectStorage.google.serviceAccountJson." -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate object store TLS CA config
*/}}
{{- define "influxdb3-core.validateObjectStoreTlsCa" -}}
{{- $tlsCa := .Values.objectStorage.tlsCa | default dict -}}
{{- $certPath := get $tlsCa "certPath" | default "" -}}
{{- $existingSecret := get $tlsCa "existingSecret" | default "" -}}
{{- if and $certPath $existingSecret -}}
{{- fail "Set only one of objectStorage.tlsCa.certPath or objectStorage.tlsCa.existingSecret." -}}
{{- end -}}
{{- end }}

{{/*
Validate admin token bootstrap config
*/}}
{{- define "influxdb3-core.validateAdminTokenConfig" -}}
{{- $security := .Values.security | default dict -}}
{{- $auth := get $security "auth" | default dict -}}
{{- $adminToken := get $auth "adminToken" | default dict -}}
{{- $existingSecret := get $adminToken "existingSecret" | default "" -}}
{{- $adminTokenFile := get $adminToken "file" | default "" -}}
{{- if and $existingSecret $adminTokenFile -}}
{{- fail "Set only one of security.auth.adminToken.existingSecret or security.auth.adminToken.file." -}}
{{- end -}}
{{- end }}

{{/*
TLS secret name
*/}}
{{- define "influxdb3-core.tlsSecretName" -}}
{{- if .Values.security.tls.existingSecret }}
{{- .Values.security.tls.existingSecret }}
{{- else }}
{{- include "influxdb3-core.fullname" . }}-tls
{{- end }}
{{- end }}

{{- define "influxdb3-core.objectStoreSecretEnv" -}}
{{- $objectStoreSecretName := include "influxdb3-core.objectStorageSecretName" . }}
{{- if eq .Values.objectStorage.type "s3" }}
  {{- $s3 := .Values.objectStorage.s3 | default dict }}
  {{- $s3ExistingSecret := get $s3 "existingSecret" | default "" }}
  {{- $s3AccessKeyID := get $s3 "accessKeyId" | default "" }}
  {{- $s3SecretAccessKey := get $s3 "secretAccessKey" | default "" }}
  {{- if or $s3ExistingSecret (and $s3AccessKeyID $s3SecretAccessKey) }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ $objectStoreSecretName }}
      key: access-key-id
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $objectStoreSecretName }}
      key: secret-access-key
- name: AWS_SESSION_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ $objectStoreSecretName }}
      key: session-token
      optional: true
  {{- end }}
{{- else if eq .Values.objectStorage.type "azure" }}
  {{- $azure := .Values.objectStorage.azure | default dict }}
  {{- $azureExistingSecret := get $azure "existingSecret" | default "" }}
  {{- $azureStorageAccount := get $azure "storageAccount" | default "" }}
  {{- $azureAccessKey := get $azure "accessKey" | default "" }}
  {{- if $azureExistingSecret }}
- name: AZURE_STORAGE_ACCOUNT
  valueFrom:
    secretKeyRef:
      name: {{ $objectStoreSecretName }}
      key: storage-account
- name: AZURE_STORAGE_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $objectStoreSecretName }}
      key: access-key
  {{- else if $azureStorageAccount }}
- name: AZURE_STORAGE_ACCOUNT
  value: {{ $azureStorageAccount | quote }}
  {{- if $azureAccessKey }}
- name: AZURE_STORAGE_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $objectStoreSecretName }}
      key: access-key
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Preconfigured admin token environment
*/}}
{{- define "influxdb3-core.adminTokenEnv" -}}
{{- $security := .Values.security | default dict -}}
{{- $auth := get $security "auth" | default dict -}}
{{- $adminToken := get $auth "adminToken" | default dict -}}
{{- $adminTokenFile := get $adminToken "file" | default "" -}}
{{- if get $adminToken "existingSecret" }}
- name: INFLUXDB3_ADMIN_TOKEN_FILE
  value: "/etc/influxdb/admin-token/admin-token.json"
{{- else if $adminTokenFile }}
- name: INFLUXDB3_ADMIN_TOKEN_FILE
  value: {{ $adminTokenFile | quote }}
{{- end }}
{{- end }}

{{/*
Probe configuration
*/}}
{{- define "influxdb3-core.probes" -}}
{{- if .Values.probes.enabled }}
livenessProbe:
  httpGet:
    path: /health
    port: http
    {{- if .Values.security.tls.enabled }}
    scheme: HTTPS
    {{- end }}
  initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
  periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
  timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds }}
  failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
readinessProbe:
  httpGet:
    path: /health
    port: http
    {{- if .Values.security.tls.enabled }}
    scheme: HTTPS
    {{- end }}
  initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
  periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
  timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
  failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
startupProbe:
  httpGet:
    path: /health
    port: http
    {{- if .Values.security.tls.enabled }}
    scheme: HTTPS
    {{- end }}
  initialDelaySeconds: {{ .Values.probes.startup.initialDelaySeconds }}
  periodSeconds: {{ .Values.probes.startup.periodSeconds }}
  timeoutSeconds: {{ .Values.probes.startup.timeoutSeconds }}
  failureThreshold: {{ .Values.probes.startup.failureThreshold }}
{{- end }}
{{- end }}

{{/*
Image reference
*/}}
{{- define "influxdb3-core.image" -}}
{{- $registry := .Values.image.registry }}
{{- $repository := .Values.image.repository }}
{{- $tag := .Values.image.tag | default (printf "%s-core" .Chart.AppVersion) }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}

{{/*
Shared volume mounts (object storage credentials/TLS and user extras)
*/}}
{{- define "influxdb3-core.sharedVolumeMounts" -}}
{{- if eq .Values.objectStorage.type "google" }}
- name: google-service-account
  mountPath: /var/secrets/google
  readOnly: true
{{- end }}
{{- $s3 := .Values.objectStorage.s3 | default dict }}
{{- if and (eq .Values.objectStorage.type "s3") (get $s3 "credentialsFile") }}
- name: aws-credentials
  mountPath: /etc/influxdb/aws
  readOnly: true
{{- end }}
{{- if .Values.security.tls.enabled }}
- name: tls
  mountPath: /etc/influxdb/tls
  readOnly: true
{{- end }}
{{- $tlsCa := .Values.objectStorage.tlsCa | default dict }}
{{- if get $tlsCa "existingSecret" }}
- name: object-store-ca
  mountPath: /etc/influxdb/object-store-ca
  readOnly: true
{{- end }}
{{- with .Values.extraVolumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Admin token volume mounts
*/}}
{{- define "influxdb3-core.adminTokenVolumeMounts" -}}
{{- $security := .Values.security | default dict -}}
{{- $auth := get $security "auth" | default dict -}}
{{- $adminToken := get $auth "adminToken" | default dict -}}
{{- if get $adminToken "existingSecret" }}
- name: admin-token
  mountPath: /etc/influxdb/admin-token
  readOnly: true
{{- end }}
{{- end }}

{{/*
Shared volumes (object storage credentials/TLS and user extras)
*/}}
{{- define "influxdb3-core.sharedVolumes" -}}
{{- if eq .Values.objectStorage.type "google" }}
- name: google-service-account
  secret:
    secretName: {{ include "influxdb3-core.objectStorageSecretName" . }}
    items:
      - key: service-account.json
        path: service-account.json
{{- end }}
{{- $s3 := .Values.objectStorage.s3 | default dict }}
{{- if and (eq .Values.objectStorage.type "s3") (get $s3 "credentialsFile") }}
- name: aws-credentials
  secret:
    secretName: {{ include "influxdb3-core.fullname" . }}-aws-credentials
    items:
      - key: credentials
        path: credentials
{{- end }}
{{- if .Values.security.tls.enabled }}
- name: tls
  secret:
    secretName: {{ include "influxdb3-core.tlsSecretName" . }}
{{- end }}
{{- $tlsCa := .Values.objectStorage.tlsCa | default dict }}
{{- if get $tlsCa "existingSecret" }}
- name: object-store-ca
  secret:
    secretName: {{ get $tlsCa "existingSecret" }}
    items:
      - key: ca.crt
        path: ca.crt
{{- end }}
{{- with .Values.extraVolumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Admin token volumes
*/}}
{{- define "influxdb3-core.adminTokenVolumes" -}}
{{- $security := .Values.security | default dict -}}
{{- $auth := get $security "auth" | default dict -}}
{{- $adminToken := get $auth "adminToken" | default dict -}}
{{- if get $adminToken "existingSecret" }}
- name: admin-token
  secret:
    secretName: {{ get $adminToken "existingSecret" }}
    items:
      - key: admin-token.json
        path: admin-token.json
{{- end }}
{{- end }}

{{/*
=============================================================================
InfluxDB 3 Explorer (web UI) helpers
=============================================================================
*/}}

{{/*
Explorer fully qualified name
*/}}
{{- define "influxdb3-core.explorer.fullname" -}}
{{- printf "%s-explorer" (include "influxdb3-core.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Explorer selector labels
*/}}
{{- define "influxdb3-core.explorer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "influxdb3-core.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: explorer
{{- end }}

{{/*
Explorer common labels
*/}}
{{- define "influxdb3-core.explorer.labels" -}}
helm.sh/chart: {{ include "influxdb3-core.chart" . }}
{{ include "influxdb3-core.explorer.selectorLabels" . }}
{{- if .Values.explorer.image.tag }}
app.kubernetes.io/version: {{ .Values.explorer.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Explorer image reference
*/}}
{{- define "influxdb3-core.explorer.image" -}}
{{- $registry := .Values.explorer.image.registry }}
{{- $repository := .Values.explorer.image.repository }}
{{- $tag := .Values.explorer.image.tag | default "latest" }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}

{{/*
Explorer default server URL (in-cluster Core service) when not overridden
*/}}
{{- define "influxdb3-core.explorer.serverUrl" -}}
{{- $conn := .Values.explorer.connection | default dict -}}
{{- $server := get $conn "server" | default "" -}}
{{- if $server -}}
{{- $server -}}
{{- else -}}
{{- $scheme := ternary "https" "http" .Values.security.tls.enabled -}}
{{- printf "%s://%s:%v" $scheme (include "influxdb3-core.fullname" .) .Values.service.port -}}
{{- end -}}
{{- end }}

{{/*
Explorer config secret name (holds the connection API token)
*/}}
{{- define "influxdb3-core.explorer.tokenSecretName" -}}
{{- $conn := .Values.explorer.connection | default dict -}}
{{- $existing := get $conn "existingSecret" | default "" -}}
{{- if $existing -}}
{{- $existing -}}
{{- else -}}
{{- printf "%s-connection" (include "influxdb3-core.explorer.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Explorer session secret name
*/}}
{{- define "influxdb3-core.explorer.sessionSecretName" -}}
{{- $session := .Values.explorer.sessionSecret | default dict -}}
{{- $existing := get $session "existingSecret" | default "" -}}
{{- if $existing -}}
{{- $existing -}}
{{- else -}}
{{- printf "%s-session" (include "influxdb3-core.explorer.fullname" .) -}}
{{- end -}}
{{- end }}
