#!/bin/bash
# Скрипт для port-forward Gateway прокси

NAMESPACE="kgateway-system"
DEPLOYMENT="kgateway-proxy"
LOCAL_PORT=8080
REMOTE_PORT=80

echo "Запуск port-forward для $DEPLOYMENT в namespace $NAMESPACE..."
echo "Gateway будет доступен на http://localhost:$LOCAL_PORT"
echo "Для остановки нажмите Ctrl+C"
echo ""

kubectl port-forward deployment/$DEPLOYMENT -n $NAMESPACE $LOCAL_PORT:$REMOTE_PORT
