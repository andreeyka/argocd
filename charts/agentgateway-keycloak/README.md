# Agentgateway Keycloak

Helm chart для развертывания Keycloak в качестве провайдера идентификации для JWT аутентификации в agentgateway.

## Описание

Этот chart развертывает Keycloak в namespace `keycloak` с базовой конфигурацией для разработки и тестирования.

## Установка

Chart автоматически развертывается через ArgoCD приложение `keycloak`.

## Настройка после развертывания

После развертывания Keycloak необходимо выполнить первоначальную настройку:

```bash
./scripts/setup-keycloak.sh
```

Скрипт создаст:

- Тестового клиента для OIDC
- Двух тестовых пользователей (user1/user2 с паролем `password`)

## Доступ к Keycloak

После развертывания Keycloak будет доступен через LoadBalancer сервис или port-forward:

```bash
kubectl port-forward -n keycloak svc/keycloak 8080:8080
```

Затем откройте в браузере: <http://localhost:8080>

**Учетные данные администратора:**

- Username: `admin`
- Password: `admin`

## Конфигурация

Основные параметры настраиваются в `values.yaml`:

- `keycloak.namespace` - namespace для развертывания (по умолчанию `keycloak`)
- `keycloak.deployment.replicas` - количество реплик
- `keycloak.deployment.image` - образ Keycloak
- `keycloak.service.type` - тип сервиса (LoadBalancer, NodePort, ClusterIP)

## Production

Для production окружения используйте `values-prod.yaml`, который настраивает:

- Больше реплик для высокой доступности
- Увеличенные ресурсы
- Рекомендуется использовать внешнюю базу данных вместо встроенной H2
