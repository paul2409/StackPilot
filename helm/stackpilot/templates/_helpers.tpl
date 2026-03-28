{{- define "stackpilot.name" -}}
stackpilot
{{- end }}

{{- define "stackpilot.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "stackpilot.labels" -}}
app.kubernetes.io/name: {{ include "stackpilot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}