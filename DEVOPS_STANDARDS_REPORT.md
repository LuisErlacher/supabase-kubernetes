# DevOps Standards Report - UNLKD Kubernetes Cluster

## Executive Summary

Análise da estrutura atual do cluster Kubernetes gerenciado via ArgoCD, identificando padrões e boas práticas implementadas pela equipe UNLKD para replicação em novos projetos.

## Cluster Overview

- **Cluster**: `https://kubernetes.default.svc`
- **ArgoCD Version**: Server v3.2.0, CLI v3.1.5
- **Primary Namespace**: `unlkd`
- **Project**: `unlkd`
- **Total Applications**: 22 aplicações gerenciadas

## Namespace Structure

### Primary Namespace: `unlkd`
Todas as aplicações são deployadas no namespace `unlkd`, seguindo um padrão de single-tenant por ambiente.

**Recursos por aplicação**:
- ConfigMaps para configurações
- Secrets para credenciais
- Services para exposição
- Deployments/StatefulSets para workloads
- PersistentVolumeClaims para dados persistentes
- Ingress para roteamento externo

## Repository Patterns

### 1. Git Repository Structure

#### Principais Repositórios:
- **Cluster Config**: `ssh://git@git.puddi.ng/clusters/dev-k8s-clients`
- **Helm Templates**: `ssh://git@git.puddi.ng/public-templates/generic-helm-service.git`
- **Application Repos**: `git@git.unlkd.co:*`
- **External Charts**: `https://guerzon.github.io/vaultwarden`

#### Estrutura de Diretórios:
```
clusters/dev-k8s-clients/
├── unlkd/
│   ├── manifests/              # YAML manifests diretos
│   ├── digiworker/
│   │   ├── manifests/          # Manifests específicos
│   │   ├── n8n/               # Aplicação específica
│   │   └── evolution.helm-values.yaml
│   ├── praticacertificacao/
│   ├── status/
│   └── thinkworklab/
```

### 2. Deployment Patterns

#### Pattern A: Generic Helm Service (Mais Comum)
```yaml
sources:
- helm:
    valueFiles:
    - $values/unlkd/digiworker/evolution.helm-values.yaml
  path: charts/generic-helm-service
  repoURL: ssh://git@git.puddi.ng/public-templates/generic-helm-service.git
  targetRevision: trunk
- ref: values
  repoURL: ssh://git@git.puddi.ng/clusters/dev-k8s-clients
  targetRevision: trunk
```

**Aplicações usando este padrão**:
- evolution-digiworker
- garupa-web
- postgres-digiworker
- praticacertificacao-db
- redis-digiworker
- thinkworklab-db
- thinkworklab-mautic*
- unlkd-co

#### Pattern B: Direct Manifests
```yaml
sources:
- path: unlkd/manifests
  repoURL: ssh://git@git.puddi.ng/clusters/dev-k8s-clients
  targetRevision: trunk
```

**Aplicações usando este padrão**:
- manifests-unlkd
- manifests-digiworker
- n8n-digiworker
- praticacertificacao
- status-digiworker
- thinkworklab

#### Pattern C: Application-Specific Repository
```yaml
source:
  path: .k8s/manifests
  repoURL: git@git.unlkd.co:digiworker/evolution-api.git
  targetRevision: HEAD
```

**Aplicações usando este padrão**:
- digibroker-digiworker
- evolutionapi-digiworker
- lightrag
- minio-digiworker
- rabbit

#### Pattern D: External Helm Chart
```yaml
source:
  chart: vaultwarden
  repoURL: https://guerzon.github.io/vaultwarden
  targetRevision: 0.32.3
```

**Aplicações usando este padrão**:
- unlkd-vaultwarden
- supabase-digiworker (using GitHub repo)

## Sync Policies

### Standard Auto-Sync Configuration
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 5
  syncOptions:
  - PruneLast=true
  - PrunePropagationPolicy=foreground
  - RespectIgnoreDifferences=true
