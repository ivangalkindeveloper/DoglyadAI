---
name: sync-harness
description: Synchronize Doglyad's shared harness into Codex and Claude settings and skills. Use after editing harness sources, after checkout, or when asked to refresh agent skills, hooks, or MCP configuration.
---

# Synchronize the project harness

`harness/` is the source of truth. Read `harness/README.md` for source and output
locations. Edit shared skills and hooks there; never edit generated copies.
Shared instructions live in `harness/instructions/`; the root `AGENTS.md` lists
the documents that both agents must read before starting work.

1. Inspect changes under `harness/` and run `python3 tools/sync_harness.py --dry-run`
   from the repository root.
2. Run `make sync-harness`. Existing authorization to update or synchronize the
   harness covers this command. If the execution sandbox protects `.codex/` or
   `.agents/`, request the tool's required filesystem escalation.
3. Run `make check-harness`. Report whether settings are current and name any
   files that could not be synchronized.

The synchronizer rejects manual changes to generated files before writing any
output. Inspect those changes and transfer intended shared edits to `harness/`.
Preserve personal settings in their agent-native local/user configuration.
Never delete the manifest or overwrite conflicting output to force a sync.

After changing the synchronizer or shared hooks, run their focused tests:

```bash
python3 -m unittest discover -s tools/tests -p 'test_harness*.py'
```

Synchronization does not install MCP packages, start services, run app builds or
model evaluations, or approve agent trust prompts. New hooks may require native
trust review; new MCP connections may require a restarted agent session.
Do not commit or push unless requested.
