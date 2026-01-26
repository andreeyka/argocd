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
helm install test-release ./charts/agentgateway --dry-run --debug
helm template test-release ./charts/agentgateway --values ./charts/agentgateway/values-dev.yaml

# Lint Helm charts
helm lint ./charts/agentgateway
helm lint ./charts/a2a
helm lint ./charts/mcp
helm lint ./charts/llm
helm lint ./charts/jwt-auth
helm lint ./charts/keycloak
helm lint ./charts/httpbin

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

### File Organization

```text
charts/
├── <component>/                   # Component charts (a2a, agentgateway, mcp, llm, jwt-auth, keycloak, httpbin)
│   ├── Chart.yaml
│   ├── values.yaml                # Base values
│   ├── values-dev.yaml            # Development overrides
│   ├── values-prod.yaml           # Production overrides
│   ├── templates/
│   │   ├── deployment.yaml        # Standard template files (resource type only)
│   │   ├── service.yaml
│   │   ├── httproute.yaml
│   │   ├── route-single.yaml      # Special routes (MCP single endpoint mode)
│   │   ├── route-multi.yaml       # Special routes (MCP multi endpoint mode)
│   │   ├── deployment-postgres.yaml # Multiple components: use suffix (deployment-<component>)
│   │   └── service-postgres.yaml
│   └── instances/                 # Instance configurations (for multi-instance deployments)
│       ├── *.yaml                 # Simple: agent1.yaml, cloudru.yaml
│       ├── single/                # MCP: single servers (each gets own endpoint)
│       └── multi/                 # MCP: multi servers (all behind /mcp)

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

- **Chart Directories**: `<component>` (e.g., `a2a`, `agentgateway`, `mcp`, `llm`, `jwt-auth`, `keycloak`, `httpbin`)
  - No `agentgateway-` prefix in directory names (all charts are in `charts/` directory)
- **Chart Names in Chart.yaml**: May keep `agentgateway-<component>` prefix for uniqueness in Helm repository
- **Template Files**: `<resource-type>.yaml` (e.g., `deployment.yaml`, `service.yaml`, `httproute.yaml`)
  - **Exception 1**: Multiple components in one chart use suffix: `deployment-postgres.yaml`, `service-postgres.yaml`
  - **Exception 2**: Special route configurations: `route-single.yaml`, `route-multi.yaml` (MCP modes)
- **Resources**: Use kebab-case for Kubernetes resource names
- **Values**: Use snake_case for value keys in values.yaml
- **Instances**: Use descriptive names in `instances/` directory with .yaml extension (no component prefix)
  - A2A agents: `instances/agent1.yaml`, `instances/agent2.yaml`
  - LLM providers: `instances/cloudru.yaml`
  - MCP servers: `instances/single/*.yaml` (separate endpoints) or `instances/multi/*.yaml` (shared /mcp endpoint)

### Helm Chart Values Structure

- **Environment-specific**: Always maintain `values-dev.yaml` and `values-prod.yaml` alongside `values.yaml`
- **Namespace defaults**: Default to `agentgateway-system` namespace unless otherwise specified
- **Image pull policy**: Use `Always` for development, `IfNotPresent` for production
- **Replicas**: Default to 1, override in environment-specific files as needed

### Template Patterns

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
- **Authentication**: JWT authentication policies configure via `jwt-auth` chart
- **Namespace isolation**: Use consistent namespace naming across environments

### Documentation

- **Comments**: Use Russian comments in shell scripts (as per existing convention)
- **README**: Maintain Russian README.md for user documentation
- **Chart descriptions**: Keep Chart.yaml descriptions concise and accurate

### Common Patterns

1. **Multi-instance deployments**: Use `instances/` directory with individual YAML files
2. **Environment overrides**: Maintain separate value files for dev/prod environments
3. **Port management**: Use consistent port allocation across components (default: 8000)
5. **Gateway references**: Use `agentgateway-proxy` as default gateway reference
6. **MCP deployment modes**:
   - **Single**: Each server gets own endpoint (`/mcp/server-name`) via `instances/single/`
   - **Multi**: All servers share one endpoint (`/mcp`) via `instances/multi/`, tools prefixed with server name

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
