# Repository Templates Design for Specialized Stacks

## Overview

Design de novos templates de repositório para padronizar diferentes tipos de aplicações que não se encaixam no `generic-helm-service` atual.

## Template Repository Structure

```
public-templates/
├── generic-helm-service/           # Existing - Web apps simples
├── generic-stateful-service/       # New - Databases, storage
├── generic-messaging-service/      # New - Message brokers
├── generic-ai-service/             # New - AI/ML applications
└── generic-multi-service/          # New - Complex stacks
```

## 1. Generic-Stateful-Service Template

### Purpose
Para aplicações que precisam de armazenamento persistente e estado (databases, storage, cache).

### Target Applications
- **minio-digiworker** (Object Storage)
- **rabbit** (RabbitMQ)
- Future: PostgreSQL, Redis, Elasticsearch

### Template Structure
```
generic-stateful-service/
├── Chart.yaml
├── values.yaml
└── charts/generic-stateful-service/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── statefulset.yaml
        ├── service.yaml
        ├── headless-service.yaml
        ├── persistentvolumeclaim.yaml
        ├── configmap.yaml
        ├── secret.yaml
        ├── serviceaccount.yaml
        ├── networkpolicy.yaml
        ├── poddisruptionbudget.yaml
        └── _helpers.tpl
```

### Key Templates

#### statefulset.yaml
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "generic-stateful-service.fullname" . }}
  labels:
    {{- include "generic-stateful-service.labels" . | nindent 4 }}
