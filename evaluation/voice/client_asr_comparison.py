from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import ROOT
from evaluation.voice.generate import file_sha256

MODES = ("guided-format", "reordered-format", "freeform-development")
VARIANTS = ("clean", "noisy")
ENGINES = ("SpeechAnalyzer", "SFSpeechRecognizer", "WhisperKit", "Parakeet")
OUTPUT_ROOT = ROOT / "build/voice-eval"


def report_path(engine: str, mode: str, variant: str) -> Path:
    if engine == "SpeechAnalyzer":
        if mode in ("reordered-format", "freeform-development"):
            prefix = "ios-candidate-device-confidence-only-asr-only"
        else:
            prefix = "ios-candidate-device-asr-only"
        name = "asr-replay-speechAnalyzer-hints-true-report.json"
    elif engine == "SFSpeechRecognizer":
        prefix = "ios-candidate-device-asr-only-sfSpeechRecognizer-only"
        name = "asr-replay-sfSpeechRecognizer-hints-true-raw-report.json"
    elif engine == "WhisperKit":
        prefix = "ios-whisperkit-device"
        name = "asr-report.json"
    elif engine == "Parakeet":
        prefix = "ios-parakeet-device"
        name = "asr-report.json"
    else:
        raise ValueError(f"Unknown engine: {engine}")
    return OUTPUT_ROOT / f"{prefix}-{mode}-{variant}" / name


def summarize() -> dict[str, Any]:
    summaries: list[dict[str, Any]] = []
    sources: list[dict[str, str]] = []
    reports: dict[tuple[str, str, str], dict[str, Any]] = {}
    model_loads: dict[str, list[float]] = {"WhisperKit": [], "Parakeet": []}
    for mode in MODES:
        manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        expected = {entry["caseId"]: entry["locale"] for entry in manifest["entries"]}
        if (
            len(expected) != 124
            or list(expected.values()).count("en") != 62
            or list(expected.values()).count("ru") != 62
        ):
            raise ValueError(f"Unexpected corpus size: {mode}")
        for variant in VARIANTS:
            for engine in ENGINES:
                path = report_path(engine, mode, variant)
                report = json.loads(path.read_text(encoding="utf-8"))
                if report["platform"] != "iOS" or report["audioMode"] != mode or report["audioVariant"] != variant:
                    raise ValueError(f"Wrong iPhone ASR report: {path}")
                if report["audioManifestSha256"] != file_sha256(manifest_path):
                    raise ValueError(f"Audio manifest changed: {path}")
                rows = report["results"]
                if len(rows) != len(expected) or {row["caseId"]: row["locale"] for row in rows} != expected:
                    raise ValueError(f"Missing or mismatched cases: {path}")
                sources.append(
                    {"engine": engine, "mode": mode, "variant": variant, "path": str(path.relative_to(ROOT))}
                )
                reports[(engine, mode, variant)] = report
                if engine in model_loads:
                    model_loads[engine].append(report["modelLoadSeconds"])
                for locale in ("en", "ru"):
                    selected = [row for row in rows if row["locale"] == locale]
                    completed = [row for row in selected if row["status"] == "ok"]
                    durations = [row.get("seconds", row.get("elapsedSeconds")) for row in completed]
                    if any(value is None for value in durations):
                        raise ValueError(f"Missing transcription duration: {path}")
                    summaries.append(
                        {
                            "engine": engine,
                            "mode": mode,
                            "variant": variant,
                            "locale": locale,
                            "completed": len(completed),
                            "total": len(selected),
                            "meanRawWER": statistics.mean(row["rawWER"] for row in completed) if completed else None,
                            "medianSeconds": statistics.median(durations) if durations else None,
                            "meanSeconds": statistics.mean(durations) if durations else None,
                        }
                    )
    qwen_screening: list[dict[str, Any]] = []
    for mode in MODES:
        manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
        for variant in VARIANTS:
            for locale in ("en", "ru"):
                path = OUTPUT_ROOT / f"qwen3-asr-mac-sample-{mode}-{variant}-{locale}.json"
                sample = json.loads(path.read_text(encoding="utf-8"))
                if sample["platform"] != "macOS" or sample["audioMode"] != mode or sample["audioVariant"] != variant:
                    raise ValueError(f"Wrong Qwen screening report: {path}")
                if sample["audioManifestSha256"] != file_sha256(manifest_path):
                    raise ValueError(f"Qwen audio manifest changed: {path}")
                sample_rows = sample["results"]
                case_ids = {row["caseId"] for row in sample_rows}
                if len(sample_rows) != 10 or len(case_ids) != 10 or any(row["locale"] != locale for row in sample_rows):
                    raise ValueError(f"Wrong Qwen sample: {path}")
                sources.append(
                    {
                        "engine": "Qwen3-ASR Mac screening",
                        "mode": mode,
                        "variant": variant,
                        "path": str(path.relative_to(ROOT)),
                    }
                )
                item: dict[str, Any] = {"mode": mode, "variant": variant, "locale": locale, "sampleSize": 10}
                for engine in ("WhisperKit", "Parakeet"):
                    paired = [row for row in reports[(engine, mode, variant)]["results"] if row["caseId"] in case_ids]
                    if len(paired) != 10 or any(row["status"] != "ok" for row in paired):
                        raise ValueError(f"Incomplete paired iPhone sample: {engine}/{mode}/{variant}/{locale}")
                    item[f"{engine}MeanWER"] = statistics.mean(row["rawWER"] for row in paired)
                completed = [row for row in sample_rows if row["status"] == "ok"]
                item["qwenCompleted"] = len(completed)
                item["qwenMeanWER"] = statistics.mean(row["rawWER"] for row in completed) if completed else None
                qwen_screening.append(item)
    return {
        "schemaVersion": 1,
        "summaries": summaries,
        "qwenScreening": qwen_screening,
        "modelLoadMedianSeconds": {engine: statistics.median(values) for engine, values in model_loads.items()},
        "sources": sources,
    }


