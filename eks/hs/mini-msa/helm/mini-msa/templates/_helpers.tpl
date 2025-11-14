{{/* Return chart name */}}
{{- define "mini-msa.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Return fully qualified release name */}}
{{- define "mini-msa.fullname" -}}
{{- if .Values.fullNameOverride -}}
{{- .Values.fullNameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Standard chart label */}}
{{- define "mini-msa.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/* Base labels applied to every resource */}}
{{- define "mini-msa.labels" -}}
app.kubernetes.io/name: {{ include "mini-msa.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ include "mini-msa.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "mini-msa.fullname" . }}
{{- end -}}

{{/* Selector labels used for Deployments/StatefulSets */}}
{{- define "mini-msa.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mini-msa.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Component labels (extends base labels) */}}
{{- define "mini-msa.componentLabels" -}}
{{- $root := .root -}}
{{- $component := .component | default "app" -}}
{{ include "mini-msa.labels" $root }}
app.kubernetes.io/component: {{ $component }}
{{- end -}}

{{/* Compute namespace name from key (app/data). Falls back to provided name */}}
{{- define "mini-msa.namespaceName" -}}
{{- $root := .root -}}
{{- $key := .key -}}
{{- $ns := index $root.Values.namespaces $key -}}
{{- if $ns.name -}}
{{- $ns.name -}}
{{- else -}}
{{- printf "%s-%s" (include "mini-msa.fullname" $root) $key | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Component/resource name helper */}}
{{- define "mini-msa.componentName" -}}
{{- $root := .root -}}
{{- if .override -}}
{{- .override | trunc 63 | trimSuffix "-" -}}
{{- else if .suffix -}}
{{- printf "%s-%s" (include "mini-msa.fullname" $root) .suffix | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "mini-msa.fullname" $root -}}
{{- end -}}
{{- end -}}

{{/* Merge arbitrary labels map */}}
{{- define "mini-msa.renderLabels" -}}
{{- if . -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}

{{/* Convenience to render env vars */}}
{{- define "mini-msa.renderEnv" -}}
{{- if . -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}
