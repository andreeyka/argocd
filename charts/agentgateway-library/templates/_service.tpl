{{- define "agentgateway-library.service" -}}
{{- $service := .service | default dict }}
{{- $deployment := .deployment | default dict }}
{{- $name := $service.name | default $deployment.name | default .name }}
{{- $appName := $deployment.name | default .name }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}
  namespace: {{ $service.namespace | default $deployment.namespace | default .namespace | default "agentgateway-system" }}
  {{- if $service.annotations }}
  annotations:
    {{- toYaml $service.annotations | nindent 4 }}
  {{- end }}
spec:
  selector:
    app: {{ $appName }}
  type: {{ $service.type | default "ClusterIP" }}
  ports:
    - protocol: TCP
      port: {{ $service.port | default 8000 }}
      targetPort: {{ $service.targetPort | default ($deployment.port | default 8000) }}
      {{- if $service.appProtocol }}
      appProtocol: {{ $service.appProtocol }}
      {{- end }}
{{- end }}
