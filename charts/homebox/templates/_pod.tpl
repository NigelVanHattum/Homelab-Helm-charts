{{/*
The pod template both workload kinds render, so the Deployment and the StatefulSet can never
drift apart. Included with the root context and indented by the caller.
*/}}
{{- define "homebox.podTemplate" -}}
{{- $data := .Values.homebox.persistence.data -}}
{{- $db := .Values.homebox.database -}}
{{- $s3 := .Values.homebox.storage.s3 -}}
{{- $hasSecret := or .Values.homebox.existingSecret false -}}
metadata:
  {{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "homebox.labels" . | nindent 4 }}
  {{- with .Values.podLabels }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: {{ .Chart.Name }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      image: {{ include "homebox.image" . | quote }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      env:
        - name: HBOX_AUTH_API_KEY_PEPPER
          valueFrom:
            secretKeyRef:
              name: {{ include "homebox.secretName" . }}
              key: {{ include "homebox.secretKey" (dict "root" . "key" "apiKeyPepper") }}
        - name: HBOX_DATABASE_DRIVER
          value: {{ $db.driver | quote }}
{{- if eq $db.driver "postgres" }}
        - name: HBOX_DATABASE_HOST
          value: {{ $db.host | quote }}
        - name: HBOX_DATABASE_PORT
          value: {{ $db.port | quote }}
        - name: HBOX_DATABASE_USERNAME
          value: {{ $db.username | quote }}
        - name: HBOX_DATABASE_DATABASE
          value: {{ $db.database | quote }}
        - name: HBOX_DATABASE_SSL_MODE
          value: {{ $db.sslMode | quote }}
{{- if or $hasSecret $db.password }}
        - name: HBOX_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "homebox.secretName" . }}
              key: {{ include "homebox.secretKey" (dict "root" . "key" "databasePassword") }}
{{- end }}
{{- end }}
{{- if or $hasSecret $s3.accessKeyId }}
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: {{ include "homebox.secretName" . }}
              key: {{ include "homebox.secretKey" (dict "root" . "key" "s3AccessKeyId") }}
              optional: true
{{- end }}
{{- if or $hasSecret $s3.secretAccessKey }}
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: {{ include "homebox.secretName" . }}
              key: {{ include "homebox.secretKey" (dict "root" . "key" "s3SecretAccessKey") }}
              optional: true
{{- end }}
{{- if or $hasSecret .Values.homebox.oidc.clientSecret }}
        - name: HBOX_OIDC_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: {{ include "homebox.secretName" . }}
              key: {{ include "homebox.secretKey" (dict "root" . "key" "oidcClientSecret") }}
              optional: true
{{- end }}
{{- if or $hasSecret .Values.homebox.mailer.password }}
        - name: HBOX_MAILER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "homebox.secretName" . }}
              key: {{ include "homebox.secretKey" (dict "root" . "key" "mailerPassword") }}
              optional: true
{{- end }}
{{- range $name, $value := .Values.homebox.config }}
        - name: {{ $name }}
          value: {{ $value | quote }}
{{- end }}
{{- with .Values.homebox.extraEnv }}
        {{- toYaml . | nindent 8 }}
{{- end }}
      ports:
        - name: http
          containerPort: {{ .Values.homebox.config.HBOX_WEB_PORT | default 7745 }}
          protocol: TCP
      {{- with .Values.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
{{- if $data.enabled }}
        - name: data
          mountPath: /data
{{- end }}
        - name: tmp
          mountPath: /tmp
      {{- with .Values.volumeMounts }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
  volumes:
    - name: tmp
      emptyDir: {}
{{- if and $data.enabled $data.useExistingPvc }}
    - name: data
      persistentVolumeClaim:
        claimName: {{ $data.useExistingPvc }}
{{- end }}
  {{- with .Values.volumes }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
