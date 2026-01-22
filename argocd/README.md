# ArgoCD Applications

Эта директория содержит конфигурации ArgoCD Applications для проекта kgateway. Все компоненты управляются через ArgoCD и будут видны в ArgoCD UI.

## Структура

```
argocd/
├── applications/          # Готовые Application манифесты
│   ├── kgateway-crds-helm.yaml
│   ├── kgateway-helm.yaml
│   ├── kgateway-gateway.yaml
│   └── kgateway-llm-cloudru.yaml
├── charts/                # Helm чарты для Applications
│   ├── kgateway-crds-helm/
│   ├── kgateway-helm/
│   ├── kgateway-gateway/
│   └── kgateway-llm-cloudru/
└── README.md

gateway/
└── kgateway-proxy.yaml    # Gateway манифест (используется через Helm)

llm/
├── cloudru-secret.yaml    # Secret для API ключа (используется через Helm)
├── cloudru-backend.yaml   # AgentgatewayBackend (используется через Helm)
└── cloudru-httproute.yaml # HTTPRoute (используется через Helm)
```

## Applications

### kgateway-crds-helm

Application для установки CRD (Custom Resource Definitions) через Helm чарт из OCI registry.

**Важно**: Использует `ServerSideApply=true` для работы с большими CRD (например, `gatewayparameters.gateway.kgateway.dev`), которые могут иметь аннотации больше 262144 байт.

### kgateway-helm

Application для установки основного kgateway контроллера через Helm чарт с параметрами:

- `controller.image.pullPolicy: Always`
- `controller.extraEnv.KGW_ENABLE_GATEWAY_API_EXPERIMENTAL_FEATURES: true`

### kgateway-gateway

Application для создания Gateway прокси согласно [документации Gateway setup](https://kgateway.dev/docs/agentgateway/main/setup/). Использует directory source из Git репозитория (путь `gateway/`) для создания Gateway ресурса с:

- `gatewayClassName: kgateway`
- HTTP listener на порту 80
- Разрешенные маршруты из всех namespace

### kgateway-llm-cloudru

Application для настройки OpenAI-совместимого LLM провайдера Cloud.ru согласно [документации OpenAI-compatible providers](https://kgateway.dev/docs/agentgateway/main/llm/providers/openai-compatible/). Использует directory source из Git репозитория (путь `llm/`). Создает:

- Secret для хранения API ключа
- AgentgatewayBackend для подключения к API `https://foundation-models.api.cloud.ru/v1`
- HTTPRoute для маршрутизации запросов на путь `/cloudru`

## Установка через ArgoCD

### Подготовка Git репозитория

**Шаг 1**: Репозиторий уже настроен: `https://github.com/andreeyka/argocd`

**Шаг 2**: Закоммитить и запушить код в GitHub:

```bash
git init
git add .
git commit -m "Initial commit: ArgoCD Applications for kgateway"
git branch -M main
git remote add origin git@github.com:andreeyka/argocd.git
git push -u origin main
```

### Применение Applications

После того как код загружен в GitHub, примените все Applications:

```bash
# Установка CRD
kubectl apply -f argocd/applications/kgateway-crds-helm.yaml

# Установка основного контроллера
kubectl apply -f argocd/applications/kgateway-helm.yaml

# Установка Gateway (читает манифесты из Git репозитория, путь gateway/)
kubectl apply -f argocd/applications/kgateway-gateway.yaml

# Установка LLM провайдера Cloud.ru (читает манифесты из Git репозитория, путь llm/)
kubectl apply -f argocd/applications/kgateway-llm-cloudru.yaml
```

**Важно**:

- Applications для Gateway и LLM используют directory source и читают манифесты напрямую из Git репозитория
- Gateway: путь `gateway/` в репозитории
- LLM провайдер: путь `llm/` в репозитории
- Убедитесь, что репозиторий публичный или настроен доступ для ArgoCD

### Настройка API ключа для LLM провайдера

Перед применением Application `kgateway-llm-cloudru` необходимо создать Secret с API ключом:

```bash
# Убедитесь, что переменная окружения FM_API_KEY установлена
export FM_API_KEY="Bearer your-api-key"

# Создать Secret
kubectl apply -f- <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudru-secret
  namespace: kgateway-system
type: Opaque
stringData:
  Authorization: $FM_API_KEY
EOF
```

Или использовать готовый скрипт:

```bash
./scripts/create-cloudru-secret.sh
```

## Проверка в ArgoCD UI

После применения Applications все ресурсы будут видны в ArgoCD UI:

1. Откройте ArgoCD UI (обычно через port-forward на порт 9999)
2. Войдите с учетными данными (admin/gateway)
3. Вы увидите все Applications:
   - `kgateway-crds-helm`
   - `kgateway-helm`
   - `kgateway-gateway`
   - `kgateway-llm-cloudru`

4. Каждое Application показывает все управляемые ресурсы:
   - Deployments
   - Services
   - Secrets
   - Gateway
   - HTTPRoute
   - AgentgatewayBackend
   - И другие ресурсы

## Проверка статуса

После применения Applications, проверьте их статус:

```bash
# Проверка Applications
kubectl get applications -n argocd

# Проверка Gateway
kubectl get gateway kgateway-proxy -n kgateway-system

# Проверка Deployment
kubectl get deployment kgateway-proxy -n kgateway-system

# Проверка Service
kubectl get svc -n kgateway-system kgateway-proxy

# Проверка LLM Backend
kubectl get agentgatewaybackend cloudru -n kgateway-system

# Проверка HTTPRoute
kubectl get httproute cloudru -n kgateway-system
```

## Port-forward для локального тестирования Gateway

Для локального тестирования Gateway используйте port-forward:

```bash
kubectl port-forward deployment/kgateway-proxy -n kgateway-system 8080:80
```

После этого Gateway будет доступен локально на `http://localhost:8080`

## Тестирование LLM провайдера

После настройки API ключа и применения Application, можно протестировать LLM провайдер:

```bash
# Если используете port-forward
curl "localhost:8080/cloudru" -H "content-type:application/json" -d '{
   "model": "",
   "messages": [
     {
       "role": "system",
       "content": "You are a helpful assistant."
     },
     {
       "role": "user",
       "content": "Write a short haiku about artificial intelligence."
     }
   ]
 }' | jq
```
