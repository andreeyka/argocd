# Agentgateway JWT Authentication

Helm chart для настройки JWT аутентификации в agentgateway через AgentgatewayPolicy.

## Описание

Этот chart создает `AgentgatewayPolicy` ресурс, который настраивает JWT аутентификацию для Gateway в agentgateway.

## Конфигурация

### Режимы аутентификации

- `Strict` - требует валидный JWT для всех запросов (по умолчанию)
- `Optional` - валидирует JWT если он предоставлен, но разрешает запросы без токена
- `Permissive` - никогда не отклоняет запросы, даже с невалидными токенами

### Провайдеры JWT

Chart поддерживает настройку одного или нескольких провайдеров JWT. Каждый провайдер должен иметь:

- `issuer` - URL издателя токенов (должен совпадать с `iss` claim в JWT)
- `audiences` - список разрешенных аудиторий (опционально)
- `jwks.remote` - конфигурация для получения JWKS с удаленного сервера
  - `jwksPath` - путь к JWKS endpoint
  - `cacheDuration` - время кеширования ключей
  - `backendRef` - ссылка на Kubernetes сервис

### Пример получения токена

После настройки Keycloak, можно получить токен:

```bash
# Получить endpoint Keycloak
KEYCLOAK_URL="http://keycloak.keycloak.svc.cluster.local:8080"
KEYCLOAK_CLIENT="your-client-id"
KEYCLOAK_SECRET="your-client-secret"

# Получить токен
ACCESS_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${KEYCLOAK_CLIENT}" \
  -d "client_secret=${KEYCLOAK_SECRET}" \
  -d "username=user1" \
  -d "password=password" \
  | jq -r '.access_token')

# Использовать токен в запросе
curl -H "Authorization: Bearer ${ACCESS_TOKEN}" http://your-gateway/your-path
```

## Проверка работы

1. Запрос без токена должен вернуть 401:
```bash
curl -v http://your-gateway/your-path
```

2. Запрос с валидным токеном должен вернуть 200:
```bash
curl -v -H "Authorization: Bearer ${ACCESS_TOKEN}" http://your-gateway/your-path
```

## Множественные провайдеры

Для настройки нескольких провайдеров JWT, добавьте их в `values.yaml`:

```yaml
jwtAuth:
  policy:
    providers:
      - issuer: "http://keycloak.keycloak.svc.cluster.local:8080/realms/master"
        audiences: ["my-application"]
        jwks:
          remote:
            jwksPath: "/realms/master/protocol/openid-connect/certs"
            backendRef:
              name: keycloak
              namespace: keycloak
              port: 8080
      - issuer: "https://auth0.example.com/"
        audiences: ["my-other-application"]
        jwks:
          remote:
            jwksPath: "/.well-known/jwks.json"
            backendRef:
              name: auth0-proxy
              namespace: auth-system
              port: 443
```
