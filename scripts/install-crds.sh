#!/bin/bash
# Скрипт для разовой установки CRDs для kgateway/agentgateway
# CRDs устанавливаются один раз при первоначальной настройке кластера
# 
# Устанавливает:
# 1. Gateway API CRDs (v1.4.0) - из официального источника Kubernetes SIG
# 2. Agentgateway CRDs - через helm template из официального OCI registry

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Установка CRDs для kgateway/agentgateway..."
echo ""

# Проверяем подключение к кластеру
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Ошибка: не удалось подключиться к Kubernetes кластеру"
    echo "Убедитесь, что kubectl настроен и кластер доступен"
    exit 1
fi

echo "✅ Подключение к кластеру установлено"
echo ""

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

# 1. Установка Gateway API CRDs
GATEWAY_API_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml"
echo "📦 Gateway API CRDs (v1.4.0)"
echo "   Источник: $GATEWAY_API_URL"

REQUIRED_GATEWAY_CRDS=(
    "backendtlspolicies.gateway.networking.k8s.io"
    "gatewayclasses.gateway.networking.k8s.io"
    "gateways.gateway.networking.k8s.io"
    "grpcroutes.gateway.networking.k8s.io"
    "httproutes.gateway.networking.k8s.io"
    "referencegrants.gateway.networking.k8s.io"
)

# Проверяем, какие CRDs уже установлены
MISSING_CRDS=()
INSTALLED_CRDS=()
for crd in "${REQUIRED_GATEWAY_CRDS[@]}"; do
    if kubectl get crd "$crd" &>/dev/null; then
        INSTALLED_CRDS+=("$crd")
    else
        MISSING_CRDS+=("$crd")
    fi
done

if [ ${#MISSING_CRDS[@]} -gt 0 ]; then
    echo "   Статус: установлено ${#INSTALLED_CRDS[@]}/${#REQUIRED_GATEWAY_CRDS[@]}, отсутствует ${#MISSING_CRDS[@]}"
    echo "   Действие: установка отсутствующих CRDs..."
    GATEWAY_API_FILE="/tmp/gateway-api-crds.yaml"
    
    if download_file "$GATEWAY_API_URL" "$GATEWAY_API_FILE" 10; then
        if kubectl apply -f "$GATEWAY_API_FILE" &>/dev/null; then
            echo "   ✅ Успешно установлены все Gateway API CRDs"
            rm -f "$GATEWAY_API_FILE"
        else
            echo "   ❌ Ошибка при установке Gateway API CRDs"
            rm -f "$GATEWAY_API_FILE"
            exit 1
        fi
    else
        echo "   ❌ Не удалось скачать Gateway API CRDs"
        echo "   Попробуйте установить вручную:"
        echo "   kubectl apply -f $GATEWAY_API_URL"
        exit 1
    fi
else
    echo "   Статус: все CRDs установлены (${#INSTALLED_CRDS[@]}/${#REQUIRED_GATEWAY_CRDS[@]})"
    echo "   Действие: пропущено (уже установлено)"
fi
echo ""

# 2. Установка Agentgateway CRDs
AGENTGATEWAY_CRDS_CHART="oci://ghcr.io/kgateway-dev/charts/agentgateway-crds"
AGENTGATEWAY_CRDS_VERSION="v2.2.0-main"
echo "📦 Agentgateway CRDs"
echo "   Источник: $AGENTGATEWAY_CRDS_CHART:$AGENTGATEWAY_CRDS_VERSION"

# Проверяем наличие helm
if ! command -v helm &> /dev/null; then
    echo "   ❌ Ошибка: helm не установлен"
    echo "   Установите helm для установки Agentgateway CRDs"
    echo "   Или установите CRDs вручную из официального Helm chart"
    exit 1
fi

# Проверяем, установлены ли уже Agentgateway CRDs
AGENTGATEWAY_CRDS_FOUND=$(kubectl get crd 2>/dev/null | grep -E "(agentgateway|kgateway)" | wc -l | tr -d ' ')
if [ "$AGENTGATEWAY_CRDS_FOUND" -gt 0 ]; then
    echo "   Статус: найдено CRDs: $AGENTGATEWAY_CRDS_FOUND"
    echo "   Действие: применение обновлений (идемпотентная операция)..."
else
    echo "   Статус: CRDs не найдены"
    echo "   Действие: установка CRDs..."
fi

# kubectl apply идемпотентен, можно безопасно выполнять даже если CRDs уже установлены
if helm template agentgateway-crds "$AGENTGATEWAY_CRDS_CHART" \
    --version "$AGENTGATEWAY_CRDS_VERSION" \
    --skip-crds=false 2>/dev/null | kubectl apply -f - &>/dev/null; then
    echo "   ✅ Agentgateway CRDs успешно применены"
else
    echo "   ❌ Ошибка при установке Agentgateway CRDs"
    echo "   Проверьте доступность Helm chart: $AGENTGATEWAY_CRDS_CHART:$AGENTGATEWAY_CRDS_VERSION"
    exit 1
fi
echo ""

# Проверяем установленные CRDs
echo "🔍 Проверка установленных CRDs:"
echo ""
echo "   Gateway API CRDs:"
kubectl get crd | grep "gateway.networking.k8s.io" | awk '{print "     - " $1}' || echo "     (не найдены)"
echo ""
echo "   Agentgateway CRDs:"
kubectl get crd | grep -E "(agentgateway|kgateway)" | awk '{print "     - " $1}' || echo "     (не найдены)"
echo ""

echo "✅ Установка CRDs завершена!"
echo ""
echo "💡 Примечание: CRDs устанавливаются один раз при первоначальной настройке кластера."
echo "   Они не требуют постоянного управления через ArgoCD."
