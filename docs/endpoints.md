# Endpoints / Commands

## Docker deploy scripts

Entry point: `.armin/docker-scripts/` (YAML-only; no CLI flags).

| Command | Auth | Description |
|---------|------|-------------|
| `.\.armin\docker-scripts\run-on-docker-local.ps1` | No | Local deploy: build, force-recreate on `t3-net`, publish `publish_port` |
| `.\.armin\docker-scripts\run-on-docker-server.ps1` | SSH (`t3`) | Remote deploy to Irancell-T3; YAML has `ssh: "ssh t3"` + `volume_dir` |
| `.\create-image.ps1` | No | Build `lexmora-webui` image only |

# API Endpoints

Consumed from [lexmora-api](https://github.com/ArminDashti/lexmora-api). All authenticated routes require `Authorization: Bearer <jwt>`.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/health` | No | Health check (not called by UI) |
| POST | `/api/v1/auth/login` | No | Login with username/password, returns JWT |
| POST | `/api/v1/transform` | Yes | Run a transform operation |
| GET | `/api/v1/history` | Yes | List history (`sort_by`, `sort_order`, `limit`, `offset`) |
| GET | `/api/v1/history/:id` | Yes | Get single history record |
| DELETE | `/api/v1/history/:id` | Yes | Delete history record |
| GET | `/api/v1/stats` | Yes | Request counts by period and type |
| GET | `/api/v1/instructions` | Yes | List all instruction keys |
| GET | `/api/v1/instructions/:key` | Yes | Get instruction content |
| PUT | `/api/v1/instructions/:key` | Yes | Update instruction content |
| GET | `/api/v1/settings` | Yes | Get OpenRouter token and model |
| PATCH | `/api/v1/settings` | Yes | Update OpenRouter token and/or model |
| DELETE | `/api/v1/settings/data` | Yes | Delete all history rows |

## Transform — `POST /api/v1/transform`

### Full request body shape

```json
{
  "operation": "translate|simplify|term|refine|symptoms|compare",
  "text": "...",
  "text1": "...",
  "text2": "...",
  "direction": "en-fa|fa-en",
  "mode": "general|movie|formal|scientific|music",
  "movie_name": "...",
  "language": "en|fa",
  "style": "everyday|formal|slang"
}
```

Only include fields relevant to the selected operation.

### Operations

| Operation | Required fields | History type |
|-----------|-----------------|--------------|
| `translate` | `text`, `direction`, `mode` (+ `movie_name` if mode is `movie`) | `en_fa` / `fa_en` |
| `simplify` | `text` | `simplify` |
| `term` | `text`, `language`, `style` | `term_en` / `term_fa` |
| `refine` | `text`, `style` | `refine` |
| `symptoms` | `text` | `symptoms` |
| `compare` | `text1`, `text2`, `language` | `compare_en` / `compare_fa` |

### Compare

Compare two words or phrases. Do not send `text`.

```json
{
  "operation": "compare",
  "text1": "ask",
  "text2": "request",
  "language": "en"
}
```

- `language`: explanation language (`en` or `fa`)
- History `input_text` is stored as `"ask vs request"`
- Instruction keys: `compare-en`, `compare-fa`

### Stats

`StatsBucket` includes: `simplify`, `en_fa`, `fa_en`, `term`, `refine`, `symptoms`, `compare`, `total`.
