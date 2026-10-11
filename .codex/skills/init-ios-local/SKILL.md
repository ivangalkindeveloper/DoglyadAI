---
name: init-ios-local
description: Prepare the Doglyad iOS client for a local run by executing make init-ios-local. Use when asked to point the local client at the backend on the Mac or refresh its local network address.
---

# Prepare Doglyad iOS for a local run

Run from the Doglyad repository root. The existing Makefile target updates only
`BASE_URL` in `ios/Config/Config.Local.xcconfig` using the current IPv4 address
of `en0` and port `8000`.

1. Confirm that `ios/Config/Config.Local.xcconfig` exists and
   `ipconfig getifaddr en0` returns an IPv4 address. If either prerequisite is
   missing, report it instead of creating configuration or guessing an address.
2. Execute the repository command:

   ```bash
   make init-ios-local >/dev/null
   ```

   Suppress stdout because the target prints the entire configuration file.
   Keep stderr visible and report a nonzero exit status.
3. Verify that the file contains exactly one `BASE_URL` assignment using the
   detected address and port `8000`. Preserve the `.xcconfig` escaping generated
   by the target: `http:/$()/` resolves to `http://` in Xcode.
4. Report the resulting backend URL and the `Doglyad-Debug-Local` scheme to
   select in Xcode.

This command is the narrow exception permitted by `AGENTS.md` for local iOS
preparation. Preserve all other configuration values. Build the app or start
backend services only when the user also requests those actions.
