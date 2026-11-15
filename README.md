![Doglyad AI — assistant for ultrasound physicians](asset/ReadmeBanner.png)

# Doglyad AI

Doglyad helps ultrasound physicians prepare and review examination reports. The iOS
app combines examination notes, patient data and images, then receives a structured
report from a selected model. Voice input reduces manual form entry. The physician
reviews the generated content before using it in clinical work.

The project is in development. Code and deployment templates in this repository
do not establish that a feature is configured, deployed or approved for release.

## Contents

- [Application features](#application-features)
- [Architecture](#architecture)
- [Generation and data storage](#generation-and-data-storage)
- [Subscriptions](#subscriptions)
- [Local development](#local-development)
- [Deployment and backups](#deployment-and-backups)
- [Checks and agent instructions](#checks-and-agent-instructions)
- [Repository map](#repository-map)
- [License](#license)
- [Legal notice and contact](#legal-notice-and-contact)

## Application features

- Enter patient data, examination notes and complaints; capture or import images.
- Select an examination type, report template and available generation model.
- Save a form draft, examination history, photos and report versions locally.
- Receive report text progressively; reopen a running examination or retry an
  interrupted attempt while retaining the previous result.
- Review findings and image annotations, copy or share a completed report, or send
  it to a configured work email address.
- Create and edit reusable templates for examination types.
- Dictate form values using WhisperKit, Apple SpeechAnalyzer or SFSpeechRecognizer,
  subject to device, OS and language support. WhisperKit requires model weights.
- Parse dictated text with Apple Foundation Models on supported devices or through
  the server. Validate transcript evidence and offer uncertain values for review.
  The parser is an explicit setting; an unavailable local parser does not silently
  change the selected engine.
- Manage Base and Pro access, subscription restoration, recovery keys and renewal
  settings. Product availability, limits and localized text come from the backend.

The client targets iOS 18.6 or later. Foundation Models and SpeechAnalyzer require
newer supported systems and hardware; they are optional capabilities. The project
uses Swift 5 language mode, SwiftUI, Swift Concurrency, SwiftData and StoreKit 2.
See [speech](ios/DoglyadSpeech/README.md) and
[text extraction](ios/DoglyadNeuralModel/README.md) for their device and model flows.

## Architecture

```text
iOS: SwiftUI / MVVM / local persistence
                  │ HTTPS + App Check + owner bearer where required
                  ▼
Main VM: Caddy → FastAPI API
                  ├─ report worker ── private route ──► inference API → vLLM engines
                  ├─ payment gateway + subscription worker
                  ├─ PostgreSQL: shared application database
                  └─ SMTP

PostgreSQL → encrypted pgBackRest repository → Yandex Disk: full backup + WAL
```

`backend/main` runs on a non-GPU machine. It owns public configuration, localization,
prompts, request policies, subscription access, persistent report jobs and SMTP.
The API, report worker, payment gateway and subscription worker share one release
and one PostgreSQL database, `doglyad_database`.

`backend/inference` runs beside one or more vLLM engines on a GPU host. It validates
App Check, routes `modelId` to a local engine and returns structured or streamed
output. Prompts and product configuration remain in main. A host can serve several
models; the current DGX Spark profile defines five engines. Other host profiles can
use different model sets. See [inference deployment](deploy/inference/README.md).

The main and inference APIs validate App Check independently. Main forwards the
original token to inference. Owner-specific operations also require an anonymous
bearer identity; a UUID, browser return or existing subscription alone does not
prove that a particular purchase or report job belongs to the caller.

On iOS, modules use SwiftUI and MVVM with immutable lifecycle states. View models
publish new state instances, including `copyWith` updates within the same phase.
Modules and root view models exchange data through closures. `DoglyadUI` supplies
visible application controls and styling. Application initialization composes
repositories and shared services in ordered dependency tiers.

## Generation and data storage

1. The app saves the examination locally before requesting generation.
2. Main accepts an owner-scoped job through
   `POST /v1/ultrasound/report_generations` and returns `202` with its identity.
3. A report worker builds the prompt and calls the configured inference endpoint.
4. The app receives job snapshots through SSE or reads the current snapshot after
   reconnecting. Closing the report screen does not cancel the server job.
5. Main validates the completed report and settles its reserved usage. The app
   retains the result in its local examination history.

PostgreSQL stores subscriptions, payments, usage and temporary generation jobs.
Report requests and snapshots are encrypted with the environment's
`REPORT_GENERATION_ENCRYPTION_KEY`. The source request and its App Check token are
removed when processing finishes. Jobs expire after the configured retention
period, currently 12 hours; the worker physically removes expired rows. Database
backups have their own retention and can outlive the corresponding live rows.

Long-term examination history remains in the client's SwiftData storage. Main does
not currently expose a server-side patient-history account or synchronization API.
Patient text, images and generated reports must not be written to technical logs.

See [the generation contract and lifecycle](backend/main/REPORT_STREAMING.md).

## Subscriptions

The repository factory selects Robokassa for the Russian storefront and StoreKit
for other storefronts. Provider credentials stay on the backend. Robokassa opens
its payment page through the system browser session and collects receipt details.
Only verified provider evidence grants access; returning to the app is insufficient.

For Robokassa, a new paid plan starts immediately at its full price and replaces
previous access without carrying over unused time. Existing automatic renewal can
be disabled; enabling it requires a new purchase. Recovery keys restore access on
another device. StoreKit owns Apple purchase and management operations.

`ENVIRONMENT=development` selects development configuration and Robokassa test
payments; `production` selects production configuration and live payments. Generation
implementation is selected independently through `MODEL_SERVICE_TYPE`.

See [billing integration](backend/main/BILLING.md),
[local payment checks](backend/main/BILLING_LOCAL.md) and
[release requirements](backend/main/BILLING_RELEASE_PLAN.md).

## Local development

Use macOS with a suitable Xcode toolchain, Python 3.11 and Docker with Compose.
Backend development dependencies include Ruff and mypy; iOS formatting uses
SwiftFormat and the selected Xcode's SwiftSyntax libraries.

```sh
make venv
source .venv311/bin/activate
make pip-install
make pip-install-dev
make sync-harness
```

Supply the private environment and Firebase files described in the
[main-backend guide](backend/main/README.md). They are excluded from Git. App Check
remains enabled during local fixture generation.

In VS Code, select `Backend: Local Mock` or `Backend: Local Inference`. Their
prelaunch tasks prepare PostgreSQL and migrations; `app.local_main` starts the API
and report worker together. Mock returns local generation fixtures. Inference
requires a reachable GPU host and an endpoint-map entry for each selected model.
SMTP, localization, authentication and validation retain their normal behavior.

The ordinary local profiles preserve database data. The two **Cold** profiles
recreate only the dedicated local database. For a clean billing identity, pair them
with `Doglyad-Debug-Local-Clean`. See the [local guide](backend/main/README.md).

Before running iOS against the Mac, use `make init-ios-local`, then select
`Doglyad-Debug-Local`. The explicit database commands are
`make start-local-database`, `make stop-local-database` and
`make reset-local-database`; reset deletes local application data.

## Deployment and backups

Main images and the PostgreSQL image target Linux amd64. Inference images support
amd64 and arm64; the DGX Spark uses an arm64 host profile. Docker, Caddy, Tailscale,
NVIDIA runtime tools and GHCR provide the deployment foundation.

- `deploy/docker-compose.main.yml` defines the four main application processes and
  Caddy. `deploy/docker-compose.database.yml` defines PostgreSQL and the shared
  `database_migrate` job. `deploy/main-compose.sh` combines them.
- `deploy/configure_main.py` initializes main storage, database backups, migrations,
  application processes and timers. `deploy/Caddyfile` routes API and payment traffic.
- `deploy/inference/` defines model-host profiles, private engine routes and startup.
- `deploy/secrets/infrastructure.json` is the private fleet inventory used by
  `make check-infrastructure` and `make update-infrastructure`. It contains SSH
  targets, deployment directories and model/profile assignments, rather than
  application passwords. Keep it current; an omitted host is not updated.
- The central updater stages published images, stops all four main writers, takes
  a verified remote backup and applies Alembic migrations before starting the new
  release. Applied or uncertain migrations block automatic old-image rollback.

Full encrypted database backups run daily and before migrations. WAL is uploaded
to Yandex Disk every five minutes. The destination is `DoglyadAIDB`, with separate
folders for development and production. One latest completed backup set is retained
per environment; a replacement is verified before the old set is removed. File
names include UTC time and a unique ID. Large archives are split into parts.
External heartbeat checks and isolated recovery drills require owner configuration.
These templates do not establish that live backups have already been enabled.

Start with [deployment](deploy/README.md),
[database operations and required backup settings](deploy/database/README.md), and
[DGX setup](deploy/dgx-spark/README.md).

## Checks and agent instructions

[AGENTS.md](AGENTS.md) is the instruction entry point. The seven maintained rule
documents and shared agent skills, hooks and settings live in
[harness/](harness/README.md). Run `make sync-harness` after changes there;
`make check-harness` verifies the generated agent adapters.

```sh
make lint-ios
make lint-backend
make check-architecture
make check-harness
make regression-check
```

Formatting, architecture checks and regression-catalog validation are separate
checks. Passing one does not establish a successful build or functional regression.
For backend lint, typing and tests, and iOS build commands, see
[build verification](harness/skills/build-verify/SKILL.md).

The complete mobile regression creates an isolated local stack and runs the
registered functional cases before publishing screenshots to Figma. Preview-only
rendering is a separate mode: `make previews-figma` updates the «Макеты» section
without claiming functional coverage. See [mobile verification](test/README.md).
Voice and model-quality experiments live in [evaluation/](evaluation/voice/README.md).

## Repository map

| Path | Purpose |
|---|---|
| `ios/Doglyad/` | App lifecycle, modules, domain, repositories and regression adapters |
| `ios/DoglyadUI/` | Shared design system |
| `ios/DoglyadDatabase/` | SwiftData, preferences and billing identity storage |
| `ios/DoglyadNetwork/` | HTTP transport and SSE decoding |
| `ios/DoglyadNeuralModel/` | On-device extraction and shared proposal validation |
| `ios/DoglyadCamera/`, `ios/DoglyadSpeech/` | Camera and speech integrations |
| `backend/main/` | Product API, configuration, jobs, billing, prompts and email |
| `backend/inference/` | Protected GPU transport and local engine routing |
| `deploy/` | Provisioning, deployment, database operations and model-host profiles |
| `test/` | Functional cases, Preview inventory and Figma publication |
| `evaluation/` | Speech and model evaluations |
| `tools/` | Formatters, local database preparation and harness synchronization |
| `harness/` | Shared instructions, skills and agent tooling |
| `docs/legal/` | Privacy policy and terms |
| `asset/` | Project artwork |

## License

Doglyad is **proprietary source-available software**, not open-source software. Copyright © 2026 Ivan Galkin. All rights reserved.

Except for the limited rights provided by GitHub's Terms of Service to access, view, and fork a public repository through GitHub, no permission is granted to use, run, copy, modify, build, deploy, publish, distribute, sublicense, or commercialize any part of this project without prior explicit written authorization from the copyright holder. This restriction applies to personal, educational, research, evaluation, non-commercial, and commercial use.

The names **Doglyad** and **Догляд**, the logo, application icon, mascot, and associated visual assets are proprietary brand assets. No trademark or brand-use rights are granted.

See the [Doglyad Proprietary License](LICENSE) for the complete terms. Permission requests may be sent to [support@doglyad.ru](mailto:support@doglyad.ru).

## Legal notice and contact

Doglyad assists physicians with preparing documentation. It does not replace professional clinical judgment, provide a final diagnosis, or remove the physician's responsibility to validate generated content.

- [Privacy Policy](https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy)
- [Terms and Conditions](https://ivangalkindeveloper.github.io/DoglyadAI/legal/terms-and-conditions)
- Contact: [support@doglyad.ru](mailto:support@doglyad.ru)
