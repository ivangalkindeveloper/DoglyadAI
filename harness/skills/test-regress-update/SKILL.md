---
name: test-regress-update
description: Review Doglyad's current screens, presentation states, navigation and backend behavior, then update the short Maestro regression cases and screenshot inventory under test/. Use after product changes or when asked to refresh regression coverage.
---

# Update regression coverage

Read `test/README.md`, `test/COVERAGE.md`, `test/catalog.json` and `test/functional.json`. Compare the
recorded source hashes with current code using `python3 test/scripts/catalog.py --check`.
The catalog is evidence of the reviewed code, not proof of test execution.

- Inspect changed routes, screen/preview state definitions, view-model actions,
  repositories, backend endpoints and RU localization. Review the navigation
  into each screen and the result of each tested action. Keep cases short;
  share setup in `test/maestro/support/`. Use stable accessibility identifiers
  and actual UI text. Never invent a route, selector, successful outcome or
  platform implementation.
- Keep each module's cases in `test/modules/<Module>/`: authored `cases.yaml`
  with preparation, actions and expected results; executable `e2e/`; generated
  rendering-only `atlas/`. Follow the UI order within each feature. Keep data
  dependencies explicit in `functional.json`; do not place deletion cases at the
  end merely as incidental cleanup. Keep parser, transcriber, and model choices
  in the AI feature sequence. Check both changing a value and its persistence.
- Update functional YAML, the module's `cases.yaml`, and `test/functional.json` together. Maintain explicit
  ordering where a case depends on an earlier case's fixture. Each registered
  case must assert its expected behavior and capture its declared screenshots.
  Preserve tests for failures, retained data, retries and cancellation when those
  flows are changed. Record remaining coverage gaps in `test/README.md`.
- Use `automation.kind: maestro` only when linked flows cover every stated step.
  Use `mixed` when linked Maestro flows and named mandatory XCTest checks together
  cover every step. Each `nativeTests` entry must be registered in `test/scripts/native_checks.py`;
  previews alone still do not prove functional behavior.
  Use `partial` for incomplete automation and `manual` for fully specified cases
  that need a person or a missing fixture. State the exact remaining requirements.
  Cover Base/Pro/no access, permissions, validation, persistence, cancellation and
  error/retry paths where the owning module implements them. Do not count Preview
  screenshots as functional coverage or mark unavailable device features as passed.
- Run `python3 test/scripts/catalog.py` after reviewing the functional changes.
  Name module and component previews `"{number} {name}"` with consecutive numbers
  from 1 per module. Review the actual navigation and state transitions before
  assigning numbers; never use alphabetical state-class order. Full-module
  previews come first, components follow. Keep source declarations in that order.
  Maintain `functional.json.moduleOrder` for visual review; execution dependencies
  remain in the functional flow list. The catalog sorts by module order and numeric
  preview order, and keeps launch IDs independent of the numeric prefix.
  It refreshes offline Development responses using the backend response builders,
  and generates one-shot repository fault adapters from the actual protocols.
  Keep payment repositories real; Apple Sandbox is excluded until configured.
  Exercise YooKassa 3-D Secure with a new owner: the current backend rejects purchases
  while another subscription is active. Preserve this rejection case and bind pending
  and confirmation receipts to one order. Cover the unrelated-old-access guard in
  the mandatory Paywall ViewModel test without calling it a provider purchase.
  Keep recovery keys out of YAML, command arguments and published screenshots of active keys.
  Bind renewal/recovery checks to an actual test purchase and unchanged paid-period evidence.
  External mail/App Store adapters may replace only the unavailable external application;
  verify the exact outgoing URL and cancellation in a separate immutable receipt.
  Use the isolated worker control for generation errors and partial responses.
  Require observed terminal job states and local record-count evidence for retries;
  a retry button or screenshot alone does not prove successful recovery.
  Register only full-module Preview states: screens, bottom sheets and the application splash.
  Keep component-only Preview declarations in Xcode Canvas, including the shared catalogs in
  `ios/Doglyad/Application/Application/View/Preview/`, but exclude them from atlas YAML,
  regression execution and Figma publication. Do not add `sharedPreviewOrder` or component flows.
  It regenerates module-state YAML and `ios/Doglyad/Regression/RegressionScreens.swift` from
  named module previews, preserving stable IDs for unchanged names. It updates
  the source inventory and removes only obsolete generated atlas cases.
  Do not edit generated atlas YAML or Swift directly. If a new state lacks a
  preview, add a suitable DEBUG preview in its owning module first.
  Keep the visual collection Russian-only for now. English fixture documents
  remain available to localization unit tests; do not add English `#Preview` entries.
- Run `python3 test/scripts/scenario_coverage.py` to refresh module indexes and the coverage
  table. Its callback mapping is a completeness aid, not a code coverage metric.
- Run `make regression-check`, the focused checks in `test/checks/`, and compile
  the regression iOS configuration if generated Swift or app integration changed.
  See the exact build command in the README. Do not run GPU, speech-quality or
  external payment suites as an incidental check.
- Report added/changed cases, uncovered behavior and verification limits.
  Updating cases does not create a successful run or authorize replacing Figma
  images. Use `test-regress-run` for execution and publication. After changes to
  shared skills, run `make sync-harness` and `make check-harness`.

- For saved reports, verify the exact copied response version against the local database.
  Regeneration must retain examination data, photos and earlier model responses.
  Bind `reportAssertions` to immutable report evidence before publication.
