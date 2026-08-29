{{/*
Fail fast on missing or inconsistent configuration. Included from configmap.yaml
so it runs on every render.
*/}}
{{- define "paperclip.validate" -}}

{{- /* Image */ -}}
{{- if not .Values.image.repository -}}
{{- fail "image.repository is required" -}}
{{- end -}}
{{- if and (not .Values.image.tag) (not .Values.image.digest) -}}
{{- fail "image.tag or image.digest is required: the app image publishes no version tags, so pinning to a mutable tag like :latest is not supported" -}}
{{- end -}}
{{- if eq .Values.image.tag "latest" -}}
{{- fail "image.tag: latest is not supported, pin image.digest or a sha-<commit> tag" -}}
{{- end -}}

{{- /* Deployment */ -}}
{{- if not (has .Values.deployment.mode (list "authenticated" "local_trusted")) -}}
{{- fail "deployment.mode must be authenticated or local_trusted" -}}
{{- end -}}
{{- if not (has .Values.deployment.exposure (list "private" "public")) -}}
{{- fail "deployment.exposure must be private or public" -}}
{{- end -}}
{{- if and (eq .Values.deployment.mode "local_trusted") (ne .Values.deployment.exposure "private") -}}
{{- fail "deployment.exposure must be private when deployment.mode is local_trusted: local_trusted disables authentication entirely" -}}
{{- end -}}
{{- if and (eq .Values.deployment.exposure "public") (not .Values.deployment.publicUrl) -}}
{{- fail "deployment.publicUrl is required when deployment.exposure is public" -}}
{{- end -}}

{{- /* Service and probes */ -}}
{{- if not .Values.service.port -}}
{{- fail "service.port is required" -}}
{{- end -}}
{{- if not (has .Values.probes.type (list "auto" "http" "tcp")) -}}
{{- fail "probes.type must be auto, http or tcp" -}}
{{- end -}}

{{- /* Secrets */ -}}
{{- include "paperclip.assertSecretRef" (dict "field" "auth.betterAuthSecret" "cfg" .Values.auth.betterAuthSecret "required" true) -}}
{{- include "paperclip.assertSecretRef" (dict "field" "secrets.masterKey" "cfg" .Values.secrets.masterKey "required" true) -}}
{{- if not (has .Values.secrets.provider (list "local_encrypted")) -}}
{{- fail "secrets.provider must be local_encrypted: this chart wires no other backend" -}}
{{- end -}}

