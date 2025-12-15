# Terraform MCP Server

This Helm chart deploys the Terraform MCP Server, which provides seamless integration with Terraform ecosystem for Infrastructure as Code (IaC) development.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `terraform-mcp-server`:

```bash
helm install terraform-mcp-server ./charts/terraform-mcp-server
```

## Configuration

The following table lists the configurable parameters of the Terraform MCP Server chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `hashicorp/terraform-mcp-server` |
| `image.tag` | Image tag | `0.3.3` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `env` | List of non-secret environment variables | See `values.yaml` |
| `secretEnv` | List of secret environment variables | See `values.yaml` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `service.targetPort` | Target port | `8080` |
| `ingress.enabled` | Enable ingress | `false` |
| `resources` | CPU/Memory resource requests/limits | `{}` |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
helm install terraform-mcp-server ./charts/terraform-mcp-server -f my-values.yaml
```

## Setting Secrets

To set the Terraform API token and other secrets:

```bash
helm install terraform-mcp-server ./charts/terraform-mcp-server \
  --set secretEnv[0].value=YOUR_TFE_TOKEN
```

Or update an existing release:

```bash
helm upgrade terraform-mcp-server ./charts/terraform-mcp-server \
  --set secretEnv[0].value=YOUR_TFE_TOKEN
```

## Transport Modes

The server supports two transport modes:

- **stdio** (default): For local use with MCP clients
- **streamable-http**: For remote access via HTTP

To enable HTTP mode:

```bash
helm install terraform-mcp-server ./charts/terraform-mcp-server \
  --set env[2].value=streamable-http \
  --set env[3].value=0.0.0.0
```

## License

This chart is licensed under the MPL-2.0 license.