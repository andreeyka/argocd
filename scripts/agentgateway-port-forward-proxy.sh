#!/bin/bash
# Скрипт для port-forward к agentgateway proxy

NAMESPACE="agentgateway-system"
DEPLOYMENT="agentgateway-proxy"
LOCAL_PORT=80
REMOTE_PORT=8080

# Останавливаем старые port-forward процессы на этом порту
echo "🛑 Остановка старых port-forward процессов на порту $LOCAL_PORT..."
pkill -f "port-forward.*$LOCAL_PORT" 2>/dev/null || true
sleep 1

echo "🔧 Запуск port-forward для $DEPLOYMENT в namespace $NAMESPACE..."
echo "✅ Gateway будет доступен на http://localhost:$LOCAL_PORT"
echo "🛑 Для остановки нажмите Ctrl+C"
echo ""

kubectl port-forward deployment/$DEPLOYMENT -n $NAMESPACE $LOCAL_PORT:$REMOTE_PORT
