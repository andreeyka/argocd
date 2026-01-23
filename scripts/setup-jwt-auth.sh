#!/bin/bash
# Скрипт для настройки JWT аутентификации в agentgateway
# Используется после настройки Keycloak (setup-keycloak.sh)

set -e

# Используем Keycloak через localhost (предполагается, что port-forward уже запущен отдельно)
KEYCLOAK_URL="http://localhost:8080"

echo "Получение JWKS path и issuer URL из Keycloak..."

# Получаем issuer URL (внутренний адрес для использования в кластере)
KEYCLOAK_ISSUER="http://keycloak.keycloak.svc.cluster.local:8080/realms/master"
KEYCLOAK_JWKS_PATH="/realms/master/protocol/openid-connect/certs"

echo "Issuer URL: ${KEYCLOAK_ISSUER}"
echo "JWKS Path: ${KEYCLOAK_JWKS_PATH}"

# Проверяем, что namespace agentgateway-system существует
if ! kubectl get namespace agentgateway-system >/dev/null 2>&1; then
  echo "Ошибка: namespace agentgateway-system не найден"
  exit 1
fi

# Проверяем, что Gateway существует
if ! kubectl get gateway agentgateway-proxy -n agentgateway-system >/dev/null 2>&1; then
  echo "Ошибка: Gateway agentgateway-proxy не найден в namespace agentgateway-system"
  exit 1
fi

echo ""
echo "Создание AgentgatewayPolicy для JWT аутентификации a2a агентов..."

# Получаем список HTTPRoute для a2a агентов
A2A_ROUTES=$(kubectl get httproute -n agentgateway-system -o json | jq -r '.items[] | select(.metadata.name | startswith("a2a")) | .metadata.name')

if [ -z "$A2A_ROUTES" ]; then
  echo "Предупреждение: HTTPRoute для a2a агентов не найдены"
  echo "Создаю политику для известных маршрутов: a2a, a2a-agent2, a2a-agent3"
  A2A_ROUTES="a2a a2a-agent2 a2a-agent3"
fi

# Создаем политику для каждого HTTPRoute
for route in $A2A_ROUTES; do
  echo "Создание политики для HTTPRoute: ${route}..."
  
  cat <<EOF | kubectl apply -f -
apiVersion: networking.agentgateway.dev/v1alpha1
kind: AgentgatewayPolicy
metadata:
  name: jwt-auth-${route}
  namespace: agentgateway-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: ${route}
    namespace: agentgateway-system
  traffic:
    jwtAuthentication:
      mode: Strict
      providers:
      - issuer: "${KEYCLOAK_ISSUER}"
        jwks:
          remote:
            jwksPath: "${KEYCLOAK_JWKS_PATH}"
            cacheDuration: "5m"
            backendRef:
              group: ""
              kind: Service
              name: keycloak
              namespace: keycloak
              port: 8080
EOF
done

echo ""
echo "Ожидание применения политик..."
sleep 3

# Проверяем статус политик
echo ""
echo "Проверка статуса AgentgatewayPolicy..."
for route in $A2A_ROUTES; do
  echo "Политика jwt-auth-${route}:"
  kubectl get AgentgatewayPolicy jwt-auth-${route} -n agentgateway-system -o json | jq '.status' || echo "Статус еще не доступен"
  echo ""
done

echo ""
echo "JWT аутентификация для a2a агентов настроена!"
echo ""
echo "Для проверки:"
echo "1. Получите токен (используйте KEYCLOAK_CLIENT и KEYCLOAK_SECRET из setup-keycloak.sh):"
echo "   ACCESS_TOKEN=\$(curl -s -X POST \"${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token\" \\"
echo "     -H \"Content-Type: application/x-www-form-urlencoded\" \\"
echo "     -d \"grant_type=password\" \\"
echo "     -d \"client_id=\${KEYCLOAK_CLIENT}\" \\"
echo "     -d \"client_secret=\${KEYCLOAK_SECRET}\" \\"
echo "     -d \"username=user1\" \\"
echo "     -d \"password=password\" \\"
echo "     | jq -r '.access_token')"
echo ""
echo "2. Отправьте запрос к a2a агенту с токеном (пример для agent1):"
echo "   curl -v \"http://localhost:8000/a2a/agent1\" -H \"Authorization: Bearer \${ACCESS_TOKEN}\""
echo ""
echo "3. Проверьте, что запрос без токена отклоняется:"
echo "   curl -v \"http://localhost:8000/a2a/agent1\""
echo "   (должен вернуть 401 Unauthorized)"
echo ""
