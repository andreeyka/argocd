# AGENTS.md

This file contains documentation for agentic coding agents working in this repository.

## Build/Lint/Test Commands

### Kubernetes/Helm Commands

```bash
# Install CRDs (one-time setup, run via script)
./scripts/install-crds.sh

# Alternative: Install CRDs manually using helm template from OCI registry
helm template agentgateway-crds oci://ghcr.io/kgateway-dev/charts/agentgateway-crds \
  --version v2.2.0-main --skip-crds=false | kubectl apply -f -

# Test a single Helm chart locally
helm install test-release ./charts/agentgateway-gateway --dry-run --debug
helm template test-release ./charts/agentgateway-gateway --values ./charts/agentgateway-gateway/values-dev.yaml

# Lint Helm charts (library chart can be linted but won't produce output)
helm lint ./charts/agentgateway-gateway
helm lint ./charts/agentgateway-a2a
helm lint ./charts/agentgateway-mcp
helm lint ./charts/agentgateway-llm
helm lint ./charts/agentgateway-jwt-auth
helm lint ./charts/agentgateway-keycloak
helm lint ./charts/agentgateway-httpbin
helm lint ./charts/agentgateway-library

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f argocd-apps/dev/

# Test JWT authentication (after setup)
./scripts/test-jwt-auth.sh
```

### Scripts

```bash
# Full setup scripts
./scripts/install-argocd.sh      # Install ArgoCD + CRDs
./scripts/install-crds.sh        # Install only CRDs (Gateway API + Agentgateway)
./scripts/setup-keycloak.sh      # Configure Keycloak after deployment

# Port-forwarding for local development
./scripts/port-forward.sh        # Start all port-forwards
./scripts/port-forward-stop.sh   # Stop all port-forwards

# Testing
./scripts/test-jwt-auth.sh       # Test JWT authentication
```

### Python (project management only)

```bash
# Python is used only for project metadata (pyproject.toml)
# No Python code or tests in this project
uv sync  # Install dependencies if needed
```

## Code Style Guidelines

### YAML/Helm Chart Style

- **Indentation**: Always use 2 spaces for YAML files
- **Helm Templates**:
  - Use `{{- if }}` with proper hyphen placement to control whitespace
  - Use `default` function for optional values with sensible defaults
  - Use `required` function for mandatory fields to catch errors early
  - Template naming convention: `agentgateway-library.<resource_name>`
  - Library chart templates are prefixed with underscores (`_deployment.tpl`, `_service.tpl`, `_httproute.tpl`)

### File Organization

```text
charts/
├── agentgateway-library/          # Reusable templates (library chart)
│   ├── Chart.yaml
│   └── templates/
│       ├── _deployment.tpl        # Deployment template
│       ├── _service.tpl           # Service template
│       └── _httproute.tpl         # HTTPRoute template
├── agentgateway-<component>/      # Component charts
│   ├── Chart.yaml
│   ├── values.yaml                # Base values
│   ├── values-dev.yaml            # Development overrides
│   ├── values-prod.yaml           # Production overrides
│   ├── templates/
│   └── instances/                 # Instance configurations (for multi-instance deployments)
│       ├── *.yaml                 # Simple: agent1.yaml, cloudru.yaml
│       ├── individual/            # MCP: individual servers (each gets own endpoint)
│       └── multiplexed/           # MCP: multiplexed servers (all behind /mcp)

argocd-apps/
├── dev/                           # Development environment
│   ├── agentgateway.yaml          # Main application (includes all components)
│   └── keycloak.yaml              # Keycloak for JWT auth
└── prod/                          # Production environment
    ├── agentgateway.yaml
    └── keycloak.yaml

scripts/
├── install-argocd.sh              # Install ArgoCD + CRDs
├── install-crds.sh                # Install CRDs only
├── port-forward.sh                # Start all port-forwards
├── port-forward-stop.sh           # Stop all port-forwards
├── setup-keycloak.sh              # Configure Keycloak
└── test-jwt-auth.sh               # Test JWT authentication
```

