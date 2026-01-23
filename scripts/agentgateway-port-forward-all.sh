#!/bin/bash
# Скрипт для запуска всех port-forward'ов для agentgateway

echo "🔧 Запуск всех port-forward'ов для agentgateway..."
echo ""

# Останавливаем старые port-forward процессы
echo "🛑 Остановка старых port-forward процессов..."
pkill -f "port-forward.*agentgateway" 2>/dev/null || true
pkill -f "port-forward.*keycloak" 2>/dev/null || true
pkill -f "port-forward.*argocd" 2>/dev/null || true
sleep 2

# Proxy (порт 8000)
echo "🌐 Запуск port-forward для Proxy (порт 8000)..."
kubectl port-forward deployment/agentgateway-proxy -n agentgateway-system 8000:80 > /tmp/agentgateway-proxy.log 2>&1 &
PROXY_PID=$!
echo "  ✅ Proxy доступен на http://localhost:8000"
echo "  PID: $PROXY_PID"
echo ""

# Keycloak (порт 8080)
echo "🔐 Запуск port-forward для Keycloak (порт 8080)..."
kubectl port-forward -n keycloak svc/keycloak 8080:8080 > /tmp/keycloak.log 2>&1 &
KEYCLOAK_PID=$!
echo "  ✅ Keycloak доступен на http://localhost:8080"
echo "  PID: $KEYCLOAK_PID"
echo ""

# Control plane admin UI (порт 9095)
echo "📊 Запуск port-forward для Control plane admin UI (порт 9095)..."
kubectl port-forward deployment/agentgateway -n agentgateway-system 9095:9095 > /tmp/agentgateway-admin.log 2>&1 &
ADMIN_PID=$!
echo "  ✅ Control plane admin UI доступен на http://localhost:9095"
echo "  PID: $ADMIN_PID"
echo ""

# Proxy UI (порт 15000)
echo "🌐 Запуск port-forward для Proxy UI (порт 15000)..."
kubectl port-forward deployment/agentgateway-proxy -n agentgateway-system 15000:15000 > /tmp/agentgateway-proxy-ui.log 2>&1 &
PROXY_UI_PID=$!
echo "  ✅ Proxy UI доступен на http://localhost:15000/ui"
echo "  PID: $PROXY_UI_PID"
echo ""

# ArgoCD (порт 9999)
echo "🚀 Запуск port-forward для ArgoCD (порт 9999)..."
kubectl port-forward -n argocd svc/argocd-server 9999:443 > /tmp/argocd.log 2>&1 &
ARGOCD_PID=$!
echo "  ✅ ArgoCD доступен на https://localhost:9999"
echo "  PID: $ARGOCD_PID"
echo ""

# Сохраняем PID'ы в файл для последующей остановки
PID_FILE="/tmp/agentgateway-port-forwards.pid"
echo "$PROXY_PID $KEYCLOAK_PID $ADMIN_PID $PROXY_UI_PID $ARGOCD_PID" > $PID_FILE

echo "📝 Логи:"
echo "  - Proxy: /tmp/agentgateway-proxy.log"
echo "  - Keycloak: /tmp/keycloak.log"
echo "  - Control plane: /tmp/agentgateway-admin.log"
echo "  - Proxy UI: /tmp/agentgateway-proxy-ui.log"
echo "  - ArgoCD: /tmp/argocd.log"
echo ""
echo "📋 Доступные сервисы:"
echo "  - Proxy: http://localhost:8000"
echo "  - Keycloak: http://localhost:8080"
echo "  - Control plane admin UI: http://localhost:9095"
echo "  - Proxy UI: http://localhost:15000/ui"
echo "  - ArgoCD: https://localhost:9999 (admin/gateway)"
echo ""
echo "🛑 Для остановки всех port-forward'ов выполните:"
echo "  ./scripts/agentgateway-port-forward-stop.sh"
echo ""
echo "Или используйте:"
echo "  kill $PROXY_PID $KEYCLOAK_PID $ADMIN_PID $PROXY_UI_PID $ARGOCD_PID"
echo "  pkill -f 'port-forward.*agentgateway'"
echo "  pkill -f 'port-forward.*keycloak'"
echo "  pkill -f 'port-forward.*argocd'"
echo ""
echo "✅ Все port-forward'ы запущены!"