```

**Aplicações com Auto-Prune**: 18 de 22
**Aplicações apenas Auto**: 4 aplicações (digibroker, evolutionapi, minio, rabbit)

## Project Configuration

### UNLKD Project Settings
```yaml
project: unlkd
destinations:
- namespace: unlkd
  server: https://kubernetes.default.svc
sources: "*"  # Permite qualquer source
clusterResourceWhitelist:
- group: ""
  kind: Namespace
namespaceResourceBlacklist: 3 resources
orphanedResources: enabled (warn=false)
```

## Application Categories

### 1. Infrastructure & Storage
- **minio-digiworker**: Object storage
- **postgres-digiworker**: Database
- **redis-digiworker**: Cache/Queue
- **rabbit**: Message broker

### 2. Auth & Security
- **unlkd-vaultwarden**: Password manager
- **supabase-digiworker**: Backend-as-a-Service

### 3. Automation & Integration
- **n8n-digiworker**: Workflow automation
- **evolution-digiworker**: WhatsApp API
- **evolutionapi-digiworker**: Evolution API

### 4. Applications & Services
- **garupa-web**: Web application
- **unlkd-co**: Corporate website
- **thinkworklab***: Learning platform stack
- **praticacertificacao***: Certification platform

### 5. AI & Analytics
- **lightrag**: RAG/AI service

### 6. Support Services
- **status-digiworker**: Status page
- **manifests-***: Infrastructure manifests

## Recommended DevOps Standards

### 1. Repository Structure
```
my-project/
├── .k8s/
│   └── manifests/              # Kubernetes YAML files
├── helm-values/
│   └── environment.yaml        # Helm values per environment
└── argocd/
    └── application.yaml        # ArgoCD application definition
```

### 2. Naming Convention
- **Applications**: `{service-name}-{environment}`
- **Resources**: `{app-name}-{resource-type}`
- **Namespaces**: `{environment}` or `{team-name}`

### 3. Sync Policy Template
```yaml
syncPolicy:
  automated:
    prune: true        # Remove resources não mais definidos
    selfHeal: true     # Corrige drift automaticamente
  retry:
    limit: 5           # Retry failed syncs
  syncOptions:
    - PruneLast=true   # Remove resources after creating new ones
    - PrunePropagationPolicy=foreground
    - RespectIgnoreDifferences=true
```

### 4. Security Best Practices
- Usar secrets para credenciais
- Namespace isolation
- Resource quotas e limits
- Network policies (quando necessário)

### 5. Generic Helm Service Usage
Para aplicações padronizadas, usar o template `generic-helm-service`:
- Reduz duplicação de código
- Padroniza configurações
- Facilita manutenção
- Centralizaevoluções do template

## Integration Points

### External Git Repositories
- **puddi.ng**: Templates e cluster configs
- **unlkd.co**: Application source code
- **github.com**: External charts (Supabase)

### Repository Access Patterns
- **SSH Keys**: Para repositórios privados
- **HTTPS**: Para repositórios públicos
- **Multi-source**: Values file + template separation

## Monitoring & Health

- **Health Status**: Todas aplicações estão "Healthy"
- **Sync Status**: Todas aplicações estão "Synced"
- **Automated Healing**: Ativo na maioria das aplicações
- **Orphaned Resources**: Monitoramento ativo

## Recommendations for New Projects

1. **Adopt the Generic Helm Service pattern** para aplicações padronizadas
2. **Use the multi-source approach** para separar templates de valores
3. **Implement auto-sync with prune** para manter ambiente limpo
4. **Follow the namespace-per-environment** strategy
5. **Centralize cluster configurations** em repositório dedicado
6. **Use meaningful application names** seguindo convenção estabelecida
7. **Implement proper secret management** via Kubernetes secrets
8. **Enable orphaned resource detection** para monitoramento

## Technical Debt & Improvements

1. **Standardize on single sync policy** (algumas apps não usam auto-prune)
2. **Consider namespace separation** para different environments
3. **Implement resource quotas** para better resource management
4. **Add monitoring stack** (Prometheus/Grafana não visível)
5. **Document the generic-helm-service** template usage
6. **Consider Kustomize** para environment-specific configurations