def render_markdown(comparison: dict[str, Any]) -> str:
    rows = comparison["summaries"]
    lookup = {(row["mode"], row["variant"], row["locale"], row["engine"]): row for row in rows}
    lines = [
        "# Сравнение клиентских ASR на iPhone",
        "",
        "Все четыре движка обработали одни и те же синтетические WAV на физическом iPhone 17 (iOS 26.6.2). "
        "Три набора: диктовка по порядку, диктовка с перестановкой полей и свободная речь; "
        "для каждого — чистый звук и фоновый шум 25 дБ SNR. В каждой ячейке 62 записи на язык.",
        "",
        "| Набор | Звук | Язык | SpeechAnalyzer | SFSpeechRecognizer | WhisperKit Turbo | Parakeet v3 |",
        "|---|---|---|---:|---:|---:|---:|",
    ]
    titles = {
        "guided-format": "По порядку",
        "reordered-format": "Другой порядок",
        "freeform-development": "Свободная речь",
    }
    for mode in MODES:
        for variant in VARIANTS:
            for locale in ("en", "ru"):
                cells = []
                for engine in ENGINES:
                    item = lookup[(mode, variant, locale, engine)]
                    value = "—" if item["meanRawWER"] is None else f"{item['meanRawWER'] * 100:.1f}%"
                    cells.append(f"{value} ({item['completed']}/{item['total']})")
                lines.append(
                    f"| {titles[mode]} | {'Чистый' if variant == 'clean' else 'Шум'} | {locale} | "
                    + " | ".join(cells)
                    + " |"
                )
    lines += [
        "",
        "WER — средняя доля ошибочно распознанных слов на запись; меньше — лучше. "
        "Для записи чисел цифрами и сокращений единиц применена одна и та же нормализация. "
        "Показан исходный текст ASR до локального исправления словаря. Неудачные распознавания исключены из WER, "
        "но учтены в доле успешных записей.",
        "",
        "## Сводка по скорости и качеству",
        "",
        "| Движок | WER en, все условия | WER ru, все условия | Среднее время на WAV | Загрузка модели |",
        "|---|---:|---:|---:|---:|",
    ]
    for engine in ENGINES:
        selected = [row for row in rows if row["engine"] == engine]
        en_wer = statistics.mean(row["meanRawWER"] for row in selected if row["locale"] == "en")
        ru_wer = statistics.mean(row["meanRawWER"] for row in selected if row["locale"] == "ru")
        elapsed = statistics.mean(row["meanSeconds"] for row in selected)
        load = comparison["modelLoadMedianSeconds"].get(engine)
        lines.append(
            f"| {engine} | {en_wer * 100:.1f}% | {ru_wer * 100:.1f}% | {elapsed:.2f} с | "
            f"{'—' if load is None else f'{load:.1f} с'} |"
        )
    lines += [
        "",
        "WhisperKit дал самый низкий WER в 11 из 12 сочетаний условий и языка. Parakeet в среднем "
        "распознавал файл примерно в восемь раз быстрее. Время запуска модели получено в тестовом приложении "
        "и может отличаться при другой интеграции.",
        "",
        "## Решение для следующего этапа",
        "",
        "Whisper Turbo — первый кандидат для окончательной расшифровки записи: в этом тесте он точнее "
        "остальных почти во всех условиях. Модель Whisper можно запускать на Android через "
        "[whisper.cpp](https://github.com/ggml-org/whisper.cpp); iOS-обёртка "
        "[WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) сама по себе не является Android SDK. "
        "До замены текущего ASR нужно измерить эту же модель на Android и проверить задержку, память и размер приложения.",
        "",
        "Parakeet v3 — быстрый альтернативный кандидат. Здесь он запущен на iPhone через "
        "[FluidAudio](https://github.com/FluidInference/FluidAudio); "
        "[sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo-transducer-models.html) "
        "поддерживает вариант Parakeet v3 на Android. Качество и расход памяти этой сборки на Android пока не измерены.",
        "",
        "WER недостаточно для медицинских данных. Например, в шумном русском примере "
        "`freeformDev-ru-bladderWithResidualUrineDetermination-00` Parakeet записал рост `1081 см` "
        "вместо `181 см`; WhisperKit сохранил рост, но неоднозначно записал дату рождения. "
        "Следующая проверка должна отдельно считать ошибки имён, дат, чисел, сторон и отрицаний.",
        "",
        "## Ограничения",
        "",
        "Это сравнение распознавания заранее созданных аудиофайлов, без микрофона, естественной речи врача "
        "и последующего извлечения полей. Поэтому низкий WER здесь не доказывает медицинскую точность продукта. "
        "Чистый и шумный вариант одной записи зависимы; наборы созданы автоматическим TTS. "
        "Apple-движки использовали контекстные подсказки типа исследования; WhisperKit — без промпта; "
        "Parakeet — с подсказкой языка. Время загрузки модели не входит во время распознавания файла.",
        "",
        "## Qwen3-ASR: предварительный отсев",
        "",
        "Дополнительно Qwen3-ASR 0.6B int8 через sherpa-onnx обработал на Mac по 10 равномерно выбранных "
        "файлов на язык из каждого условия (120 WAV). Для сравнения WhisperKit и Parakeet пересчитаны ровно "
        "на тех же файлах iPhone. Это не полный прогон Qwen на iPhone; время между платформами не сравнивается.",
        "",
        "| Набор | Звук | Язык | Qwen3-ASR, Mac | WhisperKit, iPhone | Parakeet, iPhone |",
        "|---|---|---|---:|---:|---:|",
    ]
    for item in comparison["qwenScreening"]:
        qwen = "—" if item["qwenMeanWER"] is None else f"{item['qwenMeanWER'] * 100:.1f}%"
        lines.append(
            f"| {titles[item['mode']]} | {'Чистый' if item['variant'] == 'clean' else 'Шум'} | {item['locale']} | "
            f"{qwen} ({item['qwenCompleted']}/10) | {item['WhisperKitMeanWER'] * 100:.1f}% | "
            f"{item['ParakeetMeanWER'] * 100:.1f}% |"
        )
    lines += [
        "",
        "Модель Qwen3-ASR занимает около 1 ГБ на диске; приложение iPhone с ней не запускалось. "
        "На этой выборке её WER выше обоих основных кандидатов во всех 12 ячейках, поэтому полный "
        "iPhone-прогон пока не оправдан. Таблица не сравнивает скорость платформ и не доказывает качество на Android.",
        "",
        "## Воспроизведение",
        "",
        "Сводка проверяет число записей, язык и SHA-256 аудиоманифеста каждого отчёта. "
        "Исходные отчёты лежат в `build/voice-eval/` и перечислены в `client-asr-comparison.json`. "
        "Обновить документ: `python3 -m evaluation.voice.client_asr_comparison`.",
        "Для повторения Parakeet на iPhone: `python3 -m evaluation.voice.run_parakeet_ios "
        "--mode guided-format --variant clean --device-id <UDID>`; Core ML модель должна лежать в "
        "`build/voice-eval/models/parakeet-tdt-0.6b-v3/`. Скрипт копирует её в контейнер тестового приложения.",
        "Для Qwen3-ASR нужны [зависимости](requirements-qwen-asr.txt) и "
        "[модель sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/qwen3-asr/pretrained.html). "
        "Выборка запускается скриптом `run_qwen3_asr_mac.py`.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Summarize the four physical-iPhone ASR engines")
    parser.add_argument("--output", type=Path, default=ROOT / "evaluation/voice/CLIENT_ASR_COMPARISON.md")
    args = parser.parse_args()
    comparison = summarize()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_markdown(comparison), encoding="utf-8")
    args.output.with_name("client-asr-comparison.json").write_text(
        json.dumps(comparison, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(args.output)


if __name__ == "__main__":
    main()
