#!/bin/bash
# Скрипт для тестирования JWT аутентификации на a2a агентах

set -e

KEYCLOAK_URL="http://localhost:8080"
KEYCLOAK_CLIENT="agentgateway"
KEYCLOAK_SECRET="QlCjfI6prc8ncTdzF05xAv6KZBlEAPLt"

# A2A агенты для тестирования
A2A_ROUTES=(
  "http://localhost:8000/a2a/agent1"
  "http://localhost:8000/a2a/agent2"
  "http://localhost:8000/a2a/agent3"
)

echo "🔐 Тестирование JWT аутентификации"
echo ""

# Проверяем доступность Keycloak
echo "Проверка доступности Keycloak..."
if ! curl -s -f "${KEYCLOAK_URL}/realms/master" >/dev/null 2>&1; then
  echo "❌ Keycloak недоступен на ${KEYCLOAK_URL}"
  echo "   Убедитесь, что port-forward запущен: kubectl port-forward -n keycloak svc/keycloak 8080:8080"
  exit 1
fi
echo "✅ Keycloak доступен"
echo ""

# Получаем токен для user1
echo "Получение токена для user1..."
echo "  Client ID: ${KEYCLOAK_CLIENT}"
echo "  Username: user1"
echo ""

TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${KEYCLOAK_CLIENT}" \
  -d "client_secret=${KEYCLOAK_SECRET}" \
  -d "username=user1" \
  -d "password=password")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')
ERROR_DESCRIPTION=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // empty')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Не удалось получить токен"
  if [ -n "$ERROR" ]; then
    echo "   Ошибка: ${ERROR}"
    if [ -n "$ERROR_DESCRIPTION" ]; then
      echo "   Описание: ${ERROR_DESCRIPTION}"
    fi
  else
    echo "   Ответ от Keycloak:"
    echo "$TOKEN_RESPONSE" | jq '.' 2>/dev/null || echo "$TOKEN_RESPONSE"
  fi
  echo ""
  echo "💡 Возможные причины:"
  echo "   - Клиент '${KEYCLOAK_CLIENT}' не существует или не настроен"
  echo "   - Неверный client_secret"
  echo "   - У клиента не включен 'Direct Access Grants'"
  echo "   - Пользователь user1 не существует"
  echo ""
  echo "   Попробуйте запустить: ./scripts/setup-keycloak.sh"
  exit 1
fi
echo "✅ Токен получен"
echo ""

# Тестируем каждый маршрут
for route in "${A2A_ROUTES[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Тестирование: ${route}"
  echo ""
  
  # Запрос без токена (должен быть 401)
  echo "  📤 Запрос без токена..."
  NO_TOKEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${route}")
  if [ "$NO_TOKEN_CODE" = "401" ]; then
    echo "  ✅ Ожидаемый ответ: 401 Unauthorized"
  else
    echo "  ❌ Неожиданный ответ: ${NO_TOKEN_CODE} (ожидался 401)"
  fi
  echo ""
  
  # Запрос с токеном (должен быть 200)
  echo "  📤 Запрос с токеном..."
  WITH_TOKEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ACCESS_TOKEN}" "${route}")
  if [ "$WITH_TOKEN_CODE" = "200" ]; then
    echo "  ✅ Успешный ответ: 200 OK"
  else
    echo "  ❌ Неожиданный ответ: ${WITH_TOKEN_CODE} (ожидался 200)"
    echo "  💡 Возможные причины:"
    echo "     - Неверный issuer в токене (проверьте issuer в values.yaml)"
    echo "     - Политика не применена к HTTPRoute"
    echo "     - Проблема с JWKS endpoint"
  fi
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Итоги тестирования:"
echo "   - Запросы без токена должны возвращать 401"
echo "   - Запросы с токеном должны возвращать 200"
echo ""
