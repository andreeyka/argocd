# Agentgateway Keycloak

Helm chart для развертывания Keycloak в качестве провайдера идентификации для JWT аутентификации в agentgateway.

## Описание

Этот chart развертывает Keycloak в namespace `keycloak` с базовой конфигурацией для разработки и тестирования.

**Важно:** По умолчанию включен PostgreSQL для более быстрой и стабильной работы. Keycloak с встроенной H2 базой данных очень медленный при инициализации (может занимать 5+ минут).

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
- `postgresql.enabled` - включить PostgreSQL (по умолчанию `true`)
- `postgresql.auth.username` - пользователь PostgreSQL
- `postgresql.auth.password` - пароль PostgreSQL
- `postgresql.auth.database` - имя базы данных

### Отключение PostgreSQL

Если нужно использовать встроенную H2 базу данных (не рекомендуется), установите:

```yaml
postgresql:
  enabled: false
```

**Внимание:** H2 база данных очень медленная при инициализации и не рекомендуется для production.

## Production

Для production окружения используйте `values-prod.yaml`, который настраивает:

- Больше реплик для высокой доступности
- Увеличенные ресурсы для Keycloak и PostgreSQL
- PostgreSQL включен по умолчанию

**Рекомендации для production:**

- Используйте внешний PostgreSQL с персистентным хранилищем (PersistentVolume)
- Настройте резервное копирование базы данных
- Используйте сильные пароли (настройте через Secret)
- Рассмотрите использование внешнего LoadBalancer или Ingress
