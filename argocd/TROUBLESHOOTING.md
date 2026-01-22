# Troubleshooting ArgoCD Applications

## Проблема: CRD gatewayparameters.gateway.kgateway.dev не устанавливается

### Симптомы

```
Resource not found in cluster: apiextensions.k8s.io/v1/CustomResourceDefinition:gatewayparameters.gateway.kgateway.dev
```

Или в статусе Application:
```
message: 'one or more objects failed to apply, reason: CustomResourceDefinition.apiextensions.k8s.io
"gatewayparameters.gateway.kgateway.dev" is invalid: metadata.annotations: Too
long: may not be more than 262144 bytes.'
```

### Причина

Некоторые CRD (особенно `gatewayparameters.gateway.kgateway.dev`) имеют очень большие аннотации, которые превышают лимит Kubernetes в 262144 байта. Обычный client-side apply не может обработать такие ресурсы.

### Решение

Использовать Server-Side Apply в ArgoCD. Это уже настроено в `kgateway-crds-helm.yaml` через опцию `ServerSideApply=true` в `syncOptions`.

### Проверка

После применения Application с `ServerSideApply=true`, проверьте статус:

```bash
kubectl get application kgateway-crds-helm -n argocd
kubectl get crd gatewayparameters.gateway.kgateway.dev
```

### Альтернативное решение для конкретного ресурса

Если нужно применить Server-Side Apply только к конкретному CRD, можно добавить аннотацию в Helm chart:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: gatewayparameters.gateway.kgateway.dev
  annotations:
    argocd.argoproj.io/sync-options: ServerSideApply=true
```

Но в нашем случае проще использовать опцию для всего Application.