### Naming Conventions

- **Chart Names**: `agentgateway-<component>` (e.g., `agentgateway-gateway`, `agentgateway-a2a`)
- **Resources**: Use kebab-case for Kubernetes resource names
- **Values**: Use snake_case for value keys in values.yaml
- **Instances**: Use descriptive names in `instances/` directory with .yaml extension
  - A2A agents: `instances/agent1.yaml`, `instances/agent2.yaml`
  - LLM providers: `instances/cloudru.yaml`
  - MCP servers: `instances/individual/*.yaml` (separate endpoints) or `instances/multiplexed/*.yaml` (shared /mcp endpoint)

### Helm Chart Values Structure

- **Environment-specific**: Always maintain `values-dev.yaml` and `values-prod.yaml` alongside `values.yaml`
- **Namespace defaults**: Default to `agentgateway-system` namespace unless otherwise specified
- **Image pull policy**: Use `Always` for development, `IfNotPresent` for production
- **Replicas**: Default to 1, override in environment-specific files as needed

### Template Patterns

- **Library includes**: Use `{{- include "agentgateway-library.template-name" (dict "param1" value1 "param2" value2) }}`
- **Merging configurations**: Use `mergeOverwrite` and `deepCopy` for combining defaults with instance configs
- **Conditional resources**: Wrap entire templates in `{{- if .Values.component.enabled }}`
- **File loading**: Use `{{- $file := printf "instances/%s" . }}` and `{{- $data := $.Files.Get $file | fromYaml }}`

### ArgoCD Application Structure

- **Multi-source**: Applications use multiple sources (Helm charts from OCI, Git for resources)
- **Chart sources**: From `ghcr.io/kgateway-dev/charts` with version `v2.2.0-main`
- **Git sources**: From `https://github.com/andreeyka/argocd` branch `main`
- **CRD Management**: CRDs installed separately via `./scripts/install-crds.sh` script (one-time setup), main chart uses `skipCrds: true`

### Security Best Practices

- **Secrets**: Use Kubernetes Secrets with `stringData` for sensitive values
- **Authentication**: JWT authentication policies configure via `agentgateway-jwt-auth` chart
- **Namespace isolation**: Use consistent namespace naming across environments

### Documentation

- **Comments**: Use Russian comments in shell scripts (as per existing convention)
- **README**: Maintain Russian README.md for user documentation
- **Chart descriptions**: Keep Chart.yaml descriptions concise and accurate

### Common Patterns

1. **Multi-instance deployments**: Use `instances/` directory with individual YAML files
2. **Environment overrides**: Maintain separate value files for dev/prod environments
3. **Library templates**: Leverage `agentgateway-library` for consistent resource creation
4. **Port management**: Use consistent port allocation across components (default: 8000)
5. **Gateway references**: Use `agentgateway-proxy` as default gateway reference
6. **MCP deployment modes**:
   - **Individual**: Each server gets own endpoint (`/mcp/server-name`) via `instances/individual/`
   - **Multiplexed**: All servers share one endpoint (`/mcp`) via `instances/multiplexed/`, tools prefixed with server name

### Testing Strategy

- **Manual testing**: Use provided scripts for integration testing
- **Resource validation**: Apply manifests with `--dry-run=client` before actual deployment
- **JWT auth testing**: Run `./scripts/test-jwt-auth.sh` after Keycloak setup
- **Port-forward scripts**: Use `./scripts/port-forward.sh` for local development, `./scripts/port-forward-stop.sh` to stop

### Version Management

- **Helm charts**: Use OCI registry `ghcr.io/kgateway-dev/charts`
- **Agentgateway version**: Currently using `v2.2.0-main`
- **Consistent versions**: Keep same agentgateway version across all environments
- **Chart versions**: Semantic versioning starting from 0.1.0 for local charts
