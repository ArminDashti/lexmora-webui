# Docker deployment

Web UI nginx container from this repo. The API and PostgreSQL run separately from [translator-api](https://github.com/ArminDashti/translator-api).

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Vue build + nginx image |
| `docker-compose.yml` | `web` service on external `translator-net` |
| `nginx.conf.template` | Proxies `/api/` to the API container |
| `.docker/stack.manifest.json` | Image tags and ports |

## Service

| Service | Container | Host port | Notes |
|---------|-----------|-----------|-------|
| `web` | `translator-webui` | 8082 | Serves static UI; proxies `/api/*` → `${API_HOST}:${API_PORT}` |

## Local run

```bash
docker network create translator-net
# Start translator-api first, then:
docker compose up -d --build
```

Open [http://localhost:8082](http://localhost:8082).

| Variable | Default | Description |
|----------|---------|-------------|
| `API_HOST` | `translator-api` | API hostname on Docker network |
| `API_PORT` | `8080` | API port |
| `WEB_PUBLISH_PORT` | `8082` | Host port for the UI |
| `DOCKER_NETWORK` | `translator-net` | Shared network with the API stack |
