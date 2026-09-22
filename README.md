# Cyment Infrastructure

[![CI/CD](https://github.com/acyment/cyment-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/acyment/cyment-infra/actions/workflows/ci.yml)

Docker Compose setup for running multiple services on VPS B with Caddy reverse proxy and automatic HTTPS.

## Services

| Service | Description | URL |
|---------|-------------|-----|
| **Caddy** | Reverse proxy with automatic HTTPS | - |
| **Tempi Timer** | Static Svelte timer app | https://timer.cyment.com |
| **BackIn15** | Session sharing web app | https://backin15.app |
| **Fichus Feria** | Ephemeral nearby sticker-trade matching API | https://feria.fichusapp.com |
| **Fichus Mi red de canjes** | Durable private-network matching backend (see `../fichus/docs/private-network-contract-gate.md`) | https://network.fichusapp.com |
| **Feliche Site** | Static landing, privacy, and support pages | https://feliche.cyment.com |
| **Bitzi Site** | Static landing, privacy, and support pages | https://bitzi.cyment.com |
| **Twenty CRM** | Self-hosted CRM (server + worker + Postgres + Redis) | https://crm.cyment.com |
| **CrowdTimer** | Zoom timer app + PocketBase realtime backend | https://live.crowdtimer.app |

## Quick Start

```bash
# Setup (one-time)
./scripts/setup.sh

# Local development
./scripts/deploy.sh local

# Production deployment
./scripts/deploy.sh production
```

## Prerequisites

- Docker 24.0+
- Docker Compose 2.20+
- Git
- Sibling repositories:
  - `../Tempi.app` - Tempi Timer source
  - `../backin15` - BackIn15 source
  - `../fichus` - Fichus source, including `backend/feria`
  - `../CrowdTimer` - CrowdTimer source at the revision pinned in `deploy/versions.env`

## Setup

### 1. Clone and Prepare

```bash
git clone <this-repo> cyment-infra
cd cyment-infra

# Clone sibling repositories
git clone <tempi-repo-url> ../Tempi.app
git clone <backin15-repo-url> ../backin15
git clone <fichus-repo-url> ../fichus
```

### 2. Configure Environment

```bash
# Copy environment file
cp .env.example .env

# Edit with your values
nano .env
```

### 3. Validate Setup

```bash
./scripts/test.sh
```

### 4. Deploy

```bash
# Local development
./scripts/deploy.sh local

# Production
./scripts/deploy.sh production
```

## DNS Configuration

Ensure these A records point to your VPS IP:

- `timer.cyment.com`
- `feliche.cyment.com`
- `bitzi.cyment.com`
- `backin15.app`
- `www.backin15.app` → redirects to `backin15.app`
- `feria.fichusapp.com`
- `network.fichusapp.com`
- `crm.cyment.com`
- `crowdtimer.app`
- `live.crowdtimer.app`
- `pb.crowdtimer.app`

`pb-admin.crowdtimer.app` is created by its Cloudflare Tunnel route rather than
as an A record to this VPS.

## Services

### Tempi Timer

- **URL**: https://timer.cyment.com
- **Build Context**: `../Tempi.app`
- **Tech Stack**: Svelte + Bun

**Deployment:**
```bash
docker compose up -d --build tempi-app caddy
```

### BackIn15 Web App

- **URL**: https://backin15.app
- **Build Context**: `../backin15/apps/backin15_web`
- **Tech Stack**: SvelteKit + Docker

**Configuration (in `.env`):**
- `BACKIN15_VITE_APTABASE_APP_KEY` - Analytics key
- `BACKIN15_VITE_SENTRY_DSN` - Error tracking
- `BACKIN15_VITE_APP_VERSION` - App version
- `BACKIN15_VITE_*` - Other build arguments

**Deployment:**
```bash
docker compose up -d --build backin15-app caddy
```

### Fichus Feria API

- **URL**: https://feria.fichusapp.com
- **Build Context**: `../fichus/backend/feria`
- **Tech Stack**: Bun + TypeScript
- **Health**: `GET /healthz`

**Configuration (in `.env`, all optional):**
- `FERIA_SESSION_TTL_MS`
- `FERIA_INVITE_TTL_MS`
- `FERIA_COORDINATION_TTL_MS`
- `FERIA_K_ANON_MIN`
- `FERIA_MATCH_THRESHOLD`
- `FERIA_SYNC_RATE_MS`
- `FERIA_GEOHASH_PRECISION`

**Deployment:**
```bash
docker compose up -d --build fichus-feria caddy
```

### Fichus Mi red de canjes backend

- **URL**: https://network.fichusapp.com
- **Build Context**: `../fichus/backend/network`
- **Tech Stack**: Bun + TypeScript + PostgreSQL (`network-db`, separate from every
  other database in this file)
- **Health**: `GET /healthz`
- **Release contract**: `../fichus/docs/private-network-contract-gate.md` — the
  mobile apps' `networkEnabled` flag defaults OFF regardless of this backend
  being reachable; this service alone does not make the feature live for real
  users.

**Configuration (in `.env`):**
- `NETWORK_DB_PASSWORD` - required
- `NETWORK_SERVER_SECRET` - required, 32+ chars (`openssl rand -base64 32`)
- `NETWORK_BETA_OPEN` - keep `false` outside a deliberately scoped rehearsal/beta
  window (see the contract gate's monetization row)

**Deployment:**
```bash
docker compose up -d --build network-db fichus-network caddy
```

### Feliche Static Site

- **URL**: https://feliche.cyment.com
- **Content root**: `./sites/feliche`
- **Pages**:
  - `/` landing page
  - `/privacy/` public privacy policy
  - `/support/` support page

**Deployment:**
```bash
docker compose up -d --force-recreate caddy
```

### Bitzi Static Site

- **URL**: https://bitzi.cyment.com
- **Content root**: `./sites/bitzi`
- **Pages**:
  - `/` landing page
  - `/privacy/` public privacy policy
  - `/support/` support page

**Deployment:**
```bash
docker compose up -d --force-recreate caddy
```

### Twenty CRM

- **URL**: https://crm.cyment.com
- **Image**: `twentycrm/twenty:${TWENTY_TAG:-latest}` (server + worker), `postgres:16`, `redis:8-alpine`
- **Storage**: local volume (`twenty_server_data`); no S3 configured

**Configuration (in `.env`):**
- `TWENTY_DB_PASSWORD` - required
- `TWENTY_APP_SECRET` - required (`openssl rand -base64 32`)
- `TWENTY_ENCRYPTION_KEY` - required (`openssl rand -base64 32`)
- `TWENTY_TAG` - optional, pin to a specific release instead of `:latest`

**Deployment:**
```bash
docker compose up -d --build twenty-db twenty-redis twenty-server twenty-worker caddy
```

### CrowdTimer

- **App**: https://live.crowdtimer.app
- **Marketing**: https://crowdtimer.app
- **Public PocketBase API/realtime**: https://pb.crowdtimer.app
- **Protected PocketBase admin**: https://pb-admin.crowdtimer.app
- **Build context**: `../CrowdTimer`, checked out at `CROWDTIMER_REF` from `deploy/versions.env`

CrowdTimer uses the shared Caddy and `web` network. Its admin hostname is not
routed by Caddy: `crowdtimer-cloudflared` publishes PocketBase through a named
Cloudflare Tunnel protected by Access.

Production configuration is supplied by the protected GitHub environment:

- `CROWDTIMER_ENV` — the complete contents matching `.env.crowdtimer.example`
- `CROWDTIMER_TUNNEL_TOKEN` — the remotely managed tunnel token

To promote a release, update `CROWDTIMER_REF` to a full green CrowdTimer commit,
merge that change, then manually run the `CI/CD Pipeline` workflow with
`deploy_production=true` on `master`.

The one-time tunnel/Access setup, first DNS cutover, and 24-hour rollback plan
are documented in [CROWDTIMER_DEPLOYMENT.md](CROWDTIMER_DEPLOYMENT.md).

## Development

### Local Development

```bash
# Start local services
docker compose -f docker-compose.local.yml up -d

# Access services
# - http://localhost:8080 - Feliche landing page
# - http://localhost:5002 - BackIn15
# - http://localhost:8787/healthz - Fichus Feria API
```

### Testing

```bash
# Run all tests
./scripts/test.sh

# Specific tests
docker compose -f docker-compose.yml config  # Validate config
docker compose ps                           # Check status
docker compose logs -f                      # View logs
```

### Backup

```bash
# Backup Caddy data, Botini media, Botini Postgres, and Umami Postgres
./scripts/backup.sh
```

## Project Structure

```
cyment-infra/
├── docker-compose.yml          # Production services
├── docker-compose.local.yml    # Local development
├── Caddyfile                   # Production reverse proxy
├── Caddyfile.local            # Local reverse proxy
├── .env.example               # Environment template
├── scripts/                   # Automation scripts
│   ├── setup.sh              # Initial setup
│   ├── deploy.sh             # Deploy services
│   ├── test.sh               # Run tests
│   └── backup.sh             # Backup production state
├── .github/workflows/         # CI/CD
│   └── ci.yml                # GitHub Actions
└── packages/
    └── tempi/
        └── Dockerfile         # Tempi app build
```

## Health Checks

All services include health checks:

```bash
# View health status
docker compose ps

# Check specific service
docker compose exec caddy wget -qO- http://localhost:80
docker compose exec backin15-app wget -qO- http://localhost:80/
docker compose exec fichus-feria bun --eval "fetch('http://127.0.0.1:8787/healthz').then(r => console.log(r.status))"
```

## Troubleshooting

### Services not starting

```bash
# Check logs
docker compose logs

# Validate configuration
docker compose config

# Restart with rebuild
docker compose up -d --build
```

### SSL Certificate Issues

```bash
# View Caddy logs
docker compose logs caddy

# Check certificate status
docker compose exec caddy caddy list-modules

# Force certificate renewal (be careful with rate limits)
docker compose restart caddy
```

### Build Failures

```bash
# Check sibling repositories exist
ls -la ../Tempi.app
ls -la ../backin15
ls -la ../fichus/backend/feria

# Clean build
docker compose down -v
docker compose build --no-cache
```

## Security

- Environment variables in `.env` (not committed)
- Automatic HTTPS via Caddy
- Health checks on all services
- Regular backups recommended

## CI/CD

GitHub Actions workflow:
- Validates Docker Compose files
- Runs smoke tests
- Checks for secrets in code
- Verifies build process

### Production Deployment

Pushes and pull requests validate configuration and run smoke tests but never
mutate production. To deploy, manually run the `CI/CD Pipeline` workflow on
`main`/`master` with `deploy_production=true`. The protected production
environment can require reviewer approval before the SSH deployment begins.

**Required GitHub Secrets:**

| Secret | Description |
|--------|-------------|
| `VPS_HOST` | VPS IP address or hostname |
| `VPS_USER` | SSH username |
| `VPS_SSH_KEY` | Private SSH key for authentication |
| `VPS_PATH` | Absolute path to cyment-infra on VPS (e.g., `/home/user/cyment-infra`) |
| `CROWDTIMER_ENV` | Multiline CrowdTimer production environment file |
| `CROWDTIMER_TUNNEL_TOKEN` | Token for the Access-protected PocketBase admin tunnel |

**Setup:**
1. Generate SSH key pair: `ssh-keygen -t ed25519 -C "github-actions" -f github-actions`
2. Add public key to VPS: `cat github-actions.pub >> ~/.ssh/authorized_keys`
3. Add private key to GitHub repository secrets as `VPS_SSH_KEY`
4. Add other secrets (`VPS_HOST`, `VPS_USER`, `VPS_PATH`)
5. Create GitHub environment named "production" for deployment protection rules

**Deployment Flow:**
- Pulls the selected `main`/`master` infrastructure revision
- Updates branch-tracked sibling repositories
- Checks out CrowdTimer at its exact committed revision pin
- Atomically stages CrowdTimer secrets from the protected GitHub environment
- Runs `./scripts/deploy.sh production`
- Shows service status

**Manual Deployment:**
```bash
# On VPS
./scripts/deploy.sh production
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed setup instructions.

## Adding New Services

1. Add service to `docker-compose.yml`
2. Add reverse proxy rule to `Caddyfile`
3. Update DNS records
4. Add health check
5. Update documentation

## Contributing

1. Create a feature branch
2. Make changes
3. Run tests: `./scripts/test.sh`
4. Submit pull request

## License

Private - Cyment Infrastructure
