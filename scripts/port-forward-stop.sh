#!/bin/bash
# Скрипт для остановки всех port-forward'ов для agentgateway

echo "🛑 Остановка всех port-forward'ов для agentgateway..."
echo ""

# Останавливаем по PID файлу, если он существует
PID_FILE="/tmp/agentgateway-port-forwards.pid"
if [ -f "$PID_FILE" ]; then
  PIDS=$(cat $PID_FILE)
  echo "Остановка процессов из PID файла: $PIDS"
  for pid in $PIDS; do
    if kill -0 $pid 2>/dev/null; then
      kill $pid 2>/dev/null && echo "  ✅ Остановлен процесс $pid" || echo "  ⚠️  Не удалось остановить процесс $pid"
    fi
  done
  rm -f $PID_FILE
fi

# Останавливаем все port-forward процессы для agentgateway, keycloak и argocd
echo "Остановка всех port-forward процессов..."
pkill -f "port-forward.*agentgateway" 2>/dev/null && echo "  ✅ Остановлены port-forward для agentgateway" || echo "  ℹ️  Не найдено процессов для agentgateway"
pkill -f "port-forward.*keycloak" 2>/dev/null && echo "  ✅ Остановлены port-forward для keycloak" || echo "  ℹ️  Не найдено процессов для keycloak"
pkill -f "port-forward.*argocd" 2>/dev/null && echo "  ✅ Остановлены port-forward для ArgoCD" || echo "  ℹ️  Не найдено процессов для ArgoCD"

sleep 1

echo ""
echo "✅ Все port-forward'ы остановлены!"
