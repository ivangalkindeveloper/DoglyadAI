.PHONY: \
	sync-harness \
	check-harness \
	check-architecture \
	regression \
	regression-check \
	regression-doctor \
	regression-figma \
	regression-publish \
	venv \
	pip-install \
	pip-install-dev \
	format \
	format-backend \
	lint-backend \
	format-ios \
	lint-ios \
	init-ios-local \
	build-ios-debug-local \
	build-ios-debug-development \
	build-ios-release-development \
	build-ios-release-production \
	upload-ios-release-development \
	upload-ios-release-production \
	start-backend-main-development \
	start-local-billing \
	stop-local-billing \
	reset-local-billing \
	start-backend-main-production \
	start-backend-main-logs \
	stop-backend-main \
	sync-secrets-main-development \
	sync-secrets-main-production \
	update-infrastructure \
	check-infrastructure \
	render-inference \
	start-backend-inference \
	start-backend-inference-logs \
	stop-backend-inference \
	sync-secrets-inference \
	init-vm-main \
	init-vm-inference \
	voice-eval-text \
	voice-eval-audio \
	voice-eval-audio-extended \
	voice-eval-audio-v2 \
	voice-eval-guided-format-audio \
	voice-eval-reordered-format-audio \
	voice-eval-freeform-audio \
	voice-eval-asr-macos \
	voice-eval-asr-compare \
	voice-eval-fleurs \
	voice-eval-ios \
	voice-eval-ios-candidate \
	voice-eval-verify \
	voice-eval-report
.SILENT:

IOS_DEST ?= platform=iOS Simulator,name=iPhone 17
IOS_ARCHIVE_DIR ?= $(CURDIR)/build/ios-archives
IOS_EXPORT_OPTIONS_PLIST := $(CURDIR)/ios/ExportOptions.plist
IOS_ARCHIVE_TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
IOS_XCODE_PATH := /usr/bin:/bin:/usr/sbin:/sbin:$(PATH)

# Prefer the project venv so `make format` works without activating it first.
RUFF ?= $(shell if [ -x "$(CURDIR)/.venv311/bin/ruff" ]; then echo "$(CURDIR)/.venv311/bin/ruff"; else echo ruff; fi)
BACKEND_FORMAT_PYTHON ?= $(shell if [ -x "$(CURDIR)/.venv311/bin/python" ]; then echo "$(CURDIR)/.venv311/bin/python"; else echo python3; fi)

venv:
	python3.11 -m venv .venv311
	source .venv311/bin/activate

pip-install:
	pip3 install -r backend/main/requirements.txt
	pip3 install -r test/requirements.txt

pip-install-dev:
	pip3 install -r backend/main/requirements-dev.txt

sync-harness:
	python3 tools/sync_harness.py

check-harness:
	python3 tools/sync_harness.py --check

check-architecture:
	python3 harness/checks/architecture.py

regression-check:
	python3 test/scripts/catalog.py --check
	python3 test/scripts/scenario_coverage.py --check
	python3 test/scripts/regression.py validate

regression-doctor:
	python3 test/scripts/regression.py doctor

regression:
	python3 test/scripts/regression.py run

regression-figma:
	python3 test/scripts/regression.py run --publish

regression-publish:
	@test -n "$(RUN)" || (echo 'Use RUN=build/regression/runs/<run-id>'; exit 1)
	python3 test/scripts/figma_bridge.py "$(RUN)"

format: format-ios format-backend

format-backend:
	"$(BACKEND_FORMAT_PYTHON)" tools/format_python.py --ruff "$(RUFF)"

lint-backend:
	"$(BACKEND_FORMAT_PYTHON)" tools/format_python.py --check --ruff "$(RUFF)"

format-ios:
	python3 tools/format_ios.py

lint-ios:
	python3 tools/format_ios.py --check

init-ios-local:
	@set -e; \
	IP="$$(ipconfig getifaddr en0)"; \
	sed -i '' 's|^BASE_URL = .*|BASE_URL = http:/$$()/'''"$${IP}:8000"'|' ios/Config/Config.Local.xcconfig; \
	cat ios/Config/Config.Local.xcconfig

build-ios-debug-local:
	cd ios && xcodebuild build \
		-project Doglyad.xcodeproj \
		-scheme Doglyad-Debug-Local \
		-destination '$(IOS_DEST)'

build-ios-debug-development:
	cd ios && xcodebuild build \
		-project Doglyad.xcodeproj \
		-scheme Doglyad-Debug-Development \
		-destination '$(IOS_DEST)'

build-ios-release-development:
	cd ios && xcodebuild build \
		-project Doglyad.xcodeproj \
		-scheme Doglyad-Release-Development \
		-destination '$(IOS_DEST)'

build-ios-release-production:
	cd ios && xcodebuild build \
		-project Doglyad.xcodeproj \
		-scheme Doglyad-Release-Production \
		-destination '$(IOS_DEST)'

upload-ios-release-development:
	mkdir -p "$(IOS_ARCHIVE_DIR)"
	PATH="$(IOS_XCODE_PATH)" xcodebuild archive \
		-project ios/Doglyad.xcodeproj \
		-scheme Doglyad-Release-Development \
		-configuration Release-Development \
		-destination 'generic/platform=iOS' \
		-archivePath "$(IOS_ARCHIVE_DIR)/Doglyad-Release-Development-$(IOS_ARCHIVE_TIMESTAMP).xcarchive" \
		-allowProvisioningUpdates
	PATH="$(IOS_XCODE_PATH)" xcodebuild -exportArchive \
		-archivePath "$(IOS_ARCHIVE_DIR)/Doglyad-Release-Development-$(IOS_ARCHIVE_TIMESTAMP).xcarchive" \
		-exportOptionsPlist "$(IOS_EXPORT_OPTIONS_PLIST)" \
		-allowProvisioningUpdates

