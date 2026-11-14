# DGX Spark: один inference-сервис, MedGemma и Hulu-Med

Один Compose project в `/opt/doglyad/inference` содержит шесть контейнеров:
общий `backend_inference` и пять vLLM. Backend проверяет App Check и выбирает
движок по `modelId`. Все модели используют один приватный API.

```text
main backend → DGX Tailscale :8100 → App Check → modelId
                                               ├─ vllm_medgemma_4b:8000
                                               ├─ vllm_medgemma_15_4b:8000
                                               ├─ vllm_medgemma_27b:8000
                                               ├─ vllm_hulu_med_32b:8000
                                               └─ vllm_hulu_med_7b:8000
```

У vLLM нет опубликованных портов. Профиль
[`dgx-spark.json`](../inference/profiles/dgx-spark.json) задаёт состав и параметры
моделей. Генератор формирует Compose и `VLLM_ENDPOINTS` из этого профиля.
Неизвестный ID возвращает `400`.
Каждая модель имеет отдельную очередь: восемь выполняемых и один ожидающий запрос.
Всего сервис допускает до 40 генераций одновременно. Ожидание ограничено двумя
секундами; заполненная очередь возвращает `503` с `Retry-After: 5`.
Сбой или занятая очередь одной модели не занимают очередь другой. Перезапуск
общего backend временно прерывает доступ ко всем моделям.

## Что установить и сохранить

Сохраните штатные DGX OS, драйвер NVIDIA, CUDA, Container Toolkit, Docker и DGX
Dashboard. Проверьте Compose, SSH и доступ пользователя к Docker. Установите
Tailscale и добавьте DGX в сеть проекта. Предпочтителен Ethernet; Wi-Fi также
подходит при устойчивом соединении. Отключите автоматический сон для работы сервера.

vLLM, PyTorch и Python-зависимости работают в контейнерах. Системный `pip`
для них не нужен. Не используйте amd64 bootstrap `make init-vm-inference`
на ARM64 DGX. После проверки штатных компонентов можно выполнить на DGX:

```bash
sudo bash prepare-host.sh YOUR_LOGIN_USER
```

Скрипт поддерживает DGX OS на Ubuntu 24.04 ARM64, устанавливает Tailscale из
подписанного репозитория, добавляет пользователя в Docker и создаёт
`/opt/doglyad/inference`. Авторизация Tailscale выполняется отдельно.
Не удаляйте драйвер, firmware, NVIDIA/DGX metapackages и Container Toolkit.
Удаление своих ненужных образов и остановленных контейнеров допустимо после
проверки их назначения. Не удаляйте volume с весами.

Для SSH используйте вывод `whoami` и локальный адрес из `hostname -I`.
Проверьте `systemctl is-active ssh`. На Mac настройте SSH-ключ и, при желании,
alias `doglyad-spark`. Пароли и приватные ключи не отправляйте в чат или Git.

## Файлы и образы

На Mac из корня проекта выполните `make render-inference`. Проверьте файлы
в `build/inference/dgx-spark/` и перенесите их в каталог развёртывания.
Генерация не запускает контейнеры. Общая инструкция и формат профиля:
[`deploy/inference/README.md`](../inference/README.md).

В `/opt/doglyad/inference` должны находиться:

```text
docker-compose.yml
start.sh
start.py
host_profile.py
compose_document.py
profile.json
.env                         заполненная .env.example
config/server.json
secrets/.env                 существующий HF_TOKEN для движков/загрузчика
secrets/firebase_credentials.json
logs/
```

Используйте один `COMPOSE_PROJECT_NAME=doglyad-dgx`.
Заполните `INFERENCE_BACKEND_IMAGE` и
`INFERENCE_BACKEND_BIND` в машинном `.env`. Адрес должен совпадать с
`tailscale ip -4`. Порт API по умолчанию 8100. На роутере проброс портов не нужен.
Образ vLLM и параметры моделей заданы в исходном профиле.

Для GB10 проверены ARM64, BF16 CUDA и этот образ vLLM:

```text
vllm/vllm-openai:v0.28.0@sha256:2a7cde230b59f3ce6cab33dd245ba6bee41aa87b38c9fe84f966ff24016813ce
```

