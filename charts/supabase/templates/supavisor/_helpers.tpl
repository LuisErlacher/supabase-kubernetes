{{/*
Expand the name of the chart.
*/}}
{{- define "supabase.supavisor.name" -}}
{{- default .Chart.Name .Values.supavisor.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "supabase.supavisor.fullname" -}}
{{- if .Values.supavisor.fullnameOverride }}
{{- .Values.supavisor.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.supavisor.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name "supavisor" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "supabase.supavisor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "supabase.supavisor.labels" -}}
helm.sh/chart: {{ include "supabase.supavisor.chart" . }}
{{ include "supabase.supavisor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "supabase.supavisor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase.supavisor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "supabase.supavisor.serviceAccountName" -}}
{{- if .Values.supavisor.serviceAccount.create }}
{{- default (include "supabase.supavisor.fullname" .) .Values.supavisor.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.supavisor.serviceAccount.name }}
{{- end }}
{{- end }}