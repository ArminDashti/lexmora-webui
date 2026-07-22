# Module 1: Docker Deploy Assets

## Responsibility
Contains YAML-only deployment scripts and config for running the web UI with Docker Compose.

## Key scripts
- `.deploy/docker/run-on-docker-local.ps1`
- `.deploy/docker/run-on-docker-server.ps1`

## Key configs
- `.deploy/docker/run-on-docker-local.yaml`
- `.deploy/docker/run-on-docker-server.yaml`

## Dependencies / assumptions
- `docker-compose.yml` expects overrides via `WEB_IMAGE_TAG` and `DOCKER_NETWORK`.
- `docker-compose.yml` publishes via `WEB_PUBLISH_PORT` (defaults to `8082`).
