# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Helm charts for deploying Supabase (open source Firebase alternative) on Kubernetes. The main chart is located at `charts/supabase/` and includes all Supabase services: database, auth, storage, realtime, functions, and supporting infrastructure.

## Key Commands

### Installation and Deployment
```bash
# Install Supabase using example values
helm install demo -f charts/supabase/values.example.yaml charts/supabase/

# Install with custom values file
helm install <release-name> -f <custom-values.yaml> charts/supabase/

# Upgrade existing deployment
helm upgrade <release-name> -f <values-file> charts/supabase/

# Uninstall deployment
helm uninstall <release-name>
```

### Development and Testing
```bash
# Package chart and update repository index
sh build.sh

# Lint chart (using Docker)
docker run -it --workdir=/data --volume $(pwd)/charts/supabase:/data quay.io/helmpack/chart-testing:v3.7.1 ct lint --validate-maintainers=false --chart-dirs . --charts .

# Test chart installation (requires Kubernetes access)
docker run -it --network host --workdir=/data --volume ~/.kube/config:/root/.kube/config:ro --volume $(pwd)/charts/supabase:/data quay.io/helmpack/chart-testing:v3.7.1 ct install --chart-dirs . --charts .

# Check pod status for a deployment
kubectl get pod -l app.kubernetes.io/instance=<release-name>
```

## Architecture

### Chart Structure
- **Main Chart**: `charts/supabase/` - Contains all templates and configurations
- **Services**: Each Supabase service has its own template directory under `charts/supabase/templates/`:
  - `db/` - PostgreSQL database with Supabase extensions
  - `auth/` - Authentication service (GoTrue)
  - `storage/` - Object storage service
  - `realtime/` - WebSocket-based realtime service
  - `rest/` - RESTful API (PostgREST)
  - `kong/` - API gateway routing
  - `studio/` - Supabase Studio dashboard
  - `analytics/` - Logflare analytics
  - `vector/` - Log aggregation
  - `functions/` - Edge functions runtime
  - `minio/` - Optional S3-compatible storage backend
  - `imgproxy/` - Image transformation service
  - `meta/` - Metadata service

### Configuration Flow
1. **values.yaml**: Main configuration file containing all service settings
2. **Secrets**: Sensitive data (JWT keys, passwords) stored in Kubernetes secrets
3. **Templates**: Helm templates generate Kubernetes manifests using values and helpers
4. **_helpers.tpl**: Common template functions for naming, labels, and selectors

### Service Dependencies
- All services depend on the database being available
- Kong acts as the API gateway, routing requests to appropriate services
- Auth, Storage, and Realtime services require JWT secrets
- Analytics service requires Logflare API key
- Storage can use either local volumes or S3-compatible storage (including Minio)

## Important Configuration Areas

### Secrets Management
All sensitive configurations are managed through the `secret:` section in values.yaml:
- JWT keys (anon, service, secret)
- Database credentials
- SMTP credentials
- Dashboard authentication
- S3 credentials
- Analytics API key

### Ingress Configuration
Primary entry points are through Kong and database services. Modify ingress settings in respective service sections to configure external access.

### Database Configuration
- Uses `supabase/postgres` image with custom extensions
- Migration scripts can be added via `db.config` field
- Supports external database providers (requires adjusting DB_HOST and credentials)

### Testing
Test jobs are provided in `charts/supabase/templates/test/` to verify service connectivity after deployment using `helm test`.