upload-ios-release-production:
	mkdir -p "$(IOS_ARCHIVE_DIR)"
	PATH="$(IOS_XCODE_PATH)" xcodebuild archive \
		-project ios/Doglyad.xcodeproj \
		-scheme Doglyad-Release-Production \
		-configuration Release-Production \
		-destination 'generic/platform=iOS' \
		-archivePath "$(IOS_ARCHIVE_DIR)/Doglyad-Release-Production-$(IOS_ARCHIVE_TIMESTAMP).xcarchive" \
		-allowProvisioningUpdates
	PATH="$(IOS_XCODE_PATH)" xcodebuild -exportArchive \
		-archivePath "$(IOS_ARCHIVE_DIR)/Doglyad-Release-Production-$(IOS_ARCHIVE_TIMESTAMP).xcarchive" \
		-exportOptionsPlist "$(IOS_EXPORT_OPTIONS_PLIST)" \
		-allowProvisioningUpdates

start-local-billing:
	"$(BACKEND_FORMAT_PYTHON)" tools/local_billing_database.py

stop-local-billing:
	"$(BACKEND_FORMAT_PYTHON)" tools/local_billing_database.py --stop

reset-local-billing:
	"$(BACKEND_FORMAT_PYTHON)" tools/local_billing_database.py --reset

start-backend-main-development:
	ENV_FILE=secrets/.env.development bash deploy/start-backend.sh main
start-backend-main-production:
	ENV_FILE=secrets/.env.production bash deploy/start-backend.sh main
start-backend-main-logs:
	docker compose -f backend/main/docker-compose.yml logs -f
stop-backend-main:
	docker compose -f backend/main/docker-compose.yml down

start-backend-inference:
	bash deploy/start-backend.sh inference
start-backend-inference-logs:
	docker compose --env-file backend/inference/secrets/.env -f backend/inference/docker-compose.yml logs -f
stop-backend-inference:
	docker compose --env-file backend/inference/secrets/.env -f backend/inference/docker-compose.yml down

init-vm-main:
	test -n "$(TARGET)" || { echo "TARGET is required: make init-vm-main TARGET=USER@HOST" >&2; exit 1; }
	deploy/init-vm.sh main "$(TARGET)"
init-vm-inference:
	test -n "$(TARGET)" || { echo "TARGET is required: make init-vm-inference TARGET=USER@HOST" >&2; exit 1; }
	deploy/init-vm.sh inference "$(TARGET)"

sync-secrets-main-development sync-secrets-main-production:
	test -n "$(TARGET)" || { echo "TARGET is required: make $@ TARGET=USER@HOST" >&2; exit 1; }
	deploy/sync-secrets.sh main "$(TARGET)"
sync-secrets-inference:
	test -n "$(TARGET)" || { echo "TARGET is required: make sync-secrets-inference TARGET=USER@HOST" >&2; exit 1; }
	deploy/sync-secrets.sh inference "$(TARGET)"

INFRASTRUCTURE_INVENTORY ?= deploy/secrets/infrastructure.json
INFRASTRUCTURE_REF ?= master
INFRASTRUCTURE_SCOPE ?= all
INFERENCE_PROFILE ?= deploy/inference/profiles/dgx-spark.json
INFERENCE_OUTPUT ?= build/inference/dgx-spark

render-inference:
	python3 deploy/inference/render.py --profile "$(INFERENCE_PROFILE)" --output "$(INFERENCE_OUTPUT)"

update-infrastructure:
	bash deploy/update-infrastructure.sh --inventory "$(INFRASTRUCTURE_INVENTORY)" --ref "$(INFRASTRUCTURE_REF)" --scope "$(INFRASTRUCTURE_SCOPE)"

check-infrastructure:
	bash deploy/update-infrastructure.sh --inventory "$(INFRASTRUCTURE_INVENTORY)" --scope "$(INFRASTRUCTURE_SCOPE)" --check

voice-eval-text:
	python3 -m evaluation.voice.datasets.generate

voice-eval-audio:
	python3 -m evaluation.voice.audio.audio --mode quick

voice-eval-audio-extended:
	python3 -m evaluation.voice.audio.audio --mode extended

voice-eval-audio-v2:
	python3 -m evaluation.voice.audio.audio_v2

voice-eval-guided-format-audio:
	python3 -m evaluation.voice.audio.guided_format

voice-eval-reordered-format-audio:
	python3 -m evaluation.voice.audio.reordered_format

voice-eval-freeform-audio:
	python3 -m evaluation.voice.audio.freeform_audio

voice-eval-asr-macos: voice-eval-audio
	python3 -m evaluation.voice.runners.asr --mode quick

voice-eval-asr-compare: voice-eval-audio
	python3 -m evaluation.voice.analysis.comparison --mode quick

voice-eval-fleurs:
	python3 -m evaluation.voice.audio.fleurs --locale both
	python3 -m evaluation.voice.runners.fleurs_eval

voice-eval-ios: voice-eval-audio
	python3 -m evaluation.voice.runners.run_ios

voice-eval-ios-candidate: voice-eval-audio
	python3 -m evaluation.voice.runners.run_ios --candidate

voice-eval-verify:
	python3 -m evaluation.voice.runners.verify

voice-eval-report:
	python3 -m evaluation.voice.analysis.report --strict
