# Helm Charts Availability Analysis

## Executive Summary

Análise da disponibilidade de Helm charts oficiais para as aplicações identificadas que precisam ser migradas para o padrão de repositórios padronizado.

## Applications Chart Availability Matrix

| Application | Official Chart Available | Chart Source | Version | Migration Strategy |
|-------------|--------------------------|-------------|---------|-------------------|
| **digibroker-digiworker** | ❌ No | N/A | N/A | Use generic-helm-service |
| **evolutionapi-digiworker** | ⚠️ Limited | Community | N/A | Use generic-helm-service |
| **rabbit** | ✅ Yes | Bitnami | 16.0.14 | Use official chart |
| **minio-digiworker** | ✅ Yes | Official/Bitnami | 8.0.10/17.0.21 | Use official chart |
| **lightrag** | ❌ No | N/A | N/A | Use generic-ai-service |
| **supabase-digiworker** | ✅ Yes | Community | Current | Keep current approach |

## Detailed Findings

### 1. DigibrokerBackend
**Status**: ❌ No Official Chart Available
- **Finding**: No specific Helm chart found for DigibrokerBackend
- **Recommendation**: Migrate to `generic-helm-service` template
- **Effort**: Low - Standard web application pattern

### 2. Evolution API (WhatsApp Integration)
**Status**: ⚠️ Limited Community Support
- **Finding**:
  - Evolution API is open-source WhatsApp integration API
  - No official Helm chart from Evolution API team
  - Community chart available for WhatsApp Business API
  - Docker-based deployment recommended by official docs
- **Recommendation**: Use `generic-helm-service` template
- **Special Considerations**:
  - Multi-tenant architecture support needed
  - Persistent storage for WhatsApp sessions
  - Port 8080 exposure
- **Effort**: Low-Medium - Standard API with session persistence

### 3. RabbitMQ
**Status**: ✅ Official Chart Available
- **Finding**:
  - **Official Bitnami Chart**: `rabbitmq 16.0.14`
  - **Repository**: `oci://registry-1.docker.io/bitnamicharts/rabbitmq`
  - **Features**: Management UI, clustering, metrics, persistence
  - **⚠️ Important**: Bitnami transitioning to secure images (August 28, 2025)
- **Recommendation**: Use official Bitnami chart
- **Migration Strategy**:
  - Replace current app-specific repo with Bitnami chart
  - Move values to cluster config repository
  - Configure for production (clustering, persistence, monitoring)
- **Effort**: Medium - Chart migration with configuration

**Example Configuration**:
```yaml
# unlkd/digiworker/rabbitmq.helm-values.yaml
auth:
  username: admin
  password: secure-password
  erlangCookie: secure-cookie

persistence:
  enabled: true
  size: 20Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

clustering:
  enabled: false  # Single node for digiworker

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### 4. MinIO
**Status**: ✅ Multiple Official Charts Available
- **Finding**:
  - **Official MinIO Chart**: `minio/minio 8.0.10`
  - **Bitnami Chart**: `bitnami/minio 17.0.21`
  - **MinIO Operator**: `minio-operator 4.3.7` (for enterprise/multi-tenant)
- **Recommendation**: Use official MinIO chart for simplicity
- **Features**: S3-compatible storage, web console, distributed mode
- **Migration Strategy**:
  - Replace app-specific repo with official chart
  - Configure for single-node deployment (suitable for digiworker)
  - Enable web console for management
- **Effort**: Medium - Chart migration with storage configuration

**Example Configuration**:
```yaml
# unlkd/digiworker/minio.helm-values.yaml
mode: standalone  # or distributed for HA
replicas: 1

persistence:
  enabled: true
  size: 100Gi

service:
  type: ClusterIP
  port: 9000

consoleService:
  type: ClusterIP
  port: 9001

auth:
  rootUser: admin
  rootPassword: secure-password

buckets:
  - name: digiworker-data
    policy: none
    purge: false

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 5. LightRAG
**Status**: ❌ No Official Chart Available
- **Finding**:
  - LightRAG is "Simple and Fast Retrieval-Augmented Generation" by HKU Data Science
  - Docker deployment available
  - No official Helm chart
  - RAG-specific deployment patterns exist in community
- **Recommendation**: Create `generic-ai-service` template
- **Special Considerations**:
  - GPU support potential
  - Model storage requirements
  - Vector database integration (if needed)
  - API and Web UI components
- **Effort**: Medium - AI-specific template creation

### 6. Supabase
**Status**: ✅ Community Chart Available (Already Using)
- **Finding**: Currently using community chart from GitHub
- **Recommendation**: Keep current approach, optimize configuration
- **Action**: Move values file to cluster config for consistency
- **Effort**: Low - Configuration reorganization

