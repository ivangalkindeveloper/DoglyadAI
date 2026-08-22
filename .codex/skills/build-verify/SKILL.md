---
name: build-verify
description: Verify Doglyad changes before commit by building or testing iOS with xcodebuild and checking both backends with Ruff, mypy, and pytest. Use for requests such as verify the build, run the tests, or confirm that the project compiles.
---

# Verify Doglyad builds and tests

Close the loop from implementation to a verified result. Run checks after changes and before `git-push`. Prefer the project commands and configurations instead of inventing alternative invocations.

## Select the scope

1. Identify whether changes affect iOS, the main backend, inference, or a shared contract. Run only relevant checks.
2. Use `iPhone 17` through `IOS_DEST` by default. If unavailable, select an installed simulator with `make build-ios-debug-development IOS_DEST='platform=iOS Simulator,name=<name>'`.
3. Verify Development by default. Verify Production when release behavior or production configuration is affected.

## Backend checks

Check `backend/main` and `backend/inference` independently. Check both when their shared contract changes.

```bash
make format

cd backend/main
../../.venv311/bin/python -m ruff check app tests
../../.venv311/bin/python -m mypy
../../.venv311/bin/python -m pytest

cd ../inference
../../.venv311/bin/python -m ruff check app tests
../../.venv311/bin/python -m mypy
../../.venv311/bin/python -m pytest
```

Install main development dependencies with `make pip-install-dev` and inference dependencies with `pip3 install -r backend/inference/requirements-dev.txt`. Record pytest exit code 5 for no collected tests without treating it as a code failure. Separate pre-existing mypy errors from new regressions.

## iOS checks

```bash
make format
make build-ios-debug-development
make build-ios-release-production
```

Run tests directly:

```bash
cd ios
xcodebuild test \
  -project Doglyad.xcodeproj \
  -scheme Doglyad-Debug-Development \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Extract relevant `error:`, `** BUILD FAILED **`, or `** TEST FAILED **` lines from failures. Select another installed simulator when needed.

Switch environments with schemes. Never edit files in `ios/Config/` or `ios/Firebase/`. If required untracked configuration files are missing, ask the user to provide them instead of generating substitutes.

## Report

1. Summarize each checked part and include file and line for failures.
2. Do not commit automatically; `git-push` owns that operation.
3. Never present failed checks as success. Explain the error and offer to fix it.
