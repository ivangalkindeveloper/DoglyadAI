---
name: git-push
description: Commit and push Doglyad changes according to project conventions. Format code, stage all changes except secrets and generated noise, write a short imperative English commit message, commit to master, and push to origin. Use when asked to commit, push, or send changes.
---

# Commit and push Doglyad changes

Prepare and send changes according to repository conventions. Work directly on `master` unless the user explicitly requests a branch. The remote is `origin` at `ivangalkindeveloper/DoglyadAI`.

## Resolve before starting

1. Use a user-provided commit message or create one from the rules below.
2. Push to `origin master` by default. If the user asks only for a commit, do not push.

Commit all relevant working-tree changes with `git add -A`, excluding protected and noisy files.

## Required rules

- Run `make format` before committing.
- Never commit `backend/main/secrets/`, `backend/inference/secrets/`, `ios/Config/`, `ios/Firebase/`, or `ios/DoglyadNeuralModel/Resources/`.
- Exclude `*.xcuserstate` and `xcschememanagement.plist` unless explicitly requested.
- Write a short English commit subject in imperative mood, capitalized, without a trailing period. Examples: `Add version`, `Fix settings buttons`, `Fix gallery button`, `Add skills`.
- Commit directly to `master`. Do not create a branch unless requested.

## Procedure

1. Inspect `git status` and `git diff`. Confirm that no merge or rebase is in progress and identify protected or unrelated files.
2. Run `make format`.
3. Run `git add -A`, then inspect `git status`. Remove protected or noisy paths with `git restore --staged <path>`.
4. Commit with a conventional subject:

```bash
git commit -m "Fix subscription paywall layout"
```

When Claude Code authors the commit, append:

```text
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

5. Push when requested:

```bash
git push origin master
```

## Report

Provide the included files, commit subject, commit hash, and push result. If push is rejected as non-fast-forward, run `git pull --rebase origin master`, resolve conflicts, and retry. Never force-push without explicit permission.
