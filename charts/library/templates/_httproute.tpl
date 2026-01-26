{{- define "agentgateway-library.httproute" -}}
{{- $route := .route | default dict }}
{{- $service := .service | default dict }}
{{- $name := $route.name | default $service.name | default .name }}
{{- $serviceName := $service.name | default .name }}
{{- $gateway := $route.gateway | default dict }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $name }}
  namespace: {{ $route.namespace | default $service.namespace | default .namespace | default "agentgateway-system" }}
spec:
  parentRefs:
    - name: {{ $gateway.name | default "agentgateway-proxy" }}
      namespace: {{ $gateway.namespace | default "agentgateway-system" }}
  rules:
    {{- if $route.path }}
    # Для GET запроса на точный путь -> /.well-known/agent-card.json
    - matches:
        - path:
            type: Exact
            value: {{ $route.path | quote }}
          method: GET
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplaceFullPath
              replaceFullPath: /.well-known/agent-card.json
      backendRefs:
        - name: {{ $serviceName }}
          port: {{ $service.port | default 8000 }}
    # Для остальных путей - отрезаем префикс через ReplacePrefixMatch
    - matches:
        {{- if $route.methods }}
        {{- range $route.methods }}
        - path:
            type: PathPrefix
            value: {{ $route.path | quote }}
          method: {{ . }}
        {{- end }}
        {{- else }}
        - path:
            type: PathPrefix
            value: {{ $route.path | quote }}
        {{- end }}
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
      backendRefs:
        - name: {{ $serviceName }}
          port: {{ $service.port | default 8000 }}
    {{- else }}
    - matches:
        {{- if $route.methods }}
        {{- range $route.methods }}
        - method: {{ . }}
        {{- end }}
        {{- end }}
      backendRefs:
        - name: {{ $serviceName }}
          port: {{ $service.port | default 8000 }}
    {{- end }}
{{- end }}
