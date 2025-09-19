# DevOps Repository Architecture Guide

## Overview

Análise dos dois repositórios fundamentais da arquitetura DevOps da UNLKD e como replicá-los para novos projetos.

## Repositórios Analisados

### 1. Cluster Configuration Repository
**Repo**: `ssh://git@git.puddi.ng/clusters/dev-k8s-clients`
**Função**: Centralizador de configurações por ambiente/projeto

### 2. Generic Helm Service Template
**Repo**: `ssh://git@git.puddi.ng/public-templates/generic-helm-service.git`
**Função**: Template reutilizável para deployments padronizados

## Arquitetura de Separação de Responsabilidades

```mermaid
graph TB
    A[ArgoCD Application] --> B[Generic Helm Template]
    A --> C[Cluster Config Values]

    B --> D[charts/generic-helm-service]
    D --> E[deployment.yaml]
    D --> F[service.yaml]
    D --> G[ingress.yaml]

    C --> H[unlkd/project/app.helm-values.yaml]
    C --> I[unlkd/manifests/shared-resources.yaml]
```

## 1. Cluster Configuration Repository

### Estrutura Atual
```
clusters/dev-k8s-clients/
├── unlkd/                           # Namespace/Environment
│   ├── manifests/                   # Shared resources
│   │   ├── secrets.yaml
│   │   ├── pvcs.yaml
│   │   └── configmaps.yaml
│   ├── digiworker/                  # Project folder
│   │   ├── manifests/               # Project-specific manifests
│   │   ├── n8n/                     # Service-specific configs
│   │   └── evolution.helm-values.yaml  # Helm values
│   ├── praticacertificacao/
│   ├── status/
│   └── thinkworklab/
```

### Responsabilidades
- **Values Files**: Configurações específicas por aplicação
- **Shared Manifests**: Recursos compartilhados (secrets, PVCs)
- **Project Organization**: Estrutura hierárquica por projeto
- **Environment Configuration**: Configurações por ambiente

### Exemplo de Values File
```yaml
# unlkd/digiworker/evolution.helm-values.yaml
replicaCount: 2
image:
  repository: digiworker/evolution-api
  tag: "1.0.0"
service:
  type: ClusterIP
  port: 8080
ingress:
  enabled: true
  hosts:
    - host: evolution.unlkd.co
      paths: ["/"]
env:
  NODE_ENV: production
  DATABASE_URL: postgresql://user:pass@postgres:5432/evolution
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

## 2. Generic Helm Service Template

### Estrutura do Template
```
public-templates/generic-helm-service/
├── Chart.yaml
├── values.yaml                     # Default values
└── charts/generic-helm-service/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── configmap.yaml
        ├── secret.yaml
        ├── serviceaccount.yaml
        ├── _helpers.tpl
        └── tests/
            └── test-connection.yaml
```

### Templates Principais

#### deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "generic-helm-service.fullname" . }}
  labels:
    {{- include "generic-helm-service.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "generic-helm-service.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "generic-helm-service.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort | default .Values.service.port }}
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

#### service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "generic-helm-service.fullname" . }}
  labels:
    {{- include "generic-helm-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort | default .Values.service.port }}
      protocol: TCP
      name: http
  selector:
    {{- include "generic-helm-service.selectorLabels" . | nindent 4 }}
```

## Multi-Source ArgoCD Configuration

### Pattern Usado (8 aplicações)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-application
  namespace: argocd
spec:
  project: unlkd
  sources:
  # Source 1: Helm Template
  - helm:
      valueFiles:
      - $values/unlkd/project/app.helm-values.yaml
    path: charts/generic-helm-service
    repoURL: ssh://git@git.puddi.ng/public-templates/generic-helm-service.git
    targetRevision: trunk
  # Source 2: Values Reference
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
    retry:
      limit: 5
    syncOptions:
    - PruneLast=true
    - PrunePropagationPolicy=foreground
    - RespectIgnoreDifferences=true
```

## Como Replicar para Novos Projetos

### Passo 1: Criar Structure no Cluster Config
```bash
# No repositório clusters/your-environment-k8s-clients
mkdir -p your-environment/
mkdir -p your-environment/manifests/
mkdir -p your-environment/project-name/
```

### Passo 2: Criar Values File
```yaml
# your-environment/project-name/app-name.helm-values.yaml
replicaCount: 1
image:
  repository: your-registry/app-name
  tag: "latest"
  pullPolicy: Always

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app-name.your-domain.com
      paths:
        - path: /
          pathType: Prefix

env:
  NODE_ENV: production
  DATABASE_URL: postgresql://postgres:5432/appdb

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Passo 3: Criar ArgoCD Application
```yaml
# argocd/app-name.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-name-environment
  namespace: argocd
spec:
  project: your-project
  sources:
  - helm:
      valueFiles:
      - $values/your-environment/project-name/app-name.helm-values.yaml
    path: charts/generic-helm-service
    repoURL: ssh://git@git.puddi.ng/public-templates/generic-helm-service.git
    targetRevision: trunk
  - ref: values
    repoURL: ssh://git@git.puddi.ng/clusters/your-environment-k8s-clients
    targetRevision: trunk
  destination:
    namespace: your-environment
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Passo 4: Apply Application
```bash
kubectl apply -f argocd/app-name.yaml
```

## Vantagens desta Arquitetura

### ✅ **Padronização**
- Templates consistentes para todos os serviços
- Práticas de segurança aplicadas automaticamente
- Redução de código duplicado

### ✅ **Manutenibilidade**
- Mudanças no template propagam automaticamente
- Configurações centralizadas por ambiente
- Versionamento independente

### ✅ **Escalabilidade**
- Fácil onboarding de novos projetos
- Estrutura organizada e previsível
- Reutilização de componentes

### ✅ **Flexibilidade**
- Override de qualquer valor via values file
- Suporte a diferentes tipos de aplicação
- Customização por projeto/ambiente

## Casos de Uso por Padrão

### Generic Helm Service (Recomendado para)
- ✅ APIs REST/GraphQL
- ✅ Aplicações web (React, Vue, Angular)
- ✅ Microserviços stateless
- ✅ Workers/Background jobs

### Direct Manifests (Usar quando)
- ✅ Recursos compartilhados (secrets, configmaps)
- ✅ Configurações muito específicas
- ✅ CRDs (Custom Resource Definitions)
- ✅ Operators

### External Helm Charts (Para)
- ✅ Software terceiros (PostgreSQL, Redis, etc)
- ✅ Ferramentas prontas (Vault, Grafana, etc)
- ✅ Quando existe chart oficial

## Checklist para Novos Projetos

### 📋 Setup Inicial
- [ ] Criar estrutura no cluster config repository
- [ ] Definir values file para a aplicação
- [ ] Criar ArgoCD application manifest
- [ ] Configurar secrets necessários
- [ ] Definir ingress/routing

### 📋 Configuração
- [ ] Ajustar resources (CPU/Memory)
- [ ] Configurar health checks
- [ ] Definir variáveis de ambiente
- [ ] Configurar volumes se necessário
- [ ] Setup de monitoramento

### 📋 Deploy
- [ ] Apply ArgoCD application
- [ ] Verificar sync status
- [ ] Testar conectividade
- [ ] Validar logs
- [ ] Confirmar métricas

Este padrão permite escalar eficientemente o número de aplicações mantendo consistência e qualidade nos deployments.