{{- /* Heartbeat and replicas */ -}}
{{- if ne .Values.heartbeat.schedulerGating "ordinal" -}}
{{- fail "heartbeat.schedulerGating must be ordinal: the app has no lease-based scheduler leader election (paperclipai/paperclip#9005 is unmerged), so any other mode lets every replica run the scheduler" -}}
{{- end -}}
{{- if gt (int .Values.replicaCount) 1 -}}
{{- if not .Values.heartbeat.acknowledgeMultiReplica -}}
{{- fail "replicaCount > 1 requires heartbeat.acknowledgeMultiReplica=true: the scheduler is pinned to pod-0 with no failover, and every replica mounts the same ReadWriteOnce data volume" -}}
{{- end -}}
{{- end -}}
{{- if lt (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount must be at least 1" -}}
{{- end -}}

{{- /* Persistence */ -}}
{{- if not .Values.persistence.mountPath -}}
{{- fail "persistence.mountPath is required" -}}
{{- end -}}
{{- if and .Values.persistence.enabled (not .Values.persistence.size) -}}
{{- fail "persistence.size is required when persistence.enabled is true" -}}
{{- end -}}

{{- /* Bootstrap hook Job */ -}}
{{- if .Values.bootstrap.enabled -}}
{{- if not .Values.persistence.enabled -}}
{{- fail "bootstrap.enabled requires persistence.enabled: the invite command reads the instance config from the data volume" -}}
{{- end -}}
{{- if lt (int .Values.bootstrap.attempts) 1 -}}
{{- fail "bootstrap.attempts must be at least 1" -}}
{{- end -}}
{{- if lt (int .Values.bootstrap.intervalSeconds) 1 -}}
{{- fail "bootstrap.intervalSeconds must be at least 1" -}}
{{- end -}}
{{- end -}}

{{- /* Wait-for-database init container */ -}}
{{- if .Values.waitForDatabase.enabled -}}
{{- if not .Values.waitForDatabase.image.repository -}}
{{- fail "waitForDatabase.image.repository is required when waitForDatabase.enabled is true" -}}
{{- end -}}
{{- if lt (int .Values.waitForDatabase.attempts) 1 -}}
{{- fail "waitForDatabase.attempts must be at least 1" -}}
{{- end -}}
{{- if lt (int .Values.waitForDatabase.intervalSeconds) 1 -}}
{{- fail "waitForDatabase.intervalSeconds must be at least 1" -}}
{{- end -}}
{{- if lt (int .Values.waitForDatabase.connectTimeoutSeconds) 1 -}}
{{- fail "waitForDatabase.connectTimeoutSeconds must be at least 1" -}}
{{- end -}}
{{- end -}}

{{- /* Database */ -}}
{{- if not (has .Values.database.mode (list "cnpg" "external")) -}}
{{- fail "database.mode must be cnpg or external" -}}
{{- end -}}

{{- if eq .Values.database.mode "cnpg" -}}
{{- $c := .Values.database.cnpg -}}
{{- if not $c.appSecretUriKey -}}
{{- fail "database.cnpg.appSecretUriKey is required" -}}
{{- end -}}
{{- if and (not $c.create) (not $c.clusterName) (not $c.appSecretName) -}}
{{- fail "database.cnpg.clusterName or database.cnpg.appSecretName is required when database.cnpg.create is false" -}}
{{- end -}}
{{- if $c.create -}}
{{- if not $c.database -}}
{{- fail "database.cnpg.database is required" -}}
{{- end -}}
{{- if not $c.owner -}}
{{- fail "database.cnpg.owner is required" -}}
{{- end -}}
{{- if lt (int $c.instances) 1 -}}
{{- fail "database.cnpg.instances must be at least 1" -}}
{{- end -}}
{{- if not $c.storage.size -}}
{{- fail "database.cnpg.storage.size is required" -}}
{{- end -}}
{{- if and $c.walStorage.enabled (not $c.walStorage.size) -}}
{{- fail "database.cnpg.walStorage.size is required when walStorage.enabled is true" -}}
{{- end -}}
{{- if and (not $c.imageName) (not $c.postgresqlVersion) -}}
{{- fail "database.cnpg.postgresqlVersion or database.cnpg.imageName is required" -}}
{{- end -}}
{{- if and $c.enableSuperuserAccess (not $c.superuserSecret) -}}
{{- fail "database.cnpg.superuserSecret is required when enableSuperuserAccess is true" -}}
{{- end -}}
{{- end -}}
{{- if $c.backups.enabled -}}
{{- if $c.backups.create -}}
{{- if not $c.backups.destinationPath -}}
{{- fail "database.cnpg.backups.destinationPath is required when backups are enabled" -}}
{{- end -}}
{{- if not $c.backups.secretName -}}
{{- fail "database.cnpg.backups.secretName is required when backups are enabled: the chart does not create S3 credentials" -}}
{{- end -}}
{{- else if not $c.backups.objectStoreName -}}
{{- fail "database.cnpg.backups.objectStoreName is required when backups.create is false" -}}
{{- end -}}
{{- range $c.backups.scheduledBackups -}}
{{- if not .name -}}
{{- fail "every database.cnpg.backups.scheduledBackups entry needs a name" -}}
{{- end -}}
{{- if not .schedule -}}
{{- fail (printf "database.cnpg.backups.scheduledBackups %s needs a schedule" .name) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- if eq .Values.database.mode "external" -}}
{{- $db := .Values.database.external -}}
{{- if and $db.existingSecret (not $db.existingSecretKey) -}}
{{- fail "database.external.existingSecretKey is required when database.external.existingSecret is set" -}}
{{- end -}}
{{- if include "paperclip.externalDb.componentMode" . -}}
{{- include "paperclip.assertSecretRef" (dict "field" "database.external.host" "cfg" $db.host "required" true) -}}
{{- include "paperclip.assertSecretRef" (dict "field" "database.external.port" "cfg" $db.port "required" true) -}}
{{- include "paperclip.assertSecretRef" (dict "field" "database.external.database" "cfg" $db.database "required" true) -}}
{{- include "paperclip.assertSecretRef" (dict "field" "database.external.username" "cfg" $db.username "required" true) -}}
{{- include "paperclip.assertSecretRef" (dict "field" "database.external.password" "cfg" $db.password "required" true) -}}
{{- end -}}
{{- end -}}

{{- /* secretEnvFrom shape */ -}}
{{- range $key, $ref := .Values.secretEnvFrom -}}
{{- if not $ref.existingSecret -}}
{{- fail (printf "secretEnvFrom.%s.existingSecret is required" $key) -}}
{{- end -}}
{{- if not $ref.key -}}
{{- fail (printf "secretEnvFrom.%s.key is required" $key) -}}
{{- end -}}
{{- end -}}

{{- /* Ingress */ -}}
{{- if .Values.ingress.enabled -}}
{{- if not .Values.ingress.hosts -}}
{{- fail "ingress.hosts is required when ingress.enabled is true" -}}
{{- end -}}
{{- range .Values.ingress.hosts -}}
{{- if not .host -}}
{{- fail "every ingress.hosts entry needs a host" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* Drain window */ -}}
{{- if and .Values.drain.enabled (ge (int .Values.drain.timeoutSeconds) (int .Values.terminationGracePeriodSeconds)) -}}
{{- fail "drain.timeoutSeconds must be shorter than terminationGracePeriodSeconds: the grace period also has to cover the SIGTERM soft-drain" -}}
{{- end -}}

{{- end }}