spec:
  serviceName: {{ include "generic-stateful-service.fullname" . }}-headless
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "generic-stateful-service.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "generic-stateful-service.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "generic-stateful-service.serviceAccountName" . }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            {{- range .Values.service.ports }}
            - name: {{ .name }}
              containerPort: {{ .port }}
              protocol: {{ .protocol | default "TCP" }}
            {{- end }}
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- range $key, $value := .Values.envSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ include "generic-stateful-service.fullname" $ }}
                  key: {{ $key }}
            {{- end }}
          volumeMounts:
            {{- range .Values.persistence.mounts }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
              {{- if .subPath }}
              subPath: {{ .subPath }}
              {{- end }}
            {{- end }}
            {{- if .Values.configMap.enabled }}
            - name: config
              mountPath: {{ .Values.configMap.mountPath }}
            {{- end }}
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      volumes:
        {{- if .Values.configMap.enabled }}
        - name: config
          configMap:
            name: {{ include "generic-stateful-service.fullname" . }}
        {{- end }}
  volumeClaimTemplates:
    {{- range .Values.persistence.volumeClaimTemplates }}
    - metadata:
        name: {{ .name }}
      spec:
        accessModes:
          {{- range .accessModes }}
          - {{ . }}
          {{- end }}
        {{- if .storageClass }}
        storageClassName: {{ .storageClass }}
        {{- end }}
        resources:
          requests:
            storage: {{ .size }}
    {{- end }}
```

#### headless-service.yaml
```yaml
{{- if .Values.headlessService.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "generic-stateful-service.fullname" . }}-headless
  labels:
    {{- include "generic-stateful-service.labels" . | nindent 4 }}
spec:
  clusterIP: None
  selector:
    {{- include "generic-stateful-service.selectorLabels" . | nindent 4 }}
  ports:
    {{- range .Values.service.ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .port }}
      protocol: {{ .protocol | default "TCP" }}
    {{- end }}
{{- end }}
```

### Default Values
```yaml
# values.yaml for generic-stateful-service
replicaCount: 1

image:
  repository: ""
  pullPolicy: IfNotPresent
  tag: ""

imagePullSecrets: []

serviceAccount:
  create: true
  annotations: {}
  name: ""

service:
  type: ClusterIP
  ports:
    - name: main
      port: 8080
      protocol: TCP

headlessService:
  enabled: true

persistence:
  volumeClaimTemplates:
    - name: data
      accessModes:
        - ReadWriteOnce
      size: 10Gi
      # storageClass: ""
  mounts:
    - name: data
      mountPath: /data

configMap:
  enabled: false
  mountPath: /config
  data: {}

secret:
  enabled: false
  data: {}

env: {}
envSecret: {}

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe: {}
readinessProbe: {}

networkPolicy:
  enabled: false

podDisruptionBudget:
  enabled: false
  minAvailable: 1
```

## 2. Generic-Messaging-Service Template

### Purpose
Para message brokers e sistemas de filas.

### Target Applications
- **rabbit** (RabbitMQ)
- Future: Apache Kafka, Redis Pub/Sub, NATS

### Specialized Features
- Cluster formation support
- Message persistence
- Queue/Exchange configuration
- Monitoring endpoints

### Additional Templates
```yaml
# cluster-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "generic-messaging-service.fullname" . }}-cluster
data:
  {{- range $key, $value := .Values.clusterConfig }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}

# monitoring-service.yaml
{{- if .Values.monitoring.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "generic-messaging-service.fullname" . }}-monitoring
  labels:
    {{- include "generic-messaging-service.labels" . | nindent 4 }}
    app.kubernetes.io/component: monitoring
spec:
  type: {{ .Values.monitoring.service.type }}
  ports:
    - name: prometheus
      port: {{ .Values.monitoring.service.port }}
      targetPort: {{ .Values.monitoring.service.targetPort }}
  selector:
    {{- include "generic-messaging-service.selectorLabels" . | nindent 4 }}
{{- end }}
```

## 3. Generic-AI-Service Template

### Purpose
Para aplicações de AI/ML com necessidades específicas.

### Target Applications
- **lightrag** (RAG/AI service)
- Future: Model serving, Training jobs

### Specialized Features
- GPU support
- Model storage
- Inference endpoints
- Resource-intensive configurations

### Additional Templates
```yaml
# gpu-resources.yaml (if GPU enabled)
{{- if .Values.gpu.enabled }}
resources:
  limits:
    nvidia.com/gpu: {{ .Values.gpu.count }}
    cpu: {{ .Values.resources.limits.cpu }}
    memory: {{ .Values.resources.limits.memory }}
  requests:
    nvidia.com/gpu: {{ .Values.gpu.count }}
    cpu: {{ .Values.resources.requests.cpu }}
    memory: {{ .Values.resources.requests.memory }}
{{- else }}
resources:
  {{- toYaml .Values.resources | nindent 2 }}
{{- end }}

# model-volume.yaml
{{- if .Values.modelStorage.enabled }}
- name: models
  {{- if .Values.modelStorage.persistentVolumeClaim }}
  persistentVolumeClaim:
    claimName: {{ .Values.modelStorage.persistentVolumeClaim }}
  {{- else if .Values.modelStorage.hostPath }}
  hostPath:
    path: {{ .Values.modelStorage.hostPath }}
    type: Directory
  {{- end }}
{{- end }}
```

## 4. Generic-Multi-Service Template

### Purpose
Para stacks complexas com múltiplos serviços.

### Target Applications
- **supabase-digiworker** (se necessário)
- Future: Full-stack applications, Microservice clusters

### Approach
Usar sub-charts para cada serviço:

```yaml
# Chart.yaml
dependencies:
  - name: generic-helm-service
    repository: "file://../generic-helm-service/charts/generic-helm-service"
    version: "0.1.0"
    alias: frontend
    condition: frontend.enabled
  - name: generic-stateful-service
    repository: "file://../generic-stateful-service/charts/generic-stateful-service"
    version: "0.1.0"
    alias: database
    condition: database.enabled
  - name: generic-messaging-service
    repository: "file://../generic-messaging-service/charts/generic-messaging-service"
    version: "0.1.0"
    alias: queue
    condition: queue.enabled
```

## Migration Examples

### MinIO Values File
```yaml
# unlkd/digiworker/minio.helm-values.yaml
image:
  repository: minio/minio
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  ports:
    - name: api
      port: 9000
      protocol: TCP
    - name: console
      port: 9001
      protocol: TCP

persistence:
  volumeClaimTemplates:
    - name: data
      accessModes:
        - ReadWriteOnce
      size: 100Gi
  mounts:
    - name: data
      mountPath: /data

env:
  MINIO_ROOT_USER: admin
  MINIO_ROOT_PASSWORD: password123

command:
  - /bin/bash
  - -c
args:
  - minio server /data --console-address ":9001"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  httpGet:
    path: /minio/health/live
    port: 9000
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /minio/health/ready
    port: 9000
  initialDelaySeconds: 5
  periodSeconds: 10
```

### RabbitMQ Values File
```yaml
# unlkd/digiworker/rabbit.helm-values.yaml
image:
  repository: rabbitmq
  tag: "3.12-management"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  ports:
    - name: amqp
      port: 5672
      protocol: TCP
    - name: management
      port: 15672
      protocol: TCP

persistence:
  volumeClaimTemplates:
    - name: data
      accessModes:
        - ReadWriteOnce
      size: 20Gi
  mounts:
    - name: data
      mountPath: /var/lib/rabbitmq

envSecret:
  RABBITMQ_DEFAULT_USER: admin
  RABBITMQ_DEFAULT_PASS: password123

env:
  RABBITMQ_DEFAULT_VHOST: "/"
  RABBITMQ_ERLANG_COOKIE: "mycookie"

clusterConfig:
  enabled: false  # For single instance

monitoring:
  enabled: true
  service:
    type: ClusterIP
    port: 15692
    targetPort: 15692

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  exec:
    command:
      - rabbitmq-diagnostics
      - ping
  initialDelaySeconds: 60
  periodSeconds: 60

readinessProbe:
  exec:
    command:
      - rabbitmq-diagnostics
      - ping
  initialDelaySeconds: 20
  periodSeconds: 10
```

## Implementation Steps

### Step 1: Create Templates (Week 1-2)
1. Create repository structure
2. Develop generic-stateful-service template
3. Test with MinIO migration
4. Develop generic-messaging-service template
5. Test with RabbitMQ migration

### Step 2: Migrate Applications (Week 3-4)
1. Create values files in cluster config
2. Update ArgoCD applications
3. Test each migration thoroughly
4. Document any customizations needed

### Step 3: Optimize and Document (Week 5-6)
1. Refine templates based on real usage
2. Create documentation and examples
3. Train team on new patterns
4. Set up monitoring and alerting

## Benefits

### ✅ **Type-Specific Optimization**
- Templates optimized for each application type
- Better resource management
- Appropriate health checks and monitoring

### ✅ **Reusability**
- New stateful services use existing template
- Faster deployment of similar applications
- Consistent configuration patterns

### ✅ **Maintainability**
- Centralized improvements for each type
- Security updates applied automatically
- Easier troubleshooting with known patterns

### ✅ **Flexibility**
- Values-based customization
- Override capabilities for special cases
- Extensible template system

This design provides a complete framework for standardizing all application types while maintaining the flexibility needed for different use cases.