#!/bin/bash
# Скрипт для ручной установки CRD gatewayparameters с использованием --server-side

echo "🔧 Установка CRD gatewayparameters.gateway.kgateway.dev через Server-Side Apply..."

# Попытка получить CRD из Helm chart
echo "📦 Получение CRD из Helm chart..."

# Используем helm pull для получения chart
CHART_DIR=$(mktemp -d)
trap "rm -rf $CHART_DIR" EXIT

helm pull oci://ghcr.io/kgateway-dev/charts/kgateway-crds --version v2.2.0-main --untar --untardir $CHART_DIR 2>/dev/null || {
    echo "❌ Не удалось загрузить Helm chart. Убедитесь, что Helm установлен и настроен доступ к OCI registry."
    exit 1
}

# Ищем CRD файл
CRD_FILE=$(find $CHART_DIR -name "*gatewayparameters*.yaml" -o -name "*gatewayparameters*.yml" | head -1)

if [ -z "$CRD_FILE" ]; then
    echo "⚠️  CRD файл не найден в chart. Попытка извлечь из templates..."
    # Пробуем извлечь из templates
    helm template kgateway-crds $CHART_DIR/kgateway-crds --version v2.2.0-main 2>/dev/null | \
        awk '/^---$/{flag=0} /kind: CustomResourceDefinition.*gatewayparameters/{flag=1} flag' > /tmp/gatewayparameters-crd.yaml
    
    if [ -s /tmp/gatewayparameters-crd.yaml ]; then
        CRD_FILE=/tmp/gatewayparameters-crd.yaml
    else
        echo "❌ Не удалось извлечь CRD из chart"
        exit 1
    fi
fi

echo "📄 Применение CRD с --server-side флагом..."
kubectl apply --server-side --force-conflicts -f "$CRD_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ CRD успешно установлен!"
    kubectl get crd gatewayparameters.gateway.kgateway.dev
else
    echo "❌ Ошибка при установке CRD"
    exit 1
fi
