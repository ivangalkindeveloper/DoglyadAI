# Подготовка изолированных окружений

Все команды выполнялись в `/var/tmp/doglyad-engine-survey-20261104` на DGX.
Это каталог опыта, а не каталог рабочего развёртывания. Исходные контейнеры,
Docker Compose и checkpoint в Hugging Face volume не заменялись.

## llama.cpp

Commit: `5851a8e505f4d5fbb183f2847698eb6155d176b7`.
Сборка на ARM64 с CUDA 13.0, архитектура `121`:

```bash
cmake -S llama.cpp -B llama.cpp/build \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
  -DCMAKE_CUDA_ARCHITECTURES=121 \
  -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_CURL=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build llama.cpp/build --target llama-server -j6
```

`convert_hf_to_gguf.py` конвертировал исходный snapshot 4B с `--outtype bf16`.
Второй вызов с `--mmproj` создал projector изображений. Квантование Q4/Q8 не
использовалось. Некоторым служебным тензорам конвертер сохраняет F32.

Бинарный файл запускался в исходном CUDA-образе vLLM. Ему нужен
`LD_LIBRARY_PATH=/survey/llama.cpp/build/bin:/usr/local/cuda/lib64:/usr/local/nvidia/lib64`.
Окончательный план: `llama-4b-context16k.json`.

## Python-окружения

Transformers использует исходный образ vLLM. SGLang использует ранее загруженный
образ с digest из `software-versions.json`. Версии библиотек у них различаются;
сравнение относится ко всему серверному стеку, а не к одному вычислительному ядру.

LMDeploy установлен из commit `3228395546dfb2f6427faf39ec0c0c285f4c378a` в
`/survey/lmdeploy-venv`, созданный с `--system-site-packages`. Сборка использовала
`DISABLE_TURBOMIND=1`: для этой архитектуры проверен backend PyTorch.
Torch 2.12.1 выбран по ограничению LMDeploy; исходный Torch 2.13 в рабочем
контейнере не изменялся. Дополнительные зависимости установлены только в venv.

TensorRT-LLM: официальный контейнер NGC не удалось получить из-за HTTP 403.
Поэтому проверен опубликованный NVIDIA wheel ARM64
`tensorrt-llm==1.4.0rc2.post1` в отдельном `/survey/trt-venv`.
`libopenmpi3t64` установлен только во временном контейнере. Его образ сохранён
для запуска опыта. Операционная система DGX и драйвер не обновлялись.

Для MPI дополнительно установлен `openmpi-bin`. Сначала TensorRT-LLM обнаружил
старые optional-пакеты FlashInfer 0.6.16 из базового образа рядом с требуемым
`flashinfer-python==0.6.18`. Их удалили только из отдельного временного образа.
Попытка загрузки кэшей 0.6.18 из официального индекса остановлена из-за низкой
скорости; опыт выполнен в штатном JIT-режиме без этих optional-пакетов.
`FLASHINFER_DISABLE_VERSION_CHECK` не задавался.

Контейнеру TensorRT-LLM выделена сеть Docker bridge без публикации портов:
в режиме `--network none` MPI завершился с `ompi_dpm_dyn_init: Unreachable`.
`HF_MODULES_CACHE` указывает на `/tmp/huggingface_modules`, поскольку исходный
Hugging Face volume подключён только для чтения. Для обычного BF16 KV-кэша эта
версия TensorRT-LLM принимает `dtype: auto`; явный `bfloat16` в `kv_cache_config`
отклоняется. Тип самой модели остаётся явно `bfloat16`.

Автоматический выбор attention завершился на прогреве ошибкой
`TrtllmAttentionMetadata ... swap_paged_kv_indices_for_layer`.
Последний профиль явно задаёт `attn_backend: FLASHINFER`, ограничивает компиляцию
четырьмя процессами и задаёт пул KV до 16 384 токенов. Это параметры движка;
исходники TensorRT-LLM не менялись. См. `tensorrt-4b-flashinfer.{json,yml}`.
В старых обсуждениях NVIDIA также использовали явный FlashInfer для Gemma 3:
[issue 6193](https://github.com/NVIDIA/TensorRT-LLM/issues/6193).
Другой отчёт описывает ошибки attention на L4 и иной версии TensorRT-LLM;
он не является доказательством той же причины на GB10:
[issue 14942](https://github.com/NVIDIA/TensorRT-LLM/issues/14942).

Крупные публичные wheels загружены с возобновлением по диапазонам.
`download_wheel.py` проверяет SHA256 по метаданным PyPI. Хэши и адреса источников
сохранены в квитанциях; сами wheels, GGUF и venv в репозиторий не копируются.

Окружения с `--system-site-packages` содержат также пакеты базового образа.
Совместимость пакета vLLM с заменённым Torch внутри LMDeploy/TRT venv не заявляется:
vLLM из этих venv не запускается. Проверяются импорт и запуск выбранного движка.

## Поддержка моделей

`sources/*-version.json` фиксируют commits просмотренной документации и исходников.
Файлы с префиксом `wheel-` извлечены из проверяемого wheel TensorRT-LLM; это другая
ревизия, чем snapshot его ветки main. Лицензии upstream сохранены рядом с исходниками.
Список архитектур Edge-LLM и архитектура каждого checkpoint находятся в
`edge-compatibility.json`.

## Ошибки подготовки

- `llama-4b-bf16`: отсутствовал путь к общей библиотеке сервера. Исправлен `LD_LIBRARY_PATH`.
- `llama-4b-bf16-r2`: API отклонил `repeat_last_n=-1`. Повтор использует `16384`.
- `llama-4b-bf16-r3`: успешный запуск, но 16 384 токена делились между четырьмя слотами.
  Основной результат взят из повтора с 65 536 токенами всего.
- `sglang-4b-current-prompt`: четыре sampling-запроса отклонены из-за `top_k=0`.
  Основной результат взят из `sglang-4b-adapted` с `top_k=-1`.

Эти ошибки параметров и установки не считаются зацикливанием или ошибкой MedGemma.
