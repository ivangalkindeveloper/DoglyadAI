---
name: test-regress-run
description: Run Doglyad's complete clean-environment iOS regression and update its screen collection in Figma only after every case passes. Use when asked to run the mobile regression or refresh Figma screenshots from a successful regression.
---

# Run regression and update Figma

Read `test/README.md`. Cases and orchestration belong in `test/`; results belong
in `build/regression/runs/`. iOS support lives in `ios/Doglyad/Regression/`, with
native tests in the existing iOS test targets. Shared skill sources belong in
`harness/skills/`. Android has no implementation yet.
Read `test/COVERAGE.md` before execution. Module specifications marked `partial`
or `manual` remain coverage gaps; never mark them passed just to publish.
Publication requires every registered executable case and expected screenshot
to pass, unchanged run artifacts and successful environment cleanup. Coverage
gaps remain visible in the report and Figma collection, but do not block an
otherwise successful execution. Preview screenshots do not prove missing E2E behavior.

## Explicit Preview-only requests

When the user asks to update only Preview and excludes full regression, run
`make previews-figma` after refreshing the catalog with `test-regress-update`.
This separate command renders every registered Russian full-module Preview on isolated iOS
simulators. It does not start backend services, a database, functional flows or
provider purchases. It writes `preview-report.json` under `build/previews/runs/`.
Require every Preview, its screenshots, unchanged evidence and simulator cleanup
to pass before importing. Component-only previews are excluded, including shared application views; keep them in Xcode Canvas. The plugin replaces only the Preview section and
preserves regression screenshots and unrelated page content. This result is a
Preview capture, never a passed functional regression. Reuse a successful capture
with `make previews-publish RUN=build/previews/runs/<run-id>` if transfer needs retry.

## Full regression requests

1. Run `make regression-check` and `make regression-doctor`. Read the configured
   Figma target from ignored `test/secrets/config.local.json`; never print Firebase credentials
   or the App Check debug token. If the source inventory is stale, use
   `test-regress-update` before starting a new run.
2. For a new run, execute `make regression-figma`. It creates its own Compose project, PostgreSQL
   volume and iOS simulator. Do not substitute the developer's database, simulator
   or a production backend. App Check remains enabled. Inference uses existing
   mock generation. Ordinary UI cases use synthetic ledger profiles. Robokassa
   browser cases require fresh owners, a verified test merchant and a public ResultURL.
   Test payments require verified signed ResultURL evidence for the selected product;
   OpStateExt is production-only. Never replace payment evidence with SQL access.
   Keep browser/bank cases manual until their selectors and callbacks are verified.
   Pending, application restart and confirmation retain the same payment identity until provider-confirmed cancellation or expiry. Plan changes create a paid successor that starts after the current paid period, with one future renewal schedule. Apple Sandbox is currently excluded. When asked
   to upload an existing successful run, reuse it with
   `make regression-publish RUN=build/regression/runs/<run-id>` instead of rerunning tests.
3. Follow the process log. The runner fails closed on an unsuccessful or skipped
   case, timeout, missing screenshot, changed source, or cleanup failure. The exact
   XCTest checks in `test/scripts/native_checks.py` run before Maestro; zero or skipped
   tests cannot pass. SMTP cases require accepted/rejected-message evidence,
   authenticated STARTTLS and report contents matching the simulator clipboard.
   Cases with `backendAssertions` additionally require observed HTTP request fields,
   the expected terminal PostgreSQL job states and, where specified, received report sections.
   Worker-fault cases must bind the one-shot control receipt to the observed job;
   retries need distinct request IDs and the specified local report count change.
   Subscription action receipts must preserve the paid period and payment count;
   recovery must reject an invalid key and authorize the clean client with the same permanent key through the real backend.
   External application adapters require exact URL evidence and observed cancellation.
   They never replace payment providers or SMTP delivery.
   Saved response cases require immutable `report-evidence.json`: exact clipboard/version
   equality, unchanged examination/photos and preservation of earlier response versions.
   All of these receipts must remain unchanged before publication. Inspect
   the named run's logs to diagnose failure. Do not weaken assertions, edit a
   result file or publish a subset to obtain a green result.
4. After all cases pass, the command exposes that run to the Figma plugin on
   loopback. An open Doglyad AI Regression development plugin imports automatically.
   Its persistent local authentication key is generated in ignored `test/secrets/`
   and bundled only into ignored `test/cache/figma-plugin/ui.html`; never print it.
   The requested skill includes authorization to replace all content on the
   designated regression page. After every image is validated, the plugin clears
   that page, including manual additions, before showing the new collection.
   Other pages remain unchanged; failed tests or incomplete transfers do not clear it.
   Initial plugin installation is described in `test/README.md` and needs the
   user's Figma account. Import `test/cache/figma-plugin/manifest.json`; the bridge
   refreshes this local copy from `test/figma/` and preserves its configured ID.
   After plugin code changes, its window must be restarted once. When the editor
   or plugin is closed and editor control is unavailable or declined, keep the
   successful artifacts and explain that the user must open the plugin. Do not
   bypass that preference or claim publication without a receipt.
5. Confirm `figma-receipt.json` exists for this exact run. Report the run result,
   case/screenshot counts, the HTML report path and Figma node URL. A timeout
   waiting for Figma does not require repeating the tests: use
   `make regression-publish RUN=build/regression/runs/<run-id>` for this same successful run.

The atlas checks rendering of named preview states. Functional flows check real
navigation, persistence and local-backend behavior. Robokassa browser cases need
verified signed test ResultURL evidence before they can count as provider coverage. Neither proves
Apple Sandbox, live payments, physical camera/microphone operation or model quality;
those boundaries are listed in `test/README.md`. Do not run the long voice/model
evaluations as part of this skill. Do not commit or push unless requested.
