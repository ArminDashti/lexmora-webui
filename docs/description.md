# Lexmora Web UI



Vue 3 SPA for the Lexmora app. Dark-themed UI for login, transforms (including compare), history, editable AI instructions, usage stats, and OpenRouter settings. The app now includes installable PWA support with a service worker that precaches the UI shell and static assets.



The Go API and PostgreSQL live in the separate [lexmora-api](https://github.com/ArminDashti/lexmora-api) repository.



## Tech stack



- Vue 3 + TypeScript + Tailwind CSS

- Vite 6 dev server with `/api` proxy

- `vite-plugin-pwa` for manifest generation and service worker

- nginx in Docker for production (proxies `/api` to the API container)

- PWA icons and metadata in `public/`



## Run



### Development



1. Start the API from `lexmora-api` on port 8080

2. `npm install && npm run dev` → http://localhost:5173



### Docker



```powershell

# Start lexmora-api on lexmora-net first, then:

.\run-on-docker-local.ps1

# or remote:

.\run-on-docker-server.ps1 --ssh-string=<alias>

```



Web UI URL is printed by the script (host port defaults to a free port in `30000-32767`).



Default login: `armin` / `Translator@2024` (validated by the API)



## PWA behavior



- Installable in supported browsers (best on HTTPS in production)

- Offline behavior is app-shell only (cached UI and static files)

- API requests (`/api/*`) are network-only and are not cached

