.PHONY: \
	venv \
	pip-install \
	pip-install-dev \
	format \
	init-ios-local \
	build-ios-debug-local \
	build-ios-debug-development \
	build-ios-release-development \
	build-ios-release-production \
	start-backend-main-development \
	start-backend-main-production \
	start-backend-main-logs \
	stop-backend-main \
	sync-secrets-main-development \
	sync-secrets-main-production \
	update-main-development \
	update-main-production \
	start-backend-inference \
	start-backend-inference-logs \
	stop-backend-inference \
	sync-secrets-inference \
	init-vm-main \
	init-vm-inference \
	download-ios-examination-model
.SILENT:

IOS_DEST ?= platform=iOS Simulator,name=iPhone 17

# Prefer the project venv so `make format` works without activating it first.
RUFF ?= $(shell if [ -x "$(CURDIR)/.venv311/bin/ruff" ]; then echo "$(CURDIR)/.venv311/bin/ruff"; else echo ruff; fi)

venv:
	python3.11 -m venv .venv311
	source .venv311/bin/activate

pip-install:
	pip3 install -r backend/main/requirements.txt

pip-install-dev:
	pip3 install -r backend/main/requirements-dev.txt

format:
	cd ios && swiftformat .
	cd backend/main && "$(RUFF)" format app tests
	cd backend/inference && "$(RUFF)" format app tests

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

start-backend-main-development:
	ENV_FILE=secrets/.env.development \
	docker compose -f backend/main/docker-compose.yml up --build -d
start-backend-main-production:
	ENV_FILE=secrets/.env.production \
	docker compose -f backend/main/docker-compose.yml up --build -d
start-backend-main-logs:
	docker compose -f backend/main/docker-compose.yml logs -f
stop-backend-main:
	docker compose -f backend/main/docker-compose.yml down

# Inference service. Run this ON a GPU VM, not on a developer machine:
# it starts vLLM with SERVED_MODEL_ID and the adjacent backend/inference service.
# --env-file is required because Compose substitutes ${VAR} in docker-compose.yml
# only from its own environment file, not from a service's env_file section.
start-backend-inference:
	docker compose --env-file backend/inference/secrets/.env -f backend/inference/docker-compose.yml up --build -d
start-backend-inference-logs:
	docker compose --env-file backend/inference/secrets/.env -f backend/inference/docker-compose.yml logs -f
stop-backend-inference:
	docker compose --env-file backend/inference/secrets/.env -f backend/inference/docker-compose.yml down

# Initialize a clean VM from a local machine: bootstrap, reboot, verification,
# and Tailscale connection without manually entering an interactive SSH session.
# Example: make init-vm-inference TARGET=root@203.0.113.10
init-vm-main:
	test -n "$(TARGET)" || { echo "TARGET is required: make init-vm-main TARGET=USER@HOST" >&2; exit 1; }
	deploy/init-vm.sh main "$(TARGET)"
init-vm-inference:
	test -n "$(TARGET)" || { echo "TARGET is required: make init-vm-inference TARGET=USER@HOST" >&2; exit 1; }
	deploy/init-vm.sh inference "$(TARGET)"

# Transfer local secrets and apply them on an already initialized VM.
# The main deployment profile remains controlled by /opt/doglyad/.env on the VM;
# separate targets make the intended environment explicit at the call site.
sync-secrets-main-development sync-secrets-main-production:
	test -n "$(TARGET)" || { echo "TARGET is required: make $@ TARGET=USER@HOST" >&2; exit 1; }
	deploy/sync-secrets.sh main "$(TARGET)"
sync-secrets-inference:
	test -n "$(TARGET)" || { echo "TARGET is required: make sync-secrets-inference TARGET=USER@HOST" >&2; exit 1; }
	deploy/sync-secrets.sh inference "$(TARGET)"

# Deploy an image that has already been published by the GitHub Actions build.
# Example: make update-main-development TARGET=USER@HOST TAG=$$(git rev-parse HEAD)
update-main-development:
	test -n "$(TARGET)" || { echo "TARGET is required: make update-main-development TARGET=USER@HOST TAG=IMAGE_TAG" >&2; exit 1; }
	test -n "$(TAG)" || { echo "TAG is required: make update-main-development TARGET=USER@HOST TAG=IMAGE_TAG" >&2; exit 1; }
	deploy/update-main.sh development "$(TARGET)" "$(TAG)"
update-main-production:
	test -n "$(TARGET)" || { echo "TARGET is required: make update-main-production TARGET=USER@HOST TAG=IMAGE_TAG" >&2; exit 1; }
	test -n "$(TAG)" || { echo "TAG is required: make update-main-production TARGET=USER@HOST TAG=IMAGE_TAG" >&2; exit 1; }
	deploy/update-main.sh production "$(TARGET)" "$(TAG)"

download-ios-examination-model:
	sudo hf download mlx-community/Qwen2.5-1.5B-Instruct-4bit --local-dir ios/DoglyadNeuralModel/Resources/mlx-Qwen2.5-1.5B-Instruct-4bit
