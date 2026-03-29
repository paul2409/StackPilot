{{- define "stackpilot.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "stackpilot.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "stackpilot.commonLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.global.appName }}
stackpilot.io/environment: {{ .Values.global.environment }}
{{- end -}}