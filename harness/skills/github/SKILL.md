---
name: github
description: Reference for Git and GitHub work in Doglyad, including available commands, branch and commit conventions, the remote repository, and related skills. Use to inspect status, history, or diffs and to understand how commits and pushes are handled.
---

# Work with Git in Doglyad

Use this as the entry point for repository version-control conventions. This skill does not commit or push; use [git-push](../git-push/SKILL.md) to send changes.

## Repository facts

- Primary branch: `master`. Development happens directly on it unless a branch is explicitly requested.
- Remote: `origin`, GitHub repository `ivangalkindeveloper/DoglyadAI`.
- Use the `gh` CLI for pull requests, issues, releases, and other GitHub-side operations.

## Read-only commands

```bash
git status
git diff
git diff --staged
git log --oneline -20
git show <hash>
git branch
git rev-parse <ref>
git ls-files
```

## Mutating commands

Use deliberately:

```bash
git add <path>
git add -A
git commit -m "..."
```

Run `git push origin master` only through [git-push](../git-push/SKILL.md).

## Conventions

- Write short English commit subjects in imperative mood, capitalized, with no trailing period.
- When Claude Code authors a commit, append `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Run `make format` before committing.
- Never force-push without explicit permission. For a non-fast-forward rejection, rebase with `git pull --rebase origin master`, resolve conflicts, and retry.

## Protected files

When enabled and trusted by the agent, the shared security hook checks staging and commit commands for secrets and generated noise, including:

- `backend/main/secrets/`
- `backend/inference/secrets/`
- `ios/Config/`
- `ios/Firebase/`
- `ios/DoglyadNeuralModel/Resources/`
- `*.xcuserstate` and `xcschememanagement.plist`
- `*.pem`, `*.p8`, `*.p12`, `*.keystore`, `*.jks`, `id_rsa`, `secrets.*`, and `credentials.*`

If one is staged, run `git restore --staged <path>`.

## Related workflows

- Commit and push: [git-push](../git-push/SKILL.md)
- Build and test: [build-verify](../build-verify/SKILL.md)
- Pull requests and issues: `gh` CLI
