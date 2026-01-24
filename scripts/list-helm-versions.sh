#!/bin/bash

# Скрипт для получения списка версий Helm чарта из OCI репозитория
# Использование: ./scripts/list-helm-versions.sh [chart-name] [registry]
#
# Примеры:
#   ./scripts/list-helm-versions.sh kgateway
#   ./scripts/list-helm-versions.sh kgateway cr.kgateway.dev/kgateway-dev/charts

set -e

CHART_NAME="${1:-kgateway}"
REGISTRY="${2:-cr.kgateway.dev/kgateway-dev/charts}"
REGISTRY_HOST="${REGISTRY%%/*}"
CHART_URL="oci://${REGISTRY}/${CHART_NAME}"

echo "Поиск версий чарта: ${CHART_NAME}"
echo "Реестр: ${REGISTRY}"
echo ""

# Метод 1: Попытка получить список через OCI API
echo "=== Метод 1: OCI API ==="
API_RESPONSE=$(curl -s "https://${REGISTRY}/v2/${CHART_NAME}/tags/list" 2>/dev/null)

# Проверяем, есть ли ошибка аутентификации
if echo "$API_RESPONSE" | jq -e '.errors[]? | select(.code == "UNAUTHORIZED")' >/dev/null 2>&1; then
    echo "⚠ OCI API требует аутентификацию"
    echo ""
    echo "Для использования OCI API с аутентификацией выполните:"
    echo "  helm registry login ${REGISTRY_HOST}"
    echo ""
    echo "Затем получите список версий:"
    echo "  curl -H \"Authorization: Bearer \$(helm registry token)\" \\"
    echo "    https://${REGISTRY}/v2/${CHART_NAME}/tags/list | jq .tags"
elif [ -n "$API_RESPONSE" ] && echo "$API_RESPONSE" | jq -e '.tags' >/dev/null 2>&1; then
    echo "✓ Список версий получен через OCI API:"
    echo "$API_RESPONSE" | jq -r '.tags[]?' | head -20
    exit 0
else
    echo "⚠ Не удалось получить список через OCI API (требуется аутентификация)"
fi

echo ""
echo "=== Метод 2: Проверка известных версий ==="
echo "Проверка доступности версий..."

# Попытка получить информацию о последних версиях
KNOWN_VERSIONS=(
    "v2.2.0-main"
    "v2.2.0"
    "v2.1.2"
    "v2.1.1"
    "v2.1.0"
    "v2.0.0"
    "latest"
    "main"
)

AVAILABLE_VERSIONS=()

for version in "${KNOWN_VERSIONS[@]}"; do
    if helm show chart "${CHART_URL}" --version "${version}" >/dev/null 2>&1; then
        CHART_VERSION=$(helm show chart "${CHART_URL}" --version "${version}" 2>/dev/null | grep "^version:" | awk '{print $2}' || echo "${version}")
        AVAILABLE_VERSIONS+=("${version}")
        echo "✓ Версия ${version} доступна (chart version: ${CHART_VERSION})"
    else
        echo "✗ Версия ${version} недоступна"
    fi
done

echo ""
if [ ${#AVAILABLE_VERSIONS[@]} -gt 0 ]; then
    echo "Найденные доступные версии:"
    printf '  - %s\n' "${AVAILABLE_VERSIONS[@]}"
    echo ""
    echo "Для получения информации о конкретной версии:"
    echo "  helm show chart ${CHART_URL} --version <VERSION>"
else
    echo "⚠ Не удалось найти доступные версии автоматически"
    echo ""
    echo "Попробуйте вручную проверить версию:"
    echo "  helm show chart ${CHART_URL} --version <VERSION>"
    echo ""
    echo "Или используйте OCI API с аутентификацией:"
    echo "  helm registry login ${REGISTRY_HOST}"
    echo "  curl -H \"Authorization: Bearer \$(helm registry token)\" \\"
    echo "    https://${REGISTRY}/v2/${CHART_NAME}/tags/list | jq .tags"
fi
