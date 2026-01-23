#!/bin/bash
# Скрипт для port-forward к agentgateway proxy

NAMESPACE="agentgateway-system"
DEPLOYMENT="agentgateway-proxy"
LOCAL_PORT=80
REMOTE_PORT=8080

echo "🔧 Запуск port-forward для $DEPLOYMENT в namespace $NAMESPACE..."
echo "✅ Gateway будет доступен на http://localhost:$LOCAL_PORT"
echo "🛑 Для остановки нажмите Ctrl+C"
echo ""

kubectl port-forward deployment/$DEPLOYMENT -n $NAMESPACE $LOCAL_PORT:$REMOTE_PORT