Для backend используйте проверенный ARM64 image digest. Для первоначальной
локальной миграции допустим перенос проверенного образа через `docker save` /
`docker load` с закреплением его image ID на DGX. Проверка образа:

```bash
.venv311/bin/python deploy/verify_backend_image.py IMAGE inference
```

Она проверяет запуск с UID/GID 10001, права credentials/logs и обязательный
App Check на синтетических данных. Локально переданный образ не является
опубликованным GHCR-релизом. CI поддерживает ARM64; публикация — отдельное действие.

Секреты доставляйте отдельно от исходников. Подготовьте их права штатным
`deploy/prepare_backend_storage.py`: secrets 750/640, группа 10001;
logs 2770/660. Backend монтирует только Firebase JSON для чтения.
Каталог `config` должен иметь права 755, `server.json` — 644.

Общий внешний volume сохраняет ранее скачанные веса:

```bash
docker volume create doglyad-dgx-huggingface
```

Не меняйте его имя при миграции. Не запускайте старые и новые GPU-контейнеры
одновременно: они загрузят вторые копии тех же моделей.

## Параметры и запуск

| Модель | Формат весов | Сервис | KV-кэш | Доля для стартовой проверки памяти |
|---|---|---|---:|---:|
| MedGemma 4B | BF16 | `vllm_medgemma_4b` | 4 GiB | 0.15 |
| MedGemma 1.5 4B | BF16 | `vllm_medgemma_15_4b` | 4 GiB | 0.15 |
| MedGemma 27B | NVFP4 | `vllm_medgemma_27b` | 8 GiB | 0.55 |
| Hulu-Med 32B | NVFP4 | `vllm_hulu_med_32b` | 4 GiB | 0.30 |
| Hulu-Med 7B | BF16 | `vllm_hulu_med_7b` | 2 GiB | 0.15 |

Параметры MedGemma: неквантованные тензоры и KV-кэш BF16, рабочий контекст 16384, максимум шесть изображений,
до восьми одновременных запросов на модель, компиляция и CUDA Graphs, prefix caching.
В профиле заданы `maxNumSeqs: 8` и `isEager: false` для каждого движка MedGemma.
Для всех трёх моделей профиль включает N-gram speculative decoding:
`numSpeculativeTokens: 8`, `promptLookupMin: 2`, `promptLookupMax: 5`.
Основная модель проверяет предлагаемые токены; N-gram не меняет формат весов.
vLLM 0.28.0 при этом использует Model Runner V1 и отключает async scheduling.
Результаты проверки полного ответа при нагрузке 4/4/4 и 8/8/8:
[`evaluation/inference/dgx-spark-2026-11-05-ngram-capacity`](../../evaluation/inference/dgx-spark-2026-11-05-ngram-capacity/README.md).
В `config/server.json` лимит `max_concurrent_requests: 8` применяется отдельно
к каждой модели. Ревизии обеих 4B закреплены на версиях, использованных в тестах.
27B загружается из `/opt/doglyad/models/medgemma-27b-it-nvfp4-20261110`: это
проверенный preserved-экспорт NVFP4 с исходными BF16 RMSNorm. Квантуются
линейные слои языковой модели (W4A4); vision tower, projector, lm_head,
embeddings и KV-кэш остаются BF16. Не подменяйте каталог сырым экспортом.
Перед переносом сверяйте SHA256 всех файлов с утверждённым manifest.
Том HF с исходной 27B BF16 сохраняется для отката.
Поле `format` в обоих каталогах main описывает действующий формат весов.
Кэш ограничен явно; `gpu-memory-utilization` используется отдельно при старте.
При длинных входах доступный KV-кеш может уменьшить число одновременно
выполняемых запросов. Восемь слотов не гарантируют восемь активных последовательностей
или завершение любого запроса за рабочие 120 секунд.
На Spark CPU и GPU используют общую RAM: CPU offload не добавляет физическую память.

Справочное поле `contextLength` в каталоге приложения описывает окно самой
модели для пользователя. Оно не задаёт рабочий лимит vLLM.
Рабочий лимит задаётся через `models[].maxModelLen` в профиле хоста.

