# Cyment Infrastructure

[![CI/CD](https://github.com/acyment/cyment-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/acyment/cyment-infra/actions/workflows/ci.yml)

Docker Compose setup for running multiple services on VPS B with Caddy reverse proxy and automatic HTTPS.

## Services

| Service | Description | URL |
|---------|-------------|-----|
| **Caddy** | Reverse proxy with automatic HTTPS | - |
| **Tempi Timer** | Static Svelte timer app | https://timer.cyment.com |
| **BackIn15** | Session sharing web app | https://backin15.app |

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

## Setup

### 1. Clone and Prepare

```bash
git clone <this-repo> cyment-infra
cd cyment-infra

# Clone sibling repositories
git clone <tempi-repo-url> ../Tempi.app
git clone <backin15-repo-url> ../backin15
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
- `backin15.app`
- `www.backin15.app` → redirects to `backin15.app`

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

## Development

### Local Development

```bash
# Start local services
docker compose -f docker-compose.local.yml up -d

# Access services
# - http://localhost:8080 - Landing page
# - http://localhost:5002 - BackIn15
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
# Backup Caddy certificates and config
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
│   └── backup.sh             # Backup Caddy data
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
