---
name: update-infrastructure
description: Update all existing Doglyad backend services through the infrastructure deployment script, including main-development, main-production, and every inventoried inference VM. Use for fleet backend updates with builds, verification, and rollback. Use configure-vm for VM provisioning or repair.
---

# Update infrastructure

Use `deploy/update-infrastructure.sh` through Make; do not reproduce deployment logic manually.

1. Read AGENTS.md and the fleet update section of `deploy/README.md`.
2. Use the local, Git-ignored `deploy/secrets/infrastructure.json` as the single inventory. Never commit or publish it. Verify its SSH targets/model IDs and coverage of both main environments and every inference VM. Keep credentials outside it; ask only for unresolved values.
3. Review release compatibility and required migrations. The script handles compatible backend image updates, not Compose migrations, secret synchronization, OS upgrades, or vLLM/model replacement. Shared inference affects production immediately.
4. Ensure the intended release and the workflow's deployment_id input are pushed to the remote ref. Use [git-push](../git-push/SKILL.md) when publication is authorized. Never silently deploy older remote code instead of requested local changes.
5. Run `make check-infrastructure`. Use [configure-vm](../configure-vm/SKILL.md) for VM readiness repairs.
6. State the targets/ref and run `make update-infrastructure`. Override `INFRASTRUCTURE_INVENTORY` and `INFRASTRUCTURE_REF` when needed. An all-infrastructure request includes production; do not ask for redundant confirmation.
7. The script correlates its Actions build, pins amd64 digests, stages images, locks/snapshots all targets, updates inference then development then production, verifies containers/routes, and attempts reverse-order rollback on failure. Do not start a concurrent deployment.
8. Report the Actions URL, SHA, target results, and recovery locks. Follow the README recovery procedure; never clear locks without checking actual remote state and in-progress operations.

Caddy, vLLM, weights, secrets, and system packages are preserved. Explain this scope if broader maintenance is intended. HTTP 401 checks establish reachability and App Check enforcement, not report generation; report that limitation. Never disable App Check or print secrets/patient data.

Partial rollouts, historical-SHA deployments, and incompatible migrations are not supported by this entry point. Plan them explicitly instead of inventing flags. Initial VM provisioning can consume published images independently through configure-vm.