При необходимости сначала скачайте веса без GPU:

```bash
DOWNLOAD_MODEL_ID=google/medgemma-27b-it docker compose --profile download run --rm model_download
```

Загрузчик ограничен 8 GiB RAM без дополнительного swap и четырьмя CPU.
Файлы скачиваются по одному, ускоренный режим Xet выключен. Эти лимиты
не ограничивают память vLLM.

На DGX из каталога развёртывания:

```bash
bash start.sh
```

Скрипт запускает 27B, дожидается healthy, затем добавляет 4B, 1.5 4B, Hulu-Med 32B и Hulu-Med 7B.
Этот порядок использован в проверке 8/8/8. Первый запуск с компиляцией занимает
несколько минут на модель; готовность проверяется после компиляции и захвата графов.
Общий backend создаётся после готовности движков. Для перезапуска всех шести контейнеров:

```bash
bash start.sh --restart
```

Не используйте обычный `docker compose up -d` для холодного старта пяти движков:
он запускает их одновременно. Для просмотра состояния используйте
`docker compose ps`; технические логи не должны содержать тексты запросов.

При переходе со старой схемы остановите старые три backend и три vLLM перед
`bash start.sh`. Сохраните каталоги `medgemma-4b`, `medgemma-15-4b`,
`medgemma-27b` до завершения проверки. После успеха старые остановленные
контейнеры можно удалить без удаления volume. Для отката сначала остановите новый
стек, затем последовательно запустите старые стеки и восстановите endpoint map
и SSH-туннель из сохранённой конфигурации.

## Локальный main и SSH-туннель

Для локального main используйте профиль VS Code `Backend: Local Inference`.
Облачные VM для этого не нужны. Если другой VPN мешает Tailscale на Mac,
используйте один SSH-туннель, оставляя этот VPN включённым:

```bash
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -L 127.0.0.1:18100:DGX_TAILSCALE_IP:8100 doglyad-spark
```

Без alias укажите `USER@DGX_LAN_IP`, `-i PATH_TO_EXISTING_KEY` и
`-o IdentitiesOnly=yes`. Порт 18100 доступен только самому Mac.

Все пять записей локального `backend/main/secrets/inference_endpoints.json`
указывают на один API:

```json
{
  "google/medgemma-4b-it": "http://127.0.0.1:18100",
  "google/medgemma-1.5-4b-it": "http://127.0.0.1:18100",
  "google/medgemma-27b-it": "http://127.0.0.1:18100",
  "ZJU-AI4H/Hulu-Med-7B": "http://127.0.0.1:18100",
  "ZJU-AI4H/Hulu-Med-32B": "http://127.0.0.1:18100"
}
```

Для облачного main вместо loopback нужен один адрес
`http://DGX_TAILSCALE_IP:8100` во всех пяти записях. Не доставляйте локальный
loopback map на VM. Существующие модели и лимиты доступа сохраняются.
После изменения map или каталога перезапустите main.

Проверьте API без токена:

```bash
curl --noproxy '*' -sS -o /dev/null -w '%{http_code}\n' \
  --connect-timeout 5 --max-time 10 \
  -H 'Content-Type: application/json' --data '{}' \
  http://127.0.0.1:18100/v1/generation
```

Ожидается 401. Это проверяет связь и App Check, но не генерацию.
Для каждого vLLM отдельно проверьте внутренние `/health` и `/v1/models`.
Успешная генерация, изображения, скорость и полный путь через приложение —
отдельные проверки с действующим App Check. Не отключайте защиту.
Таймауты сохраняются: `300 > 130 > 120` секунд.

## Перезагрузка и диагностика

Docker может запустить backend раньше появления адреса Tailscale. Тогда
публикация порта завершается ошибкой. Дождитесь правильного `tailscale ip -4`
и выполните `bash start.sh --restart`. Скрипт последовательно восстановит
движки и пересоздаст API. Автоматический порядок запуска после перезагрузки
на уровне systemd пока не настроен.

