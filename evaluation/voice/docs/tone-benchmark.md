# Проверка T-one на сохранённом русском корпусе

Этот запуск измеряет только распознавание речи. Парсер формы не вызывается.
Используется исходный T-one со стандартным декодером KenLM, без подсказок,
медицинского словаря и исправления распознанного текста.

Аудио остаётся исходным: 758 русских WAV из матрицы 24–25 октября 2026 года.
Из них 430 — диктовки, 328 — отдельные примеры терминологии. Чистый звук
и варианты с шумом считаются отдельно. Это синтетическая речь; результаты
не устанавливают качество на записях настоящих врачей.

## Подготовка

Команды выполняются из корня репозитория. Нужен Python 3.11.
Веса занимают около 5,6 ГБ. Окружение создаётся отдельно от приложения.

```bash
.venv311/bin/python -m venv build/voice-eval/tone-2026-11-15/venv
build/voice-eval/tone-2026-11-15/venv/bin/pip install \
  'tone[demo] @ git+https://github.com/voicekit-team/T-one.git@3c5b6c015038173840e62cea99e10cdb1c759116' \
  'numpy==1.26.4' psutil
HF_HUB_DISABLE_XET=1 .venv311/bin/hf download t-tech/T-one model.onnx kenlm.bin \
  --revision 106f3b0b32a9e107eb613312e4ebc61ff3d53926 \
  --local-dir build/voice-eval/tone-2026-11-15/model
```

Версии всех установленных пакетов сохраняются в `settings.json` запуска.
Для точного воспроизведения используйте также `requirements-freeze.txt`
из каталога опубликованного результата. Контрольные суммы весов:

| Файл | SHA-256 |
|---|---|
| `model.onnx` | `707e4a282d5036304a0b8603ad83945840c3075f53c49911ef88c19bcc5a7d52` |
| `kenlm.bin` | `8c31a489a51a6e9236112dacb6bed12f45e8df734057615fa6bf220a5a769a1d` |

Сохраните русский срез манифеста, не меняя исходные случаи:

```bash
.venv311/bin/python - <<'PY'
import json
from pathlib import Path

source = Path('evaluation/voice/results/2026-10-25-asr-extraction/corpus-final.json')
manifest = json.loads(source.read_text())
manifest['cases'] = [case for case in manifest['cases'] if case['locale'] == 'ru']
destination = Path('build/voice-eval/tone-2026-11-15/corpus-ru.json')
destination.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
PY
```

## Распознавание

```bash
build/voice-eval/tone-2026-11-15/venv/bin/python \
  -m evaluation.voice.runners.tone_asr_benchmark \
  --manifest build/voice-eval/tone-2026-11-15/corpus-ru.json \
  --model-dir build/voice-eval/tone-2026-11-15/model \
  --model-revision 106f3b0b32a9e107eb613312e4ebc61ff3d53926 \
  --audio-dir ios/DoglyadTests/VoiceFixtures \
  --threads 4 \
  --output build/voice-eval/tone-2026-11-15/run
```

Если исходный `audioPath` недоступен, инструмент ищет WAV с тем же SHA-256
в `--audio-dir`. Изменённый существующий файл считается ошибкой. Аудио
не синтезируется повторно. Чтение через `tone.read_audio` приводит WAV
к требуемым моделью 8 кГц и одному каналу.

`--limit 6` подходит для проверки установки с отдельным каталогом `--output`.
Полный запуск использует один экземпляр модели. Результат каждой записи
сразу сохраняется в `results.jsonl`. Повтор той же команды продолжает запуск
только при совпадении настроек, исходника, пакетов, весов и аудио. Уже записанные
ошибки остаются ошибками и не повторяются автоматически.

## Подсчёт WER

```bash
.venv311/bin/python -m evaluation.voice.scoring.score_asr_matrix \
  --manifest build/voice-eval/tone-2026-11-15/corpus-ru.json \
  --asr build/voice-eval/tone-2026-11-15/run/results.jsonl \
  --recognizers tone --asr-only --require-complete \
  --output build/voice-eval/tone-2026-11-15/score-new
```

Каталог оценки должен быть новым. Для сравнения добавьте сохранённые JSONL
других распознавателей в `--asr` и их идентификаторы в `--recognizers`.
Используйте только строки того же русского среза с совпадающими SHA-256 аудио.
Сохраняйте ошибки и пустые результаты в знаменателе WER.

Основное сравнение с историческим отчётом использует `meanNormalizedWER`:
среднее WER по записям после общей нормализации. `normalizedMicroWER`
считает суммарные ошибки относительно общего числа эталонных слов.
Группа `clinical` в исторической схеме означает все 430 диктовок,
а не подтверждённую клиническую корректность.

Время обработки включает чтение и преобразование WAV, но не первичную
загрузку модели. Загрузка сохраняется отдельно в `execution.json`.
Не сравнивайте скорость этого CPU-запуска со старыми измерениями на iPhone
или другой машине. `processRSSBytes` — снимок памяти после записи,
а не измеренный пик потребления.
