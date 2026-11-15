---
name: update-infrastructure
description: Update all existing Doglyad backend services through the infrastructure deployment script, including main-development, main-production, and every inventoried inference VM. Use for fleet backend updates with builds, verification, and rollback. Use configure-vm for VM provisioning or repair.
---

# Update infrastructure

Use `deploy/update-infrastructure.sh` through Make; do not reproduce deployment logic manually.

1. Read AGENTS.md and the fleet update section of `deploy/README.md`.
2. Use the local, Git-ignored `deploy/secrets/infrastructure.json` as the single inventory. Never commit or publish it. Verify its SSH targets/model IDs and coverage of both main environments and every inference VM. Keep credentials outside it; ask only for unresolved values.
3. Review release compatibility and required migrations. The script handles backend image updates plus main Alembic migrations after a full backup and verified Yandex Disk publication with writers paused. Main setup must already be initialized with its database, gateway, workers and backup timers. Compose changes, secret synchronization, PostgreSQL/OS upgrades and vLLM/model replacement use configure-vm. Shared inference affects production immediately.
4. Ensure the intended release and the workflow's deployment_id input are pushed to the remote ref. Use [git-push](../git-push/SKILL.md) when publication is authorized. Never silently deploy older remote code instead of requested local changes.
5. Run `make check-infrastructure`. For an explicitly requested update of only both main environments, pass `INFRASTRUCTURE_SCOPE=main` to both check and update; this preserves main checks and skips inference availability/routes. Use [configure-vm](../configure-vm/SKILL.md) for VM readiness repairs.
6. State the targets/ref and run `make update-infrastructure`. Override `INFRASTRUCTURE_INVENTORY`, `INFRASTRUCTURE_REF`, and the documented scope when needed. An all-infrastructure request includes production; do not ask for redundant confirmation.
7. The script correlates its Actions build, pins amd64 digests, stages images, locks/snapshots all targets, updates inference then development then production, verifies containers/routes, and attempts reverse-order rollback on failure. Do not start a concurrent deployment.
8. Report the Actions URL, SHA, target results, and recovery locks. Follow the README recovery procedure; never clear locks without checking actual remote state and in-progress operations.

Main updates and rollbacks include API, report worker, payment gateway and subscription worker. PostgreSQL, Caddy, vLLM, weights, secrets, and system packages are preserved. If a database revision changed or a migration result is unknown, automatic old-image rollback is refused, writers stay stopped and recovery locks remain. Never downgrade or restore a live database automatically. Explain this scope if broader maintenance is intended. HTTP 401 checks establish reachability and App Check enforcement, not report generation; report that limitation. Never disable App Check or print secrets/patient data.

The entry point supports the full inventory and an explicit two-main scope. Other partial rollouts, historical-SHA deployments, and database recovery after schema changes is not automatic. Plan them explicitly instead of inventing flags. Initial VM provisioning can consume published images independently through configure-vm.
