---
name: test-regress-run
description: Run Doglyad's complete clean-environment iOS regression and update its screen collection in Figma only after every case passes. Use when asked to run the mobile regression or refresh Figma screenshots from a successful regression.
---

# Run regression and update Figma

Read `test/README.md`. Testing resources and results belong in `test/`; shared
skill sources belong in `harness/skills/`. Android has no implementation yet.
Read `test/COVERAGE.md` before execution. Module specifications marked `partial`
or `manual` prevent full-regression publication. Do not change these labels to
make publication pass. A local run can execute the implemented Maestro subset,
but an incomplete module matrix is reported as `incomplete` and cannot update Figma.

1. Run `make regression-check` and `make regression-doctor`. Read the configured
   Figma target from ignored `test/local.json`; never print Firebase credentials
   or the App Check debug token. If the source inventory is stale, use
   `test-regress-update` before starting a new run.
2. Run `make regression-figma`. It creates its own Compose project, PostgreSQL
   volume and iOS simulator. Do not substitute the developer's database, simulator
   or a production backend. App Check remains enabled. Inference uses existing
   mock generation; the ledger subscription is synthetic test data.
3. Follow the process log. The runner fails closed on an unsuccessful or skipped
   case, timeout, missing screenshot, changed source, or cleanup failure. Inspect
   the named run's logs to diagnose failure. Do not weaken assertions, edit a
   result file or publish a subset to obtain a green result.
4. After all cases pass, the command exposes that run to the Figma plugin on
   loopback and prints a temporary connection token. Open the configured Figma
   file and its Doglyad Regression development plugin. With supported computer
   tools, enter the temporary token and run the import; the requested skill
   includes authorization to update the plugin-managed screen collection.
   Initial plugin installation is described in `test/README.md` and needs the
   user's Figma account. If editor control is unavailable, keep the successful
   artifacts and give the user the connection step. Do not claim publication.
5. Confirm `figma-receipt.json` exists for this exact run. Report the run result,
   case/screenshot counts, the HTML report path and Figma node URL. A timeout
   waiting for Figma does not require repeating the tests: use
   `make regression-publish RUN=test/runs/<run-id>` for this same successful run.

The atlas checks rendering of named preview states. Functional flows check real
navigation, persistence and local-backend behavior. Neither proves payment
provider integration, physical camera/microphone operation or model quality;
those boundaries are listed in `test/README.md`. Do not run the long voice/model
evaluations as part of this skill. Do not commit or push unless requested.
