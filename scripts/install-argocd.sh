#!/bin/bash

set -e

echo "🚀 Начинаем установку ArgoCD..."

# Создаем namespace argocd, если его нет
echo "📁 Создаем namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Применяем манифесты ArgoCD
echo "📦 Применяем манифесты ArgoCD..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml 2>&1; then
        echo "✅ Манифесты успешно применены"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "⏳ Повторная попытка применения манифестов ($RETRY_COUNT/$MAX_RETRIES)..."
            sleep 2
        else
            echo "❌ Не удалось применить манифесты после $MAX_RETRIES попыток"
            echo "Попробуйте выполнить команду вручную для просмотра ошибок:"
            echo "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml"
            exit 1
        fi
    fi
done
echo ""

# Ждем завершения развертывания всех компонентов
echo "⏳ Ожидаем завершения развертывания компонентов ArgoCD..."

echo "  - argocd-applicationset-controller"
kubectl -n argocd rollout status deploy/argocd-applicationset-controller

echo "  - argocd-dex-server"
kubectl -n argocd rollout status deploy/argocd-dex-server

echo "  - argocd-notifications-controller"
kubectl -n argocd rollout status deploy/argocd-notifications-controller

echo "  - argocd-redis"
kubectl -n argocd rollout status deploy/argocd-redis

echo "  - argocd-repo-server"
kubectl -n argocd rollout status deploy/argocd-repo-server

echo "  - argocd-server"
kubectl -n argocd rollout status deploy/argocd-server

echo ""
echo "🔐 Устанавливаем пароль администратора..."
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2y$10$f6GlB5V/8OzCduEDEgBU.ugVn4vzxgT7cq7vuCebZAKoADaNve9Ve",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

echo ""
echo "✅ ArgoCD успешно установлен и все компоненты развернуты!"

echo ""
echo "🌐 Устанавливаем Gateway API..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

echo ""
echo "✅ Gateway API успешно установлен!"

echo ""
echo "🔌 Настраиваем port-forward для ArgoCD на порт 9999..."
kubectl -n argocd port-forward svc/argocd-server 9999:443 > /dev/null 2>&1 &
echo "✅ Port-forward запущен в фоновом режиме. ArgoCD доступен на http://localhost:9999"
