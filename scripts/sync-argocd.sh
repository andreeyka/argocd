#!/bin/bash
# Скрипт для синхронизации ArgoCD приложений

set -e

echo "🔄 Синхронизация ArgoCD приложений..."
echo ""

# Проверяем, установлен ли ArgoCD CLI
if ! command -v argocd &> /dev/null; then
  echo "⚠️  ArgoCD CLI не установлен. Используем kubectl для синхронизации."
  echo ""
  
  # Получаем список приложений
  APPS=$(kubectl get applications -n argocd -o name 2>/dev/null || echo "")
  
  if [ -z "$APPS" ]; then
    echo "❌ Приложения ArgoCD не найдены"
    exit 1
  fi
  
  echo "Найденные приложения:"
  kubectl get applications -n argocd
  echo ""
  echo "Для синхронизации используйте ArgoCD UI или установите ArgoCD CLI:"
  echo "  brew install argocd"
  echo "  или"
  echo "  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
  echo "  chmod +x /usr/local/bin/argocd"
  echo ""
  echo "Или синхронизируйте вручную через ArgoCD UI: https://localhost:9999"
  exit 0
fi

# Проверяем подключение к ArgoCD
if ! argocd app list &> /dev/null; then
  echo "⚠️  Не удалось подключиться к ArgoCD"
  echo "Убедитесь, что:"
  echo "  1. Port-forward для ArgoCD запущен: kubectl port-forward -n argocd svc/argocd-server 9999:443"
  echo "  2. Выполнен вход: argocd login localhost:9999 --insecure"
  exit 1
fi

# Синхронизируем приложение agentgateway
echo "Синхронизация приложения agentgateway..."
argocd app sync agentgateway --async

echo ""
echo "✅ Синхронизация запущена"
echo ""
echo "Проверьте статус:"
echo "  argocd app get agentgateway"
echo ""
echo "Или в ArgoCD UI: https://localhost:9999"
