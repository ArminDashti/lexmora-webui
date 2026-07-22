# Edge Cases / Risks (Yellow)

## Port binding override
Remote/local scripts do not currently set `WEB_PUBLISH_PORT` based on YAML keys unless you add `publish_port` to `run-on-docker-server.yaml`. Without it, `docker-compose.yml` will use its default `${WEB_PUBLISH_PORT-8082}`.
# Minor risks / code smells

- **[Auth]** Client only checks token presence in localStorage; expired JWTs still pass the router guard until the next API call returns 401.
- **[Stats]** If an older API without `compare` in `StatsBucket` is used, the Compare column shows `undefined`.
