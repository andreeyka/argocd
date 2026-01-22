#!/bin/bash
# Скрипт для создания Secret с API ключом из переменной окружения FM_API_KEY

if [ -z "$FM_API_KEY" ]; then
    echo "❌ Ошибка: переменная окружения FM_API_KEY не установлена"
    echo "Установите её командой: export FM_API_KEY=\"Bearer your-api-key\""
    exit 1
fi

echo "🔐 Создание Secret для Cloud.ru LLM провайдера..."
echo "Используется API ключ из переменной окружения FM_API_KEY"

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

if [ $? -eq 0 ]; then
    echo "✅ Secret успешно создан!"
else
    echo "❌ Ошибка при создании Secret"
    exit 1
fi
