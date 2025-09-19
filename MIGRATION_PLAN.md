# Migration Plan: Standardizing Non-Generic Applications

## Current State Analysis

### Applications NOT Using Generic-Helm-Service Pattern

| Application | Current Pattern | Repository | Complexity | Priority |
|-------------|----------------|------------|------------|----------|
| **digibroker-digiworker** | App-specific repo | `git@git.unlkd.co:unlkd/digibroker-backend.git` | Medium | High |
| **evolutionapi-digiworker** | App-specific repo | `git@git.unlkd.co:digiworker/evolution-api.git` | Medium | High |
| **rabbit** | App-specific repo | `git@git.unlkd.co:digiworker/rabbitmq-server.git` | Medium | Medium |
| **minio-digiworker** | App-specific repo | `git@git.unlkd.co:digiworker/minio.git` | Medium | Medium |
| **lightrag** | App-specific repo | `https://git.unlkd.co/luis.erlacher/LightRAG.git` | Medium | Low |
| **supabase-digiworker** | External Helm | `https://github.com/LuisErlacher/supabase-kubernetes.git` | High | Low |

### Application Categories

#### Category A: Simple Web Applications (High Priority)
- **digibroker-digiworker**
- **evolutionapi-digiworker**
- **lightrag**

**Characteristics**:
- Standard Deployment + Service + Ingress + ConfigMap
- Can fit generic-helm-service template easily
- Minimal customization needed

#### Category B: Infrastructure Services (Medium Priority)
- **rabbit** (RabbitMQ)
- **minio-digiworker** (Object Storage)

**Characteristics**:
- Stateful applications with persistent storage
- May need specialized templates
- Complex configurations

#### Category C: Complex Stacks (Low Priority)
- **supabase-digiworker**

**Characteristics**:
- Multi-service applications
- Custom Helm charts
- Complex dependencies

## Repository Strategy

### New Repository Structure

```
public-templates/
├── generic-helm-service/           # Existing - for simple web apps
├── generic-stateful-service/       # New - for databases/storage
├── generic-messaging-service/      # New - for message brokers
└── generic-multi-service/          # New - for complex stacks
```

### Cluster Configuration Structure

```
clusters/dev-k8s-clients/
└── unlkd/
    ├── digiworker/
    │   ├── digibroker.helm-values.yaml      # New
    │   ├── evolutionapi.helm-values.yaml    # New
    │   ├── rabbit.helm-values.yaml          # New
    │   ├── minio.helm-values.yaml           # New
    │   └── lightrag.helm-values.yaml        # New
    └── manifests/
        └── shared-resources.yaml
```

## Migration Plan by Category

### Phase 1: Simple Web Applications (Weeks 1-2)

#### 1.1 DigibrokerBackend Migration

**Current State**:
```yaml
source:
  path: .k8s/manifests
  repoURL: git@git.unlkd.co:unlkd/digibroker-backend.git
  targetRevision: main
```

**Target State**:
```yaml
sources:
- helm:
    valueFiles:
    - $values/unlkd/digiworker/digibroker.helm-values.yaml
  path: charts/generic-helm-service
  repoURL: ssh://git@git.puddi.ng/public-templates/generic-helm-service.git
  targetRevision: trunk
- ref: values
  repoURL: ssh://git@git.puddi.ng/clusters/dev-k8s-clients
  targetRevision: trunk
```

**Steps**:
1. Create `unlkd/digiworker/digibroker.helm-values.yaml` in cluster config
2. Extract current Kubernetes manifests to Helm values
3. Update ArgoCD application to use multi-source
4. Test deployment
5. Remove `.k8s/manifests` from application repo

