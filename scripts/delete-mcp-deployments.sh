#!/bin/bash
# Скрипт для удаления старых MCP Deployment с неправильным selector
# После удаления они будут автоматически пересозданы ArgoCD с новым selector

set -e

NAMESPACE="${NAMESPACE:-agentgateway-system}"

echo "Удаление старых MCP Deployment с неправильным selector..."
echo "Namespace: $NAMESPACE"

# Удаляем Deployment для каждого сервера
for deployment in ia-mcp-1 ia-mcp-2 ia-mcp-3; do
  if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
    echo "Удаление Deployment: $deployment"
    kubectl delete deployment "$deployment" -n "$NAMESPACE" --wait=false
  else
    echo "Deployment $deployment не найден, пропускаем"
  fi
done

echo ""
echo "Deployment удалены. ArgoCD автоматически пересоздаст их с новым selector."
echo "Проверьте статус: kubectl get deployments -n $NAMESPACE"
