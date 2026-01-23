#!/bin/bash
# Скрипт для port-forward к UI agentgateway для отладки

echo "🔧 Настройка port-forward для UI agentgateway..."
echo ""

# Control plane admin UI (порт 9095)
echo "📊 Control plane admin UI (порт 9095):"
kubectl port-forward deployment/agentgateway -n agentgateway-system 9095:9095 > /tmp/agentgateway-admin.log 2>&1 &
ADMIN_PID=$!
echo "  ✅ Запущен на http://localhost:9095"
echo "  PID: $ADMIN_PID"
echo "  Доступные endpoints:"
echo "    - http://localhost:9095/debug/pprof - pprof профили"
echo "    - http://localhost:9095/logging - настройка логирования"
echo "    - http://localhost:9095/snapshots/krt - KRT snapshot"
echo ""

# Proxy UI (порт 15000)
echo "🌐 Proxy UI (порт 15000):"
kubectl port-forward deployment/agentgateway-proxy -n agentgateway-system 15000:15000 > /tmp/agentgateway-proxy-ui.log 2>&1 &
PROXY_PID=$!
echo "  ✅ Запущен на http://localhost:15000/ui"
echo "  PID: $PROXY_PID"
echo "  Доступные endpoints:"
echo "    - http://localhost:15000/ui - Read-only UI для просмотра ресурсов"
echo "    - http://localhost:15000/config_dump - Конфигурация proxy"
echo ""

echo "📝 Логи:"
echo "  - Control plane: /tmp/agentgateway-admin.log"
echo "  - Proxy UI: /tmp/agentgateway-proxy-ui.log"
echo ""
echo "🛑 Для остановки выполните:"
echo "  kill $ADMIN_PID $PROXY_PID"
echo ""
echo "Или используйте: pkill -f 'port-forward.*agentgateway'"
