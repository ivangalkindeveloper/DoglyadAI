![Doglyad AI — AI assistant and medical helper for ultrasound diagnostic doctors](asset/ReadmeBanner.png)

# Doglyad AI

Doglyad is an AI assistant for ultrasound physicians. Its goal is to reduce repetitive medical work: it combines ultrasound images with patient history and examination notes, generates a structured draft report, and helps the physician review the case without losing important details.

> [!IMPORTANT]
> Doglyad is a documentation support tool, not a medical device and not an autonomous diagnostic system. Every generated report must be reviewed and approved by a qualified healthcare professional.

## Table of contents

- [What Doglyad can do](#what-doglyad-can-do)
- [How generation works](#how-generation-works)
- [Technology stack](#technology-stack)
- [Architecture](#architecture)
- [Service integrations](#service-integrations)
- [Security and patient data](#security-and-patient-data)
- [Infrastructure and deployment](#infrastructure-and-deployment)
- [Repository structure](#repository-structure)
- [License](#license)
- [Legal notice and contact](#legal-notice-and-contact)

## What Doglyad can do

### Examination workflow

- Create an ultrasound examination from patient data, complaints, examination notes, and scan images.
- Capture scans with the camera or select them from the photo library.
- Attach images to one request, the limit is remotely configurable.
- Choose from 28 ultrasound examination types, including abdominal, vascular, cardiac, thyroid, renal, pelvic, and soft-tissue studies.
- Select a published multimodal model and tune temperature, maximum output length, and Markdown formatting.
- Generate a new report or regenerate it while retaining earlier versions.
- Copy, share, or send the final report to a configured work email address.

### Voice-assisted form completion

- Dictate patient and examination data instead of filling every field manually.
- Recognize English and Russian medical speech with domain-specific contextual vocabulary.
- Correct common recognition errors using the medical lexicon before parsing the transcript.
- Convert free-form dictation into structured fields with Apple Foundation Models when available or a bundled MLX model as the on-device fallback.

### Organization and personalization

- Store examination history locally with SwiftData.
- Search and reopen previous reports.
- Create one reusable report template for each examination type.
- Configure personal details, a work email, model preferences, and application settings.
- Manage Base and Pro subscription capabilities through RevenueCat.
- Handle onboarding, permissions, application updates, service availability, legal updates, limits, and subscription management inside the app.

## How generation works

### Server-side multimodal report generation

```text
┌─────────────┐    HTTPS     ┌──────────────────────┐    Tailscale    ┌─────────────────────────┐
│ iOS client  │ ───────────► │ backend/main         │  ─────────────► │ backend/inference       │
│             │              │ non-GPU VM           │                 │ GPU VM, one per model   │
│ SwiftUI     │ ◄─────────── │ prompts + routing    │ ◄────────────── │ FastAPI + local vLLM    │
└─────────────┘              └──────────────────────┘                 └────────────┬────────────┘
                                                                                   │
                                                                                   ▼
                                                                      MedGemma multimodal model
```

1. The iOS app validates the form, compresses the selected images, and sends an authenticated request.
2. `backend/main` resolves the examination type and model, builds localized system and user prompts, and selects the GPU endpoint assigned to the model.
3. The original `X-Firebase-AppCheck` token is forwarded unchanged to `backend/inference`.
4. `backend/inference` verifies App Check again and calls its local vLLM through the OpenAI-compatible chat completions API.
5. The generated report returns through the main backend to the app and is saved locally.

The two App Check validations protect different boundaries: the first protects the public API, while the second prevents direct access to a GPU model VM that bypasses the main backend.

### On-device voice parsing

```text
Microphone
   │
   ├─ iOS 26+: SpeechAnalyzer + DictationTranscriber
   └─ fallback: SFSpeechRecognizer
   │
   ▼
Medical lexicon correction
   │
   ├─ Apple Foundation Models, when supported for the device and locale
   └─ bundled Qwen2.5 1.5B 4-bit model through MLX
   │
   ▼
Structured patient and examination fields
```

## Technology stack

| Area | Languages and frameworks | Main libraries and services |
|---|---|---|
| iOS | Swift 5, SwiftUI, MVVM, Swift Concurrency, SwiftData, iOS 18.6+ | Alamofire, Firebase, RevenueCat, MLX, Foundation Models, Speech, AVFoundation, MarkdownUI, BottomSheet, SwiftMessages, SwiftUI-Shimmer |
| iOS AI | Apple Foundation Models, MLX Swift | Qwen2.5 1.5B Instruct 4-bit, swift-transformers |
| Backend Main  | Python 3.11, FastAPI, Pydantic v2, async/await | httpx, pydantic-settings, Firebase Admin SDK, SlowAPI, Uvicorn, SMTP |
| Backend Inference | Python 3.11, FastAPI, Pydantic v2 | httpx, Firebase Admin SDK, Uvicorn, vLLM OpenAI-compatible API |
| Infrastructure | Docker, Docker Compose, Caddy, Tailscale, cloud-init | GitHub Actions, GitHub Container Registry, NVIDIA Container Toolkit and CDI |
| Quality | XCTest, Swift Testing, pytest | Ruff, mypy, SwiftFormat |
| Model runtime | NVIDIA GPU, CUDA, vLLM | Google MedGemma 4B and MedGemma 1.5 4B, Hugging Face model storage |

The iOS project also uses the author's Swift packages: `DependencyInitializer`, `NestedObservableObject`, `Handler`, and `Router`.

## Architecture

### iOS

The client is organized as one application target and several focused local framework targets:

| Target | Responsibility |
|---|---|
| `Doglyad` | Application lifecycle, screens, MVVM presentation logic, domain models, repositories, configuration, and navigation |
| `DoglyadUI` | Design system, theme, typography, and reusable UI components |
| `DoglyadDatabase` | SwiftData entities, persistence, and UserDefaults-backed settings |
| `DoglyadNetwork` | Alamofire-based HTTP client, headers, DTO transport, and network errors |
| `DoglyadNeuralModel` | Foundation Models and MLX-based on-device extraction |
| `DoglyadCamera` | Camera controller and SwiftUI camera surface |
| `DoglyadSpeech` | Speech recognition, audio processing, and medical lexicon correction |

Presentation follows MVVM. Each screen module normally contains `*Screen`, `*ScreenView`, `*ViewModel`, and `*Arguments`. View models do not call other view models directly; modules exchange state through arguments and closures supplied by the router.

Application startup is a tiered dependency-initialization pipeline. Synchronous and asynchronous steps load remote configuration, local persistence, repositories, subscription state, AI availability, and managers before producing a single `DependencyContainer` injected into SwiftUI.

### Backend services

The backend is deliberately split into two independently deployable services:

- `backend/main` runs on a non-GPU VM. It exposes the public API, validates App Check, loads environment-specific product configuration, builds prompts, applies rate limits, routes requests to the selected model VM, and sends reports by email.
- `backend/inference` runs beside vLLM on a GPU VM. A VM serves exactly one model, validates App Check, checks that the requested `modelId` matches `SERVED_MODEL_ID`, and performs generation. It does not contain prompts, localization, templates, or product-domain decisions.

`ENVIRONMENT` selects either `backend/main/config/development` or `backend/main/config/production`. The application downloads the same configuration documents from the deployed main backend so the app and backend cannot disagree about newly published models or examination types.

## Service integrations

- **Firebase App Check** authenticates the iOS client at both backend boundaries.
- **Firebase Analytics and Crashlytics** provide product telemetry and crash diagnostics.
- **RevenueCat** resolves subscription offerings, entitlements, customer-center access, and purchase restoration.
- **Apple Speech** provides `SpeechAnalyzer`/`DictationTranscriber` on supported systems and `SFSpeechRecognizer` as the compatibility path.
- **Apple Foundation Models and MLX** parse dictated text into structured fields on device.
- **Hugging Face** supplies the MedGemma weights used by vLLM and the bundled MLX model used by the app.
- **SMTP** delivers generated reports to a physician's work email through `backend/main`.
- **GitHub Container Registry** stores immutable backend images produced by GitHub Actions.
- **Tailscale** connects the main backend VM to private inference endpoints.

## Security and patient data

- Every application endpoint is versioned under `/v1` and protected by Firebase App Check in all environments; there is no development bypass flag.
- The same App Check token is verified independently by the main backend and the inference backend.
- Configuration is downloaded through the same protected, versioned API after the iOS client configures Firebase and its App Check interceptor.
- The main backend applies client-aware rate limits before forwarding generation requests.
- Caddy terminates public HTTPS traffic; inference services are reached over the private Tailscale network.
- Patient payloads and images are not written to backend logs. Logs contain only operational metadata such as status, model ID, image count, and text lengths.
- Before upload, the iOS client resizes and JPEG-compresses scan images using remotely configured parameters.
- Examination history is persisted locally with SwiftData. The backends process requests in memory and do not provide a server-side patient-history store.
- Secrets, Firebase credentials, environment files, and model weights are excluded from version control and must never be committed.

## Infrastructure and deployment

Production infrastructure uses immutable `linux/amd64` images and two VM roles:

1. **Main VM** — Docker Compose runs Caddy and `backend/main`. Only Caddy is publicly exposed.
2. **Inference VM** — Docker Compose runs `backend/inference` and a pinned vLLM image with NVIDIA GPU access. One VM is configured for one `SERVED_MODEL_ID`.

GitHub Actions builds the two backend images independently and publishes them to GHCR under the commit SHA. VM bootstrap scripts install Docker, Compose, Tailscale, and—on inference machines—the NVIDIA driver, Container Toolkit, and CDI support. Secrets and machine-specific `.env` files are synchronized separately after bootstrap.

For each model published by the main backend, `backend/main/secrets/inference_endpoints.json` must contain the corresponding private inference URL. Missing mappings are treated as configuration errors.

Detailed deployment instructions are available in [`deploy/README.md`](deploy/README.md), while GPU-service configuration is documented in [`backend/inference/README.md`](backend/inference/README.md).

## Repository structure

```text
Doglyad/
├── ios/                         iOS app and local framework targets
│   ├── Doglyad/                 application, modules, domain, repositories
│   ├── DoglyadUI/               design system
│   ├── DoglyadDatabase/         SwiftData persistence
│   ├── DoglyadNetwork/          HTTP client
│   ├── DoglyadNeuralModel/      on-device AI
│   ├── DoglyadCamera/           camera integration
│   ├── DoglyadSpeech/           speech recognition and correction
│   └── DoglyadTests/            unit tests
├── backend/
│   ├── main/                    public API, configuration, prompts, routing
│   └── inference/               protected GPU-side generation service
├── deploy/                      VM bootstrap, cloud-init, Compose, secret sync
├── docs/legal/                  privacy policy and terms and conditions
├── ml/                          experimental model tooling
├── scripts/                     repository automation
├── asset/                       README and product artwork
├── Makefile                     development, build, and deployment commands
└── AGENTS.md                    project conventions for coding agents
```

## License

Doglyad is **proprietary source-available software**, not open-source software. Copyright © 2026 Ivan Galkin. All rights reserved.

Except for the limited rights provided by GitHub's Terms of Service to access, view, and fork a public repository through GitHub, no permission is granted to use, run, copy, modify, build, deploy, publish, distribute, sublicense, or commercialize any part of this project without prior explicit written authorization from the copyright holder. This restriction applies to personal, educational, research, evaluation, non-commercial, and commercial use.

The names **Doglyad** and **Догляд**, the logo, application icon, mascot, and associated visual assets are proprietary brand assets. No trademark or brand-use rights are granted.

See the [Doglyad Proprietary License](LICENSE) for the complete terms. Permission requests may be sent to [doglyadapp@gmail.com](mailto:doglyadapp@gmail.com).

## Legal notice and contact

Doglyad assists physicians with preparing documentation. It does not replace professional clinical judgment, provide a final diagnosis, or remove the physician's responsibility to validate generated content.

- [Privacy Policy](https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy)
- [Terms and Conditions](https://ivangalkindeveloper.github.io/DoglyadAI/legal/terms-and-conditions)
- Contact: [doglyadapp@gmail.com](mailto:doglyadapp@gmail.com)
