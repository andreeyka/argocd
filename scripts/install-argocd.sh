#!/bin/bash

set -e

echo "🚀 Начинаем установку ArgoCD..."

# Создаем namespace argocd, если его нет
echo "📁 Создаем namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Функция для скачивания файла с несколькими методами
download_file() {
    local url=$1
    local output=$2
    local max_retries=${3:-10}
    local retry_count=0
    
    # Пробуем curl с расширенными опциями (L - следовать редиректам)
    while [ $retry_count -lt $max_retries ]; do
        if curl -sSLf --connect-timeout 60 --max-time 600 --retry 2 --retry-delay 3 \
           --location --max-redirs 5 \
           -o "$output" "$url" 2>&1; then
            # Проверяем, что файл не пустой
            if [ -s "$output" ]; then
                return 0
            fi
        fi
        
        # Пробуем wget как альтернативу
        if command -v wget &> /dev/null; then
            if wget --timeout=60 --tries=2 --quiet --max-redirect=5 \
               --output-document="$output" "$url" 2>/dev/null; then
                if [ -s "$output" ]; then
                    return 0
                fi
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "⏳ Повторная попытка скачивания ($retry_count/$max_retries)..."
            sleep 5
        fi
    done
    
    return 1
}

# Устанавливаем ArgoCD
echo "📦 Устанавливаем ArgoCD..."

# Пробуем установить через Helm (предпочтительный метод)
if command -v helm &> /dev/null; then
    echo "🔧 Используем Helm для установки ArgoCD..."
    
    # Добавляем репозиторий ArgoCD, если его нет
    if ! helm repo list | grep -q "argo"; then
        echo "📥 Добавляем Helm репозиторий ArgoCD..."
        if helm repo add argo https://argoproj.github.io/argo-helm 2>&1; then
            helm repo update argo 2>&1 || true
        else
            echo "⚠️  Не удалось добавить Helm репозиторий, пробуем прямой метод..."
        fi
    fi
    
    # Пробуем установить через Helm
    if helm repo list | grep -q "argo"; then
        echo "🚀 Устанавливаем ArgoCD через Helm..."
        if helm upgrade --install argocd argo/argo-cd \
            --namespace argocd \
            --create-namespace \
            --version 7.6.5 \
            --set server.service.type=ClusterIP \
            --wait --timeout 10m 2>&1; then
            echo "✅ ArgoCD успешно установлен через Helm"
            INSTALL_METHOD="helm"
        else
            echo "⚠️  Ошибка установки через Helm, пробуем прямой метод..."
            INSTALL_METHOD="direct"
        fi
    else
        INSTALL_METHOD="direct"
    fi
else
    INSTALL_METHOD="direct"
fi

# Если Helm не сработал, пробуем прямой метод
if [ "$INSTALL_METHOD" != "helm" ]; then
    echo "📥 Скачиваем манифесты ArgoCD напрямую..."
    ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml"
    ARGOCD_MANIFEST_FILE="/tmp/argocd-install.yaml"
    ARGOCD_REPO_DIR="/tmp/argo-cd"
    
    MAX_RETRIES=10
    DOWNLOAD_SUCCESS=false
    
    # Пробуем скачать через curl/wget
    if download_file "$ARGOCD_MANIFEST_URL" "$ARGOCD_MANIFEST_FILE" $MAX_RETRIES; then
        echo "✅ Манифесты успешно скачаны"
        DOWNLOAD_SUCCESS=true
    else
        # Пробуем через git clone как альтернативу
        echo "⚠️  Не удалось скачать через curl, пробуем через git..."
        if command -v git &> /dev/null; then
            if [ -d "$ARGOCD_REPO_DIR" ]; then
                rm -rf "$ARGOCD_REPO_DIR"
            fi
            if git clone --depth 1 --branch v2.12.3 https://github.com/argoproj/argo-cd.git "$ARGOCD_REPO_DIR" 2>&1; then
                if [ -f "$ARGOCD_REPO_DIR/manifests/install.yaml" ]; then
                    cp "$ARGOCD_REPO_DIR/manifests/install.yaml" "$ARGOCD_MANIFEST_FILE"
                    rm -rf "$ARGOCD_REPO_DIR"
                    echo "✅ Манифесты успешно скачаны через git"
                    DOWNLOAD_SUCCESS=true
                fi
            fi
        fi
    fi
    
    if [ "$DOWNLOAD_SUCCESS" != true ]; then
        echo "❌ Не удалось скачать манифесты после всех попыток"
        echo ""
        echo "Проблема: TLS handshake обрывается при подключении к GitHub"
        echo "Возможные причины:"
        echo "1. Firewall или сетевое оборудование блокирует соединение"
        echo "2. Проблемы с SSL/TLS сертификатами"
        echo "3. Проблемы с сетевой инфраструктурой"
        echo ""
        echo "Решения:"
        echo "1. Скачайте манифест вручную через браузер:"
        echo "   $ARGOCD_MANIFEST_URL"
        echo "   Сохраните как $ARGOCD_MANIFEST_FILE"
        echo "   Затем выполните: kubectl apply -n argocd -f $ARGOCD_MANIFEST_FILE"
        echo ""
        echo "2. Или используйте Helm (если доступен):"
        echo "   helm repo add argo https://argoproj.github.io/argo-helm"
        echo "   helm install argocd argo/argo-cd -n argocd --create-namespace"
        exit 1
    fi
    
    if [ "$DOWNLOAD_SUCCESS" = true ]; then
        echo "📦 Применяем манифесты ArgoCD..."
        if kubectl apply -n argocd -f "$ARGOCD_MANIFEST_FILE"; then
            echo "✅ Манифесты успешно применены"
            rm -f "$ARGOCD_MANIFEST_FILE"
        else
            echo "❌ Ошибка при применении манифестов"
            rm -f "$ARGOCD_MANIFEST_FILE"
            exit 1
        fi
    fi
fi
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
echo "🔌 Настраиваем port-forward для ArgoCD на порт 9999..."
kubectl -n argocd port-forward svc/argocd-server 9999:443 > /dev/null 2>&1 &
echo "✅ Port-forward запущен в фоновом режиме. ArgoCD доступен на http://localhost:9999"
