# Doglyad — agent instructions

This is the shared instruction entry point for Codex and Claude.

Before starting any task, read all seven documents below in full, in this order.
All seven documents apply to every task. They contain the project rules previously
kept in this file.

1. [Common rules](harness/instructions/common.md) — communication, product goals, shared code style, localization and constraints.
2. [Architecture](harness/instructions/architecture.md) — services, billing and code map.
3. [Backend](harness/instructions/backend.md) — Python, FastAPI, models and backend conventions.
4. [iOS](harness/instructions/ios.md) — Swift, MVVM, state, views and previews.
5. [Design](harness/instructions/design.md) — content, buttons, loading, errors and retry actions.
6. [Infrastructure](harness/instructions/infrastructure.md) — environments, inference routing and timeout relationships.
7. [Workflow](harness/instructions/workflow.md) — harness, verification, regression and project commands.

If a tool truncates a document, read the remaining parts before doing task work.
Reuse complete reads within the same session. After context compaction, read any
required document whose full instructions are no longer available.

Resolve paths written in code spans and run commands from the repository root.
Markdown links are relative to the document that contains them.

Maintain shared instructions in `harness/instructions/`. Keep this entry point
short and keep the complete reading list here. Generated `CLAUDE.md` imports this
file through `@AGENTS.md`. See [the harness guide](harness/README.md).
