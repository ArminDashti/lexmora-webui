translator-webui/
├── src/views/                      # Page components
├── src/components/                 # Shared UI (layout, modal)
├── src/api/client.ts               # Fetch wrapper and types
├── src/router/                     # Vue Router
├── docs/                           # Frontend documentation
├── Dockerfile                      # Vue build + nginx image
├── docker-compose.yml              # web service
├── nginx.conf.template             # nginx /api proxy to Go API
├── .docker/stack.manifest.json     # Docker image tags and ports
├── package.json                    # npm dependencies and scripts
└── README.md                       # Setup and usage guide
