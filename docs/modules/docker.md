# Docker deployment

Web UI nginx container from this repo. The API and PostgreSQL run separately from [lexmora-api](https://github.com/ArminDashti/lexmora-api).

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Vue build + nginx image |
| `docker-compose.yml` | `web` service on external `lexmora-net` |
| `nginx.conf.template` | Proxies `/api/` to the API container |
| `.docker/stack.manifest.json` | Image tags and ports |
| `create-image.ps1` | Build `lexmora-webui` image |
| `run-on-docker-local.ps1` | Local Docker deploy |
| `run-on-docker-server.ps1` | Remote deploy over SSH |

## Service

| Service | Container | Host port | Notes |
|---------|-----------|-----------|-------|
| `web` | `lexmora-webui` | random `30000-32767` (or `--internal-port`) | Serves static UI; proxies `/api/*` → `${API_HOST}:${API_PORT}` |

## Local run

```powershell
.\run-on-docker-local.ps1
.\run-on-docker-local.ps1 --internal-port=30042
.\run-on-docker-server.ps1 --ssh-string=<alias>
.\create-image.ps1 --help
```

API stack must be on `lexmora-net` first. Scripts create the network if missing.

| Variable | Default | Description |
|----------|---------|-------------|
| `API_HOST` | `lexmora-api` | API hostname on Docker network |
| `API_PORT` | `8080` | API port |
| `WEB_PUBLISH_PORT` | from `--internal-port` or random | Host port for the UI |
| `DOCKER_NETWORK` | `lexmora-net` | Shared network with the API stack |
