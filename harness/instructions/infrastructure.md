# Doglyad infrastructure rules

### Environments

`ENVIRONMENT` (`development` or `production`) selects a directory under `backend/main/config/` and the matching Robokassa test/live mode. The application reads the same documents from this backend instead of the repository. Otherwise, pushing a new model to `master` could expose it to the app before the backend deployment knows about it, causing a physician to receive `400`. With the default `MODEL_SERVICE_TYPE=inference`, both environments use the same inference route and token validation. A development-staging check is meaningful because it exercises the same code and path; the configuration documents and Robokassa payment mode differ.

`MODEL_SERVICE_TYPE` selects the main backend's generation implementation independently of `ENVIRONMENT`: `inference` calls GPU VMs, while `mock` returns local RU/EN fixtures. VS Code's `Backend: Local Mock` profile selects `mock` with development configuration. App Check, configuration, localization, request validation, and SMTP remain real. Mock generation does not require an inference endpoint map; see [`backend/main/README.md`](../../backend/main/README.md).

### Timeouts

Timeouts are strictly nested from outside to inside, with each wrapper wider than the operation it contains:

```text
iOS client                    300  application.json -> network.timeoutIntervalForRequest
main server.json operation    130  main backend waits for the GPU VM
inference server.json         120  queue waiting and local engine request
```

An inner timeout must be shorter than its outer timeout; otherwise the caller can terminate the connection while the wrapped generation is still running.

With `MODEL_SERVICE_TYPE=inference`, every published model must have an entry in `backend/main/secrets/inference_endpoints.json` containing the URL of its GPU VM. A missing mapping is a configuration error.