## Updated Migration Strategy

### Phase 1: Official Charts (Weeks 1-2) - **HIGH IMPACT**
1. **RabbitMQ Migration to Bitnami Chart**
   - **Priority**: High
   - **Effort**: Medium
   - **Benefit**: Production-ready, maintained, feature-rich
   - **Action**: Replace app-specific deployment with `bitnami/rabbitmq`

2. **MinIO Migration to Official Chart**
   - **Priority**: High
   - **Effort**: Medium
   - **Benefit**: S3-compatible, web console, official support
   - **Action**: Replace app-specific deployment with `minio/minio`

### Phase 2: Generic Templates (Weeks 3-4)
3. **DigibrokerBackend to Generic-Helm-Service**
   - **Priority**: Medium
   - **Effort**: Low
   - **Benefit**: Standardization, maintainability

4. **Evolution API to Generic-Helm-Service**
   - **Priority**: Medium
   - **Effort**: Low-Medium
   - **Benefit**: Standardization with session persistence

### Phase 3: Specialized Templates (Weeks 5-6)
5. **LightRAG to Generic-AI-Service**
   - **Priority**: Low
   - **Effort**: Medium
   - **Benefit**: AI/ML-specific optimizations, reusable template

6. **Supabase Configuration Optimization**
   - **Priority**: Low
   - **Effort**: Low
   - **Action**: Move values to cluster config, maintain current chart

## Repository Structure Update

### New Official Charts Integration
```
clusters/dev-k8s-clients/
└── unlkd/
    └── digiworker/
        ├── rabbitmq.helm-values.yaml      # Bitnami chart values
        ├── minio.helm-values.yaml         # Official chart values
        ├── digibroker.helm-values.yaml    # Generic-helm-service values
        ├── evolutionapi.helm-values.yaml  # Generic-helm-service values
        ├── lightrag.helm-values.yaml      # Generic-ai-service values
        └── supabase.helm-values.yaml      # Existing chart values
```

### ArgoCD Application Templates

#### RabbitMQ with Official Chart
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rabbit-digiworker
  namespace: argocd
spec:
  project: unlkd
  sources:
  - helm:
      valueFiles:
      - $values/unlkd/digiworker/rabbitmq.helm-values.yaml
    chart: rabbitmq
    repoURL: oci://registry-1.docker.io/bitnamicharts/rabbitmq
    targetRevision: 16.0.14
  - ref: values
    repoURL: ssh://git@git.puddi.ng/clusters/dev-k8s-clients
    targetRevision: trunk
  destination:
    namespace: unlkd
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### MinIO with Official Chart
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio-digiworker
  namespace: argocd
spec:
  project: unlkd
  sources:
  - helm:
      valueFiles:
      - $values/unlkd/digiworker/minio.helm-values.yaml
    chart: minio
    repoURL: https://charts.min.io/
    targetRevision: 8.0.10
  - ref: values
    repoURL: ssh://git@git.puddi.ng/clusters/dev-k8s-clients
    targetRevision: trunk
  destination:
    namespace: unlkd
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Benefits of Official Charts

### ✅ **RabbitMQ (Bitnami)**
- Production-ready clustering support
- Built-in monitoring and metrics
- Security best practices implemented
- Regular updates and CVE patches
- Management UI included
- Backup/restore capabilities

### ✅ **MinIO (Official)**
- S3-compatible API
- Distributed storage support
- Web-based administration console
- Built-in monitoring endpoints
- Enterprise features available
- Active maintenance and support

### ✅ **Reduced Maintenance Overhead**
- Security updates automatic
- Bug fixes from upstream
- Community support and documentation
- Production-tested configurations
- Best practices implemented by default

## Risk Mitigation

### Bitnami August 2025 Changes
- **Risk**: Bitnami charts transitioning to secure images
- **Mitigation**: Plan migration before August 28, 2025
- **Alternative**: RabbitMQ Cluster Operator as backup option

### Configuration Complexity
- **Risk**: Official charts may have different configuration syntax
- **Mitigation**: Thorough testing in staging environment
- **Rollback**: Keep current deployments during transition

### Feature Parity
- **Risk**: Official charts might not have exact same features as custom deployments
- **Mitigation**: Gap analysis during planning phase
- **Customization**: Use chart values and sub-charts for specific needs

## Conclusion

**2 out of 6 applications** have robust official charts available (RabbitMQ, MinIO), which should be prioritized for migration as they provide significant production benefits. The remaining applications will use the generic template approach as originally planned.

This mixed strategy optimizes for both standardization and leveraging battle-tested official solutions where available.