# Agentgateway

Установка и управление agentgateway в Kubernetes через ArgoCD.

## Структура проекта

```text
.
├── argocd-apps/                 # ArgoCD Applications
│   ├── crds/                    # Общие CRD (Custom Resource Definitions)
│   │   └── agentgateway-crds-helm.yaml
│   ├── dev/                     # Development окружение
│   │   └── agentgateway.yaml
│   └── prod/                    # Production окружение
│       └── agentgateway.yaml
├── charts/                      # Helm Charts
│   ├── agentgateway-gateway/    # Gateway чарт
│   │   ├── Chart.yaml
│   │   ├── templates/
│   │   │   └── agentgateway-proxy.yaml
│   │   ├── values.yaml          # Базовые значения
│   │   ├── values-dev.yaml      # Переопределения для dev
│   │   └── values-prod.yaml     # Переопределения для prod
│   └── agentgateway-llm/        # LLM провайдеры чарт
│       ├── Chart.yaml
│       ├── templates/
│       │   ├── cloudru-backend.yaml
│       │   └── cloudru-httproute.yaml
│       ├── values.yaml          # Базовые значения
│       ├── values-dev.yaml      # Переопределения для dev
│       └── values-prod.yaml     # Переопределения для prod
├── scripts/                     # Вспомогательные скрипты
│   ├── agentgateway-port-forward-proxy.sh
│   ├── agentgateway-port-forward-ui.sh
│   └── install-argocd.sh
├── pyproject.toml               # Python зависимости (uv)
├── uv.lock                      # Заблокированные версии зависимостей
└── README.md
```

## Запуск с нуля

### Требования

1. **Kubernetes кластер** - создан и настроен, доступен через `kubectl`
2. **Инструменты командной строки:**
   - `kubectl` - для работы с Kubernetes
   - `argo` (опционально) - для работы с ArgoCD CLI

### Шаг 1: Установка ArgoCD

Установите ArgoCD в кластер с помощью скрипта:

```bash
./scripts/install-argocd.sh
```

Скрипт выполняет:

- Создание namespace `argocd`
- Установку ArgoCD из официальных манифестов
- Ожидание готовности всех компонентов
- Установку пароля администратора: `gateway`
- Установку Gateway API CRD
- Настройку port-forward на порт 9999

**Альтернативно вручную:**

```bash
# Создание namespace
kubectl create namespace argocd

# Установка ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml

# Ожидание готовности
kubectl -n argocd rollout status deploy/argocd-applicationset-controller
kubectl -n argocd rollout status deploy/argocd-dex-server
kubectl -n argocd rollout status deploy/argocd-notifications-controller
kubectl -n argocd rollout status deploy/argocd-redis
kubectl -n argocd rollout status deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-server

# Установка пароля администратора (gateway)
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2y$10$f6GlB5V/8OzCduEDEgBU.ugVn4vzxgT7cq7vuCebZAKoADaNve9Ve",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

# Установка Gateway API CRD
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

# Port-forward для доступа к UI
kubectl port-forward svc/argocd-server -n argocd 9999:443
```

### Шаг 2: Доступ к ArgoCD UI

1. Откройте браузер и перейдите на `http://localhost:9999`
2. Войдите с учетными данными:
   - **Username:** `admin`
   - **Password:** `gateway`

### Шаг 3: Установка Agentgateway CRD

Установите Custom Resource Definitions для agentgateway:

```bash
kubectl apply -f argocd-apps/crds/agentgateway-crds-helm.yaml
```

Это создаст ArgoCD Application, которое установит Helm чарт `agentgateway-crds` из OCI registry.

### Шаг 4: Установка Agentgateway

Выберите окружение для установки:

**Для development окружения:**
```bash
kubectl apply -f argocd-apps/dev/agentgateway.yaml
```

**Для production окружения:**
```bash
kubectl apply -f argocd-apps/prod/agentgateway.yaml
```

Это создаст ArgoCD Application, которое:

- Установит Helm чарт `agentgateway` из OCI registry
- Создаст GatewayClass `agentgateway`
- Развернет контроллер и proxy
- Применит Gateway и LLM ресурсы из Git репозитория с соответствующими values файлами (dev или prod)

### Шаг 5: Проверка установки

Проверьте, что все компоненты запущены:

```bash
# Проверка подов control plane
kubectl get pods -n agentgateway-system
```

Ожидаемый вывод:

```txt
NAME                             READY   STATUS    RESTARTS   AGE
agentgateway-helm-6b5bb4db6b-c2pkq   1/1     Running   0          4m4s
```

Проверьте GatewayClass:

```bash
kubectl get gatewayclass agentgateway
```

Проверьте статус в ArgoCD UI - оба Application должны иметь статус `Healthy` и `Synced`.

### Шаг 6: Настройка LLM провайдера (опционально)

Для использования Cloud.ru LLM провайдера создайте Secret с API ключом:

```bash
kubectl apply -f- <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudru-secret
  namespace: agentgateway-system
type: Opaque
stringData:
  Authorization: Bearer your-api-key-here
EOF
```

Затем обновите соответствующий файл values для вашего окружения:
- Для dev: `charts/agentgateway-llm/values-dev.yaml`
- Для prod: `charts/agentgateway-llm/values-prod.yaml`

Раскомментируйте секцию `auth`:

```yaml
llm:
  cloudru:
    backend:
      auth:
        secretRef:
          name: cloudru-secret
```

## Полезные скрипты

### Port-forward к proxy

Для доступа к agentgateway proxy на локальной машине:

```bash
./scripts/agentgateway-port-forward-proxy.sh
```

Gateway будет доступен на `http://localhost:8080`.

### Port-forward к UI

Для доступа к UI для отладки:

```bash
./scripts/agentgateway-port-forward-ui.sh
```

UI будет доступен на портах 9095 и 15000.

## Дополнительная информация

- [Официальная документация Agentgateway](https://agentgateway.dev/docs/kubernetes/latest/)
- [Gateway setup](https://agentgateway.dev/docs/kubernetes/latest/gateway/setup/)
- [LLM consumption](https://agentgateway.dev/docs/kubernetes/latest/llm/consumption/)

## Примечания

- Helm чарты загружаются из OCI registry: `ghcr.io/kgateway-dev/charts`
- Используемая версия: `v2.2.0-main`
- Gateway и LLM ресурсы загружаются из Git репозитория: `https://github.com/andreeyka/argocd`
- Проект поддерживает раздельные конфигурации для dev и prod окружений через отдельные ArgoCD Applications
- Для управления Python зависимостями используется `uv` (см. `pyproject.toml`)
- Параметры Helm для development builds:
  - `controller.image.pullPolicy: Always`
  - `controller.extraEnv.KGW_ENABLE_GATEWAY_API_EXPERIMENTAL_FEATURES: true`
