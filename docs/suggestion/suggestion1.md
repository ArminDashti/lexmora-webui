# Suggestions

## Docker deploy env var alignment
Your `docker-compose.yml` uses `WEB_IMAGE_TAG` / `WEB_PUBLISH_PORT` env vars, while the generic Docker-deploy skill initially uses `IMAGE_TAG` / `PUBLISH_PORT`. The scripts in `.deploy/docker/` currently map YAML keys to the `WEB_*` env vars so overrides work with this repo.

Further improvement: add `publish_port` to `run-on-docker-server.yaml` (currently omitted) if you want remote deployments to bind a port other than the compose default (`8082`).
# History list has no pagination UI

The API supports `limit` / `offset` on `GET /api/v1/history`, but the web UI only sends sort params and loads the API default page. Once history grows, add pagination or infinite scroll.

**Effort:** small–medium
