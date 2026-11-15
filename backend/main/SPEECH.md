# T-one on main CPU

Main recognizes Russian audio with T-one and KenLM on CPU, then sends the transcript
to inference for LLM parsing. One client request returns both results. WhisperKit
remains the default transcription engine.

## HTTP flow

1. `POST /v1/ultrasound/parse_audio?usExaminationTypeId=...&selectedNeuralModelId=...`:
   binary, headerless mono PCM16 LE at 8000 Hz, `Content-Type: application/octet-stream`,
   `Accept-Language: ru`. Both the selected model ID and the examination type are required.
   Main validates the IDs, runs T-one, then calls the existing transcript parser once.
   Response: `{"transcript":"...","result":{"proposals":[...]}}`.
2. iOS validates the returned fields against that same transcript without another
   HTTP or LLM call. T-one uses server parsing; the parser selection for local
   speech engines is retained. The returned transcript is not rewritten by a local
   lexicon corrector after server parsing.
3. `POST /v1/ultrasound/parse_transcript` still accepts `selectedNeuralModelId`,
   `usExaminationTypeId` and `transcript` for device transcripts or manual edits.
   The model ID is required here as well; missing or blank IDs return 422.
   Unchanged T-one text reuses the returned result. `/parse_dictation` and
   `/transcribe_audio` do not exist.

Both endpoints require App Check and the anonymous owner's microphone entitlement.
Audio is limited to 300 seconds / 4,800,000 bytes, including chunked requests.
The server does not decode compressed files. Invalid format/language returns 422;
missing models return 503; silence returns `noSpeech` (422). Busy admission or
queue timeout returns `speechBusy` (503) with `Retry-After: 5`.

## Execution and configuration

`MainLifespan` starts one spawned CPU process and verifies both model hashes before
serving requests. `TOneWorker` loads ONNX Runtime's CPU provider and KenLM once.
Every recording gets independent decoder state. Billing ingress, report workers
and billing workers do not start speech recognition.

`server.json.speech` configures ONNX threads (4), waiting requests (2), queue wait
(10 seconds) and processing deadline (120 seconds). One recording runs at a time. With the default settings, queue wait + ASR +
inference deadlines total 260 seconds, below the 300-second client timeout. Keep
that total below the client timeout when changing these settings.
Cancellation and timeout do not release the running CPU slot until work actually
finishes. Audio never enters a database, persistent job, application file or log.
The iOS client retains failed audio in memory for retry until a new recording or
sheet dismissal; audio is discarded after the combined response succeeds. A failed
combined request retries recognition and parsing. Once a response is available,
text edits and parsing retries use the retained transcript.

Keep one Uvicorn process for main: each API process would allocate its own model
and queue. More CPU threads or replicas require a load test on the target VM;
the synthetic Mac benchmark is not a VM throughput guarantee.

## Models and local setup

The main Docker image includes the models in a separate cached build layer.
Both Compose files set `T_ONE_MODEL_PATH=/app/models/t_one` only for `backend_main`.
No model downloads occur during HTTP requests or startup. The image grows by about
5.61 GB. The native KenLM toolchain exists only in the dependencies build stage.

For a local Python launch, install `requirements.txt`, then run from `backend/main`:

```sh
PYTHONPATH=. ../../.venv311/bin/python scripts/download_t_one_models.py ../../build/models/t_one
```

Set `T_ONE_MODEL_PATH` to that directory's absolute path in the launch environment.
An existing verified evaluation model directory can be reused. If the variable is
absent, other main features work and audio recognition returns `speechUnavailable`.
`MODEL_SERVICE_TYPE=mock` changes only parsing/generation, not speech recognition.

Pinned upstream: `tone` commit `3c5b6c015038173840e62cea99e10cdb1c759116`.
Model: `t-tech/T-one`, revision `106f3b0b32a9e107eb613312e4ebc61ff3d53926`.
SHA-256 values live in `TOneWorker.checksums`. Changing them requires a new evaluation.

## Legal version

Server audio processing is described in both legal documents. Their shared
`legalDate` is 2026-11-16. Under the existing billing policy, deploying that version
requires acceptance again and disables outdated Robokassa renewal schedules;
paid access remains. The code change does not deploy services or publish pages.
