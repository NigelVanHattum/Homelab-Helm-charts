# Paperless-ngx Helm Chart

This Helm chart deploys Paperless-ngx, a community-supported open-source document management system using a StatefulSet for stable persistent storage.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- **PostgreSQL database** (external, required)
- **Redis** (deployed internally as simple caching service)
- **Apache Tika** (optional, for enhanced document processing)
- **Gotenberg** (optional, for PDF generation and document conversion)

### Database
Paperless-ngx requires PostgreSQL. By default, the chart expects an external PostgreSQL database. Configure the connection details in `values.yaml` under `paperless.database`. If you want to deploy PostgreSQL as a dependency, set `paperless.database.enabled` to `true`.

### Redis
Redis is deployed internally as a simple, volatile caching service without persistence or authentication.

### PAPERLESS_URL Auto-Configuration
When ingress is enabled with hosts configured, the `PAPERLESS_URL` environment variable is automatically set to `https://<first-ingress-host>`. If you need to override this behavior, explicitly set `paperless.env.PAPERLESS_URL` in your values.yaml file.

## Configuration

The following table lists the configurable parameters of the paperless-ngx chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Paperless-ngx image repository | `ghcr.io/paperless-ngx/paperless-ngx` |
| `image.tag` | Paperless-ngx image tag | `""` (uses Chart appVersion) |
| `service.port` | Service port | `8000` |
| `paperless.env.PAPERLESS_TIME_ZONE` | Time zone | `UTC` |
| `paperless.env.PAPERLESS_OCR_LANGUAGE` | OCR language | `eng` |
| `paperless.env.PAPERLESS_ADMIN_USER` | Admin username | `admin` |
| `paperless.env.PAPERLESS_ADMIN_PASSWORD` | Admin password | `""` |
| `paperless.env.PAPERLESS_SECRET_KEY` | Django secret key | `""` |
| `paperless.env.PAPERLESS_URL` | Paperless URL (auto-configured from ingress if empty) | `""` |
| `paperless.database.enabled` | Enable PostgreSQL dependency | `false` |
| `paperless.persistence.data.enabled` | Enable data PVC | `true` |
| `paperless.persistence.media.enabled` | Enable media PVC | `true` |
| `paperless.persistence.consume.enabled` | Enable consume PVC | `true` |
| `paperless.tika.enabled` | Enable Apache Tika dependency | `true` |
| `paperless.tika.url` | Apache Tika service URL | `""` (auto-generated) |
| `paperless.gotenberg.enabled` | Enable Gotenberg dependency | `true` |
| `paperless.gotenberg.url` | Gotenberg service URL | `""` (auto-generated) |
| `paperless.extraEnv` | Additional environment variables | `[]` |

## Extra Environment Variables

You can add additional environment variables to the Paperless-ngx container using the `paperless.extraEnv` configuration. This allows you to set custom environment variables that can be either static values or references to Kubernetes secrets.

### Examples:

```yaml
paperless:
  extraEnv:
    # Static value
    - name: PAPERLESS_CUSTOM_SETTING
      value: "my-custom-value"

    # From a secret
    - name: PAPERLESS_API_TOKEN
      valueFrom:
        secretKeyRef:
          name: my-secret
          key: api-token

    # From a config map
    - name: PAPERLESS_CONFIG_FILE
      valueFrom:
        configMapKeyRef:
          name: my-config
          key: config.yaml
```

## Persistence

Paperless-ngx requires persistent storage for:
- **data**: Database and configuration files
- **media**: Processed documents and thumbnails
- **consume**: Directory for document ingestion

## Accessing Paperless-ngx

After deployment, access Paperless-ngx using the provided URL in the NOTES output. Default credentials are configured via `paperless.env.PAPERLESS_ADMIN_USER` and `paperless.env.PAPERLESS_ADMIN_PASSWORD`.