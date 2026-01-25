#!/bin/bash
# Скрипт для разовой установки CRDs для kgateway/agentgateway
# CRDs устанавливаются один раз при первоначальной настройке кластера

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CRDS_DIR="$PROJECT_ROOT/crds"

echo "🔧 Установка CRDs для kgateway/agentgateway..."
echo ""

# Проверяем наличие стандартных Gateway API CRDs
echo "🔍 Проверка стандартных Gateway API CRDs..."
REQUIRED_GATEWAY_CRDS=(
    "backendtlspolicies.gateway.networking.k8s.io"
    "gatewayclasses.gateway.networking.k8s.io"
    "gateways.gateway.networking.k8s.io"
    "grpcroutes.gateway.networking.k8s.io"
    "httproutes.gateway.networking.k8s.io"
    "referencegrants.gateway.networking.k8s.io"
)

MISSING_CRDS=()
for crd in "${REQUIRED_GATEWAY_CRDS[@]}"; do
    if ! kubectl get crd "$crd" &>/dev/null; then
        MISSING_CRDS+=("$crd")
    fi
done

if [ ${#MISSING_CRDS[@]} -gt 0 ]; then
    echo "⚠️  Внимание: стандартные Gateway API CRDs не установлены!"
    echo "   Установите их перед продолжением:"
    echo ""
    echo "   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml"
    echo ""
    echo "   Отсутствующие CRDs:"
    for crd in "${MISSING_CRDS[@]}"; do
        echo "     - $crd"
    done
    echo ""
    read -p "Продолжить установку CRDs для kgateway/agentgateway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Установка отменена."
        exit 1
    fi
else
    echo "✅ Стандартные Gateway API CRDs установлены"
fi
echo ""

# Проверяем наличие папки с CRDs
if [ ! -d "$CRDS_DIR" ]; then
    echo "❌ Ошибка: папка $CRDS_DIR не найдена"
    exit 1
fi

# Проверяем наличие файлов CRDs
CRD_FILES=$(find "$CRDS_DIR" -name "*.yaml" -type f | grep -v "agentgateway-crds.yaml" | sort)
if [ -z "$CRD_FILES" ]; then
    echo "❌ Ошибка: файлы CRDs не найдены в $CRDS_DIR"
    exit 1
fi

echo "📦 Найдено CRDs файлов: $(echo "$CRD_FILES" | wc -l | tr -d ' ')"
echo ""

# Проверяем подключение к кластеру
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Ошибка: не удалось подключиться к Kubernetes кластеру"
    echo "Убедитесь, что kubectl настроен и кластер доступен"
    exit 1
fi

echo "✅ Подключение к кластеру установлено"
echo ""

# Применяем CRDs
echo "📥 Применение CRDs..."
APPLIED=0
FAILED=0

for crd_file in $CRD_FILES; do
    crd_name=$(basename "$crd_file" .yaml)
    echo -n "  - $crd_name ... "
    
    if kubectl apply -f "$crd_file" &>/dev/null; then
        echo "✅"
        APPLIED=$((APPLIED + 1))
    else
        echo "❌"
        FAILED=$((FAILED + 1))
        echo "    Ошибка при применении: $crd_file"
    fi
done

echo ""
echo "📊 Результат:"
echo "   ✅ Успешно применено: $APPLIED"
if [ $FAILED -gt 0 ]; then
    echo "   ❌ Ошибок: $FAILED"
fi
echo ""

# Проверяем установленные CRDs
echo "🔍 Проверка установленных CRDs:"
kubectl get crd | grep -E "(agentgateway|kgateway)" | awk '{print "   - " $1}'
echo ""

echo "✅ Установка CRDs завершена!"
echo ""
echo "💡 Примечание: CRDs устанавливаются один раз при первоначальной настройке."
echo "   После установки можно удалить приложение agentgateway-crds-helm из ArgoCD."
