# Doglyad workflow

## Shared agent harness

- Maintain shared skills, hooks, MCP definitions and agent adapters in `harness/`; see [the harness guide](../../harness/README.md).
- Run `make sync-harness` after changing those sources or updating a checkout, then `make check-harness`. Use [sync-harness](../../harness/skills/sync-harness/SKILL.md) for this workflow.
- `PostToolUse` formats Swift and checks architecture in edited source files. Run `make check-architecture` for the full project or after shell edits. Rules and limitations are documented in [harness/README.md](../../harness/README.md); the check does not build the app or run model evaluations.
- `.codex/`, `.claude/`, `.agents/`, `.mcp.json`, `.mobilebuildmcp/` and `CLAUDE.md` are ignored generated outputs. Edit their maintained sources instead. Preserve personal agent settings and resolve reported conflicts before synchronizing.
- Keep `AGENTS.md` as the shared instruction entry point. Generated `CLAUDE.md` imports it. Never put credentials in harness sources.
- Mobile regression cases and scripts live in `test/`; run artifacts live in `build/regression/runs/`. iOS support lives in `ios/Doglyad/Regression/`, with native checks in `ios/DoglyadTests/Regression/` and `ios/DoglyadUITests/Regression/`. Use `test-regress-run` for a clean full run and Figma publication, and `test-regress-update` to review source changes and refresh cases. Figma updates require every registered case and expected screenshot to pass; see [test/README.md](../../test/README.md).
- When the user explicitly requests only Preview updates, use `make previews-figma`. This separate rendering-only mode requires every registered full-module Preview and screenshot to pass, writes artifacts under `build/previews/runs/`, and replaces only the Figma Preview section. It preserves existing regression screenshots and never reports functional regression success. In Figma, use the visible section name «Макеты» and screen names without a «Preview» prefix; keep internal Preview metadata for publication checks. Full regression publication retains its complete-suite requirements.

## Commands

The `Makefile` contains all project commands. Common targets:

- `make venv` / `make pip-install` — create a Python 3.11 environment and install `backend/main/requirements.txt`.
- `make format` — run the iOS and Python formatting pipelines.
- `make format-backend` / `make lint-backend` — apply or check argument line breaks and Ruff formatting for every Python source under `backend/`.
- `make format-ios` / `make lint-ios` — apply or check SwiftFormat and the mandatory argument line breaks without modifying protected resource/configuration folders.
- `make start-local-billing` / `make stop-local-billing` — start local PostgreSQL 17 and apply migrations, or stop it while preserving its Docker volume. VS Code local profiles run this preparation before `app.local_main`, which starts the API and report worker together. They supply the matching loopback-only database URL; the launcher creates and reuses a private local report-encryption key if none is provided.
- `make reset-local-billing` — recreate the dedicated local PostgreSQL volume and apply migrations. Requires the local API to be stopped and a local Docker Unix socket. This deletes all local billing data; it is the prelaunch action only for `Backend: Local Mock (Cold)` and `Backend: Local Inference (Cold)`.
- `make sync-harness` / `make check-harness` — generate or verify local agent settings and skills from `harness/` without starting application or model checks.
- `make init-ios-local` — update the local iOS `BASE_URL` with the `en0` address; see [init-ios-local](../../harness/skills/init-ios-local/SKILL.md).
- `make build-ios-debug-local` / `make build-ios-debug-development` / `make build-ios-release-development` / `make build-ios-release-production` — build the matching Xcode scheme; override `IOS_DEST` to select another simulator.
- `make start-backend-main-development` / `make start-backend-main-production` — run the main backend with the matching environment profile.
- `make check-infrastructure` / `make update-infrastructure` — check or update all inventoried existing backend VMs through the central deployment script. Set `INFRASTRUCTURE_SCOPE=main` to select both main environments without contacting inference VMs; inference availability/routes are unverified in this mode. See `deploy/README.md`; `start-backend-*` builds from source and is not the deployed-fleet update path.
- `make render-inference` — generate a GPU-host deployment from `INFERENCE_PROFILE` into `INFERENCE_OUTPUT` (defaults: the DGX profile and `build/inference/dgx-spark`). Does not connect to hosts or start containers. Edit profiles, not generated Compose files.
- `make start-backend-main-logs` / `make stop-backend-main` — follow logs or stop the main backend.
- `make start-backend-inference` / `make start-backend-inference-logs` / `make stop-backend-inference` — manage the inference stack **on a GPU VM**, not on a developer machine. The stack starts vLLM with `SERVED_MODEL_ID` and the adjacent inference service.