**Values File Template**:
```yaml
# unlkd/digiworker/digibroker.helm-values.yaml
replicaCount: 1
image:
  repository: registry.gitlab.com/unlkd/digibroker-backend
  tag: "latest"
  pullPolicy: Always

imagePullSecrets:
  - name: gitlab-registry-secret

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: digibroker.unlkd.co
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: digibroker-backend-tls
      hosts:
        - digibroker.unlkd.co

env:
  NODE_ENV: production
  # Add other environment variables

configMap:
  enabled: true
  data:
    # Configuration data

secret:
  enabled: true
  data:
    # Secret data

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

#### 1.2 Evolution API Migration

Similar process to DigibrokerBackend.

#### 1.3 LightRAG Migration

Similar process with specific AI/ML configurations.

### Phase 2: Infrastructure Services (Weeks 3-4)

#### 2.1 Create Generic-Stateful-Service Template

**New Template Structure**:
```
public-templates/generic-stateful-service/
├── Chart.yaml
├── values.yaml
└── charts/generic-stateful-service/
    ├── templates/
    │   ├── statefulset.yaml
    │   ├── service.yaml
    │   ├── headless-service.yaml
    │   ├── persistentvolumeclaim.yaml
    │   ├── configmap.yaml
    │   └── secret.yaml
    └── values.yaml
```

#### 2.2 RabbitMQ Migration

**StatefulSet Template**:
```yaml
# statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "generic-stateful-service.fullname" . }}
spec:
  serviceName: {{ include "generic-stateful-service.fullname" . }}-headless
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        {{- range .Values.service.ports }}
        - containerPort: {{ .port }}
          name: {{ .name }}
        {{- end }}
        volumeMounts:
        {{- range .Values.persistence.mounts }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
        {{- end }}
  volumeClaimTemplates:
  {{- range .Values.persistence.volumeClaimTemplates }}
  - metadata:
      name: {{ .name }}
    spec:
      accessModes: {{ .accessModes }}
      resources:
        requests:
          storage: {{ .size }}
  {{- end }}
```

#### 2.3 MinIO Migration

Similar approach with S3-compatible storage considerations.

### Phase 3: Complex Stacks (Weeks 5-6)

#### 3.1 Supabase Migration Strategy

**Option A: Keep Current Approach**
- Supabase already uses proper Helm chart
- Just move values file to cluster config
- Update to multi-source pattern

**Option B: Create Generic-Multi-Service Template**
- More complex but reusable for other stacks
- Handle multiple services in one application

**Recommended: Option A**

**Migration Steps**:
1. Move `values-digiworker.yaml` to cluster config
2. Update ArgoCD application to multi-source
3. Keep using the existing Supabase Helm chart

## Implementation Timeline

### Week 1
- [ ] Create cluster config structure
- [ ] Migrate digibroker-digiworker
- [ ] Test and validate

### Week 2
- [ ] Migrate evolutionapi-digiworker
- [ ] Migrate lightrag
- [ ] Test both applications

### Week 3
- [ ] Create generic-stateful-service template
- [ ] Migrate rabbit (RabbitMQ)
- [ ] Test messaging functionality

### Week 4
- [ ] Migrate minio-digiworker
- [ ] Test storage functionality
- [ ] Validate all stateful services

### Week 5
- [ ] Migrate supabase-digiworker to multi-source
- [ ] Test Supabase functionality
- [ ] End-to-end testing

### Week 6
- [ ] Documentation update
- [ ] Team training
- [ ] Monitoring setup

## Risk Mitigation

### Rollback Strategy
1. Keep original ArgoCD applications with different names
2. Test new applications in parallel
3. Switch traffic only after validation
4. Quick rollback if issues occur

### Testing Approach
1. Deploy new version alongside current
2. Validate all endpoints and functionality
3. Check logs for errors
4. Performance testing
5. Gradual traffic switching

### Monitoring
1. Set up alerts for application health
2. Monitor deployment success/failure rates
3. Track resource utilization changes
4. Application-specific metrics

## Benefits After Migration

### ✅ **Standardization**
- All applications follow same deployment pattern
- Consistent resource management
- Unified monitoring and logging

### ✅ **Maintenance**
- Centralized template improvements
- Security updates applied automatically
- Easier troubleshooting

### ✅ **Scalability**
- Faster onboarding of new applications
- Predictable deployment patterns
- Reduced DevOps overhead

### ✅ **Visibility**
- Centralized configuration management
- Better change tracking
- Easier compliance auditing

## Success Criteria

1. **All applications migrated** to standardized patterns
2. **Zero downtime** during migration
3. **Performance maintained** or improved
4. **Team adoption** of new patterns
5. **Documentation completed** for future use

This migration will bring consistency to the entire application portfolio while maintaining the flexibility needed for different application types.