На этой машине с ядром `7.0.0-1024-nvidia` и драйвером `580.178.04`
зарегистрирован сбой GPU с Xid 13/154/109 и потерей изображения.
В [обсуждении NVIDIA](https://forums.developer.nvidia.com/t/dgx-spark-repeatedly-rebooting-after-most-recent-update/387397)
есть похожие случаи. Работа без монитора проверяется как временная мера;
причина на этой машине не доказана. Docker healthy после Xid сам по себе
не подтверждает исправность GPU. Проверяйте журнал ядра.

Режим 4/4/4 прошёл 220 запросов, включая совместную генерацию, изображения
и вход около лимита контекста. Минимум доступной RAM при генерации — 15,49 GiB.
На большом входе часть запросов 27B ожидала внутри vLLM: лимит 4 не гарантирует
четыре одновременно активных последовательности при любом размере запроса.
Это ограниченная нагрузочная проверка, а не длительный тест устойчивости.
Подробности: [отчёт 4/4/4](../../evaluation/inference/dgx-spark-2026-11-01/mixed-4-4-4/RESULTS.md).

При восстановлении прежних eager-контейнеров после тестов появлялись сообщения
драйвера `NV_ERR_NO_MEMORY`. Все движки затем успешно запустились; причина
сообщений не установлена. Порядок с 27B первой их не устранил. При развёртывании
проверяйте новые сообщения ядра и контрольную генерацию, а не только healthy.

При постоянном включении 4/4/4 1 ноября 2026 ошибка повторилась во время
инициализации CUDA у 4B. Контейнер автоматически перезапустился один раз и
стал healthy. Этот старт нельзя считать запуском без ошибок. Подробности и
проверки после запуска: [развёртывание 4/4/4](../../evaluation/inference/dgx-spark-2026-11-01/deployment-4-4-4/RESULTS.md).

Штатные драйвер, ядро и настройки Wi-Fi при этой миграции не меняются.
При нестабильном Wi-Fi предпочтителен Ethernet. Изменение энергосбережения
адаптера — отдельное действие администратора.

## Hulu-Med 32B NVFP4

Логический ID в приложении и inference API: `ZJU-AI4H/Hulu-Med-32B`.
Веса: [ivangalkindeveloper/Hulu-Med-32B-NVFP4](https://huggingface.co/ivangalkindeveloper/Hulu-Med-32B-NVFP4),
закреплённый commit `5ed563b024f1511837b26830fcb2846cb1fdc501`.
Каталог на DGX: `/opt/doglyad/models/hulu-med-32b-nvfp4-20261112`.
Перед запуском сверяйте файлы с `SHA256SUMS` опубликованного чекпойнта.
После сверки замените только `preprocessor_config.json` в отдельной рабочей
копии чекпойнта файлом [`config/hulu-med-32b-preprocessor.json`](config/hulu-med-32b-preprocessor.json).
Он ограничивает визуальный бюджет процессора до 2048 токенов вместо исходных
16384. Штатный resize уменьшает большие кадры перед обработкой; веса и
публичный чекпойнт не меняются. Это соответствует encoder cache при
`maxNumBatchedTokens: 2048` и оставляет часть рабочего контекста для текста и ответа.
Без этой настройки кадр 1024×768 даёт 4015 визуальных токенов и получает `400`.
`SHA256SUMS` источника после этой замены намеренно отличается только для
`preprocessor_config.json`; храните исходный manifest для проверки остальных файлов.

```bash
cp deploy/dgx-spark/config/hulu-med-32b-preprocessor.json \
  /opt/doglyad/models/hulu-med-32b-nvfp4-20261112/preprocessor_config.json
```

Команда выше выполняется на DGX из копии репозитория. На Mac можно доставить
этот файл по SSH в указанный каталог. Не изменяйте каталог исходной публикации.
Языковые проекции используют NVFP4 W4A4; vision encoder, projector,
embeddings и lm_head сохранены в BF16. KV-кэш также BF16.

Для Hulu-Med требуется адаптер собственной архитектуры. Он опубликован вместе
с весами в `vllm_adapter/`, с Dockerfile на закреплённой базе vLLM 0.28.0.
Сборка на ARM64 DGX из проверенного каталога:

```bash
docker build -t doglyad-hulu32-vllm:20261112-verified \
  /opt/doglyad/models/hulu-med-32b-nvfp4-20261112/vllm_adapter
docker image inspect --format '{{.Id}} {{.Architecture}}' \
  doglyad-hulu32-vllm:20261112-verified
```

Профиль закрепляет проверенный локальный image ID, а не изменяемый tag.
После новой сборки сверьте image ID с профилем перед генерацией Compose.
У Hulu-Med включены `isRemoteCodeTrusted: true`, eager execution и prefix caching.
Шаблон чата получает `image_token: "<image>"` через `chatTemplateKwargs`,
как в исходном процессоре Hulu-Med. N-gram и CUDA Graphs для неё не включены. Рабочий контекст — 16384,
до восьми последовательностей, до шести изображений, KV-кэш — 4 GiB.
Поле `contextLength: 32768` в каталоге приложения описывает архитектурное окно
исходной модели; рабочий лимит DGX задаётся отдельно профилем.

В обоих каталогах main модель доступна по Pro и имеет `format: NVFP4`.
В `backend/main/secrets/inference_endpoints.json` её логический ID указывает
на тот же inference API, что и MedGemma. Перезапустите локальный main backend
после изменения каталога и карты endpoint. Каталог клиента обновляется при
следующей загрузке конфигурации приложения.

## Hulu-Med 7B BF16

ID приложения и inference API: `ZJU-AI4H/Hulu-Med-7B`.
Источник: [Hulu-Med-7B](https://huggingface.co/ZJU-AI4H/Hulu-Med-7B),
revision `258594714a0d3835eb2c9e4cc165a4242e606d71`.
Используются четыре safetensors-шарда, около 14,98 GiB, в исходном BF16.
Квантование не выполняется. Каталог DGX:
`/opt/doglyad/models/hulu-med-7b-bf16-20261112`.
Исходный checkpoint хранится отдельно; все шарды сверяются с LFS SHA256.

7B использует тот же проверенный адаптер vLLM и локальный image ID, что 32B.
Её исходный `processing_hulumed.py` имеет тот же SHA256, поэтому применены
те же изменения совместимости с Transformers 5 и optional Decord.
Остальной код модели и веса сохраняются. В рабочей копии процессор получает
[`config/hulu-med-7b-preprocessor.json`](config/hulu-med-7b-preprocessor.json)
с бюджетом 2048 визуальных токенов. Нормализация изображений не меняется.
`--default-chat-template-kwargs` передаёт `image_token: "<image>"`.

Рабочий контекст — 16384, KV-кэш BF16 — 2 GiB, до восьми последовательностей
и шести изображений. Включены eager execution и prefix caching; N-gram и
CUDA Graphs не включены. `gpuMemoryUtilization: 0.15` используется для стартовой
проверки; фактический размер KV-кэша задан отдельно.
Каталог приложения показывает архитектурное окно 32768 и формат BF16.
Модель относится к Pro и использует тот же endpoint общего backend.

Перед добавлением нового движка проверяется свободная RAM. Загрузка идёт
в отдельном CPU-контейнере с лимитом 4 GiB, без GPU и дополнительного swap.
При старте движка защита памяти останавливает только новый контейнер, если
MemAvailable остаётся ниже 8 GiB в трёх последовательных замерах.
Параметры и контейнеры четырёх существующих движков должны сохраниться.

## Последующие обновления

Обновление общего backend затрагивает все модели. Веса и пять vLLM при
обновлении только backend можно сохранить работающими.
После перехода на сгенерированный стек добавьте DGX в общий inventory одной
записью с `profile: "../inference/profiles/dgx-spark.json"` и
`directory: "/opt/doglyad/inference"`. Скрипт обновления проверяет все пять
движков и сохраняет их при обновлении backend. Подробности и порядок отката
описаны в [руководстве профилей](../inference/README.md).

## Источники

- [Аппаратная конфигурация DGX Spark](https://docs.nvidia.com/dgx/dgx-spark/hardware.html).
- [Обновления DGX OS](https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html).
- [Запуск vLLM на Spark](https://build.nvidia.com/spark/vllm/intermediate).
- [Контракт inference-сервиса](../../backend/inference/README.md).
