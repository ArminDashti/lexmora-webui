lexmora-webui/
├── public/
│   ├── apple-touch-icon.png        # iOS home-screen icon
│   ├── favicon.ico                 # Legacy browser favicon
│   ├── favicon.svg                 # Primary browser favicon
│   ├── pwa-192x192.png             # PWA install icon (small)
│   └── pwa-512x512.png             # PWA install icon (large)
├── src/
│   ├── api/
│   │   └── client.ts              # Fetch wrapper, auth helpers, API types
│   ├── components/
│   │   ├── AppLayout.vue          # Shell nav and logout
│   │   └── HistoryModal.vue       # History row detail modal
│   ├── router/
│   │   └── index.ts               # Routes and auth guard
│   ├── views/
│   │   ├── HistoryView.vue        # Sortable history table
│   │   ├── InstructionsView.vue   # Edit AI instruction prompts
│   │   ├── LoginView.vue          # Login form
│   │   ├── SettingsView.vue       # OpenRouter settings / clear data
│   │   ├── StatsView.vue          # Usage stats by period
│   │   └── TransformView.vue      # Transform operations UI
│   ├── App.vue                    # Root component
│   ├── main.ts                    # App bootstrap
│   ├── style.css                  # Tailwind and shared styles
│   └── vite-env.d.ts              # Vite type shims
├── docs/
│   ├── description.md             # Project overview
│   ├── dir-tree.md                # This tree
│   ├── endpoints.md               # API contract used by the UI
│   ├── modules/
│   │   ├── docker.md              # Docker / nginx notes
│   │   └── frontend.md            # Frontend module notes
│   ├── suggestion/
│   │   └── suggestion1.md         # Improvement ideas
│   └── potentional-bugs/
│       ├── red.md                 # Critical risks
│       └── yellow.md              # Minor risks
├── .docker/
│   └── stack.manifest.json        # Docker image tags and ports
├── create-image.ps1               # Build Docker image
├── run-on-docker-local.ps1        # Local Docker deploy
├── run-on-docker-server.ps1       # Remote Docker deploy over SSH
├── Dockerfile                     # Vue build + nginx image
├── docker-compose.yml             # web service
├── nginx.conf.template            # nginx /api proxy + SW cache headers
├── package.json                   # npm dependencies and scripts
├── vite.config.ts                 # Vite config, proxy, and PWA plugin
└── README.md                      # Setup and usage guide
