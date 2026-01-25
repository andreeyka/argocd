{{- define "agentgateway-library.deployment" -}}
{{- $deployment := .deployment | default dict }}
{{- $name := $deployment.name | default .name }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  namespace: {{ $deployment.namespace | default .namespace | default "agentgateway-system" }}
  labels:
    app: {{ $name }}
    {{- with $deployment.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  replicas: {{ $deployment.replicas | default 1 }}
  selector:
    matchLabels:
      app: {{ $name }}
  template:
    metadata:
      labels:
        app: {{ $name }}
        {{- with $deployment.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      containers:
        - name: {{ $name }}
          image: {{ $deployment.image | required "deployment.image is required" }}
          imagePullPolicy: {{ $deployment.imagePullPolicy | default "IfNotPresent" }}
          ports:
            - containerPort: {{ $deployment.port | default 8000 }}
              protocol: TCP
          {{- if $deployment.env }}
          env:
            {{- range $deployment.env }}
            - name: {{ .name }}
              {{- if .value }}
              value: {{ .value | quote }}
              {{- end }}
              {{- if .valueFrom }}
              valueFrom:
                {{- if .valueFrom.secretKeyRef }}
                secretKeyRef:
                  name: {{ .valueFrom.secretKeyRef.name }}
                  key: {{ .valueFrom.secretKeyRef.key }}
                  {{- if .valueFrom.secretKeyRef.optional }}
                  optional: {{ .valueFrom.secretKeyRef.optional }}
                  {{- end }}
                {{- end }}
                {{- if .valueFrom.configMapKeyRef }}
                configMapKeyRef:
                  name: {{ .valueFrom.configMapKeyRef.name }}
                  key: {{ .valueFrom.configMapKeyRef.key }}
                  {{- if .valueFrom.configMapKeyRef.optional }}
                  optional: {{ .valueFrom.configMapKeyRef.optional }}
                  {{- end }}
                {{- end }}
              {{- end }}
            {{- end }}
          {{- end }}
          {{- if $deployment.resources }}
          resources:
            {{- toYaml $deployment.resources | nindent 12 }}
          {{- end }}
          {{- if $deployment.command }}
          command:
            {{- toYaml $deployment.command | nindent 12 }}
          {{- end }}
          {{- if $deployment.args }}
          args:
            {{- toYaml $deployment.args | nindent 12 }}
          {{- end }}
{{- end }}
