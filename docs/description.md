# Translator Web UI

Vue 3 SPA for the Translator app. Dark-themed UI for login, transforms, history, editable AI instructions, usage stats, and OpenRouter settings.

The Go API and PostgreSQL live in the separate [translator-api](https://github.com/ArminDashti/translator-api) repository.

## Tech stack

- Vue 3 + TypeScript + Tailwind CSS
- Vite dev server with `/api` proxy
- nginx in Docker for production (proxies `/api` to the API container)

## Run

### Development

1. Start the API from `translator-api` on port 8080
2. `npm install && npm run dev` → http://localhost:5173

### Docker

```bash
docker network create translator-net
# Start translator-api first, then:
docker compose up -d --build
```

Web UI: http://localhost:8082

Default login: `armin` / `Translator@2024` (validated by the API)
