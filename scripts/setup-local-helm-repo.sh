#!/bin/bash
# Скрипт для настройки локального Helm репозитория для ArgoCD

echo "📦 Настройка локального Helm репозитория для ArgoCD..."

# Проверка наличия helm
if ! command -v helm &> /dev/null; then
    echo "❌ Helm не установлен. Установите Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Создание директории для чартов
CHARTS_DIR="./argocd/charts"
REPO_DIR="./helm-repo"

echo "🔨 Упаковка Helm чартов..."

# Упаковка всех чартов
for chart_dir in "$CHARTS_DIR"/*/; do
    if [ -f "$chart_dir/Chart.yaml" ]; then
        chart_name=$(basename "$chart_dir")
        echo "  📦 Упаковка $chart_name..."
        helm package "$chart_dir" -d "$REPO_DIR" 2>/dev/null || {
            echo "    ⚠️  Предупреждение: не удалось упаковать $chart_name"
        }
    fi
done

# Создание index.yaml
echo "📋 Создание index.yaml..."
helm repo index "$REPO_DIR" --url http://localhost:8879

echo ""
echo "✅ Helm чарты упакованы в $REPO_DIR"
echo ""
echo "🚀 Запуск локального Helm репозитория на порту 8879..."
echo "   Для остановки нажмите Ctrl+C"
echo ""

# Запуск локального Helm репозитория
cd "$REPO_DIR" || exit 1
python3 -m http.server 8879 2>/dev/null || \
python -m SimpleHTTPServer 8879 2>/dev/null || {
    echo "❌ Не удалось запустить HTTP сервер. Установите Python 3"
    exit 1
}
