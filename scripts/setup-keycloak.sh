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

# Создаем initial token для регистрации клиента
echo "Создание initial token для регистрации клиента..."
read -r client token <<<$(curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' "${KEYCLOAK_URL}/admin/realms/master/clients-initial-access" | jq -r '[.id, .token] | @tsv')
KEYCLOAK_CLIENT=${client}
echo "Client ID: ${KEYCLOAK_CLIENT}"

# Регистрируем клиента
echo "Регистрация клиента..."
read -r id secret <<<$(curl -s -k -X POST -d "{ \"clientId\": \"${KEYCLOAK_CLIENT}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${token}" "${KEYCLOAK_URL}/realms/master/clients-registrations/default" | jq -r '[.id, .secret] | @tsv')
KEYCLOAK_SECRET=${secret}
echo "Client Secret: ${KEYCLOAK_SECRET}"

# Настраиваем клиента
echo "Настройка клиента..."
curl -s -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["*"]}' "${KEYCLOAK_URL}/admin/realms/master/clients/${id}"

# Добавляем group атрибут в JWT токен
echo "Добавление group атрибута в JWT токен..."
curl -s -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' "${KEYCLOAK_URL}/admin/realms/master/clients/${id}/protocol-mappers/models"

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
