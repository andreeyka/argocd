#!/bin/bash
# Скрипт для запуска локального Helm репозитория (после упаковки чартов)

REPO_DIR="./helm-repo"

if [ ! -d "$REPO_DIR" ]; then
    echo "❌ Директория $REPO_DIR не найдена"
    echo "Сначала запустите: ./scripts/setup-local-helm-repo.sh"
    exit 1
fi

echo "🚀 Запуск локального Helm репозитория на http://localhost:8879"
echo "   Для остановки нажмите Ctrl+C"
echo ""

cd "$REPO_DIR" || exit 1
python3 -m http.server 8879 2>/dev/null || \
python -m SimpleHTTPServer 8879 2>/dev/null || {
    echo "❌ Не удалось запустить HTTP сервер. Установите Python 3"
    exit 1
}
