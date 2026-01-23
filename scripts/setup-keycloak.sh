#!/bin/bash
# Скрипт для настройки Keycloak после развертывания
# Создает тестовых пользователей и клиента для JWT аутентификации

set -e

# Ожидаем готовности Keycloak
echo "Ожидание готовности Keycloak..."
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s

# Используем Keycloak через localhost (предполагается, что port-forward уже запущен отдельно)
KEYCLOAK_URL="http://localhost:8080"
echo "Keycloak URL: ${KEYCLOAK_URL}"

# Получаем admin token
echo "Получение admin token..."
KEYCLOAK_TOKEN=$(curl -s -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" | jq -r .access_token)

if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
  echo "Ошибка: не удалось получить admin token"
  exit 1
fi

echo "Admin token получен"

# Используем фиксированные Client ID / Secret для тестов (можно переопределить через env)
KEYCLOAK_CLIENT=${KEYCLOAK_CLIENT:-agentgateway}
KEYCLOAK_SECRET=${KEYCLOAK_SECRET:-QlCjfI6prc8ncTdzF05xAv6KZBlEAPLt}
echo "Client ID: ${KEYCLOAK_CLIENT}"

# Ищем клиента по clientId
CLIENT_INTERNAL_ID=$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/master/clients?clientId=${KEYCLOAK_CLIENT}" | jq -r '.[0].id')

if [ -z "$CLIENT_INTERNAL_ID" ] || [ "$CLIENT_INTERNAL_ID" = "null" ]; then
  echo "Клиент не найден, создаем..."
  curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" \
    -d "{\"clientId\": \"${KEYCLOAK_CLIENT}\", \"secret\": \"${KEYCLOAK_SECRET}\", \"protocol\": \"openid-connect\", \"publicClient\": false, \"serviceAccountsEnabled\": true, \"directAccessGrantsEnabled\": true, \"authorizationServicesEnabled\": true, \"redirectUris\": [\"*\"]}" \
    "${KEYCLOAK_URL}/admin/realms/master/clients"
  CLIENT_INTERNAL_ID=$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/master/clients?clientId=${KEYCLOAK_CLIENT}" | jq -r '.[0].id')
else
  echo "Клиент найден, обновляем..."
  # Получаем текущую конфигурацию клиента
  CURRENT_CONFIG=$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/master/clients/${CLIENT_INTERNAL_ID}")
  
  # Обновляем конфигурацию, сохраняя существующие поля и добавляя нужные
  UPDATED_CONFIG=$(echo "$CURRENT_CONFIG" | jq '. + {
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": true,
    "authorizationServicesEnabled": true,
    "redirectUris": ["*"],
    "publicClient": false
  }')
  
  curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" \
    -d "$UPDATED_CONFIG" \
    "${KEYCLOAK_URL}/admin/realms/master/clients/${CLIENT_INTERNAL_ID}"
  
  echo "Настройки клиента обновлены"
fi

if [ -z "$CLIENT_INTERNAL_ID" ] || [ "$CLIENT_INTERNAL_ID" = "null" ]; then
  echo "Ошибка: не удалось получить ID клиента"
  exit 1
fi

ACTUAL_SECRET=$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/master/clients/${CLIENT_INTERNAL_ID}/client-secret" | jq -r .value)
if [ -n "$ACTUAL_SECRET" ] && [ "$ACTUAL_SECRET" != "null" ] && [ "$ACTUAL_SECRET" != "$KEYCLOAK_SECRET" ]; then
  echo "Предупреждение: секрет в Keycloak отличается от заданного. Используется фактический секрет."
  KEYCLOAK_SECRET=$ACTUAL_SECRET
fi
echo "Client Secret: ${KEYCLOAK_SECRET}"

# Добавляем group атрибут в JWT токен
echo "Добавление group атрибута в JWT токен..."
curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' "${KEYCLOAK_URL}/admin/realms/master/clients/${CLIENT_INTERNAL_ID}/protocol-mappers/models"

# Создаем первого пользователя
echo "Создание пользователя user1..."
curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@example.com", "firstName": "Alice", "lastName": "Doe", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' "${KEYCLOAK_URL}/admin/realms/master/users"

# Создаем второго пользователя
echo "Создание пользователя user2..."
curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user2", "email": "user2@example.com", "firstName": "Bob", "lastName": "Doe", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' "${KEYCLOAK_URL}/admin/realms/master/users"

# Удаляем trusted-hosts политику (только для тестирования)
echo "Удаление trusted-hosts политики..."
trusted_hosts=$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" "${KEYCLOAK_URL}/admin/realms/master/components?type=org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy" | jq -r 'if type=="array" then .[] | select(.providerId=="trusted-hosts") | .id else empty end')
if [ -n "$trusted_hosts" ]; then
  curl -s -X DELETE -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" "${KEYCLOAK_URL}/admin/realms/master/components/${trusted_hosts}"
fi

# Удаляем allowed-client-templates политику (только для тестирования)
echo "Удаление allowed-client-templates политики..."
allowed_client_templates=$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" "${KEYCLOAK_URL}/admin/realms/master/components?type=org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy" | jq -r '.[] | select(.providerId=="allowed-client-templates" and .subType=="anonymous") | .id')
if [ -n "$allowed_client_templates" ]; then
  curl -s -X DELETE -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" "${KEYCLOAK_URL}/admin/realms/master/components/${allowed_client_templates}"
fi

echo ""
echo "Настройка Keycloak завершена!"
echo "Client ID: ${KEYCLOAK_CLIENT}"
echo "Client Secret: ${KEYCLOAK_SECRET}"
echo ""
echo "Тестовые пользователи:"
echo "  user1 / password"
echo "  user2 / password"
echo ""
echo "Keycloak URL: ${KEYCLOAK_URL}"
