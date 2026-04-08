# Cyment Infrastructure

Docker Compose setup for running multiple services on VPS B with Caddy reverse proxy.

## Services

- **Caddy**: Reverse proxy with automatic HTTPS
- **Tempi Timer**: Static Svelte timer served behind Caddy at https://timer.cyment.com
- **BackIn15**: Web app for BackIn15 session sharing at https://backin15.app

## Setup

1. Clone repository to VPS B
2. Copy `.env.example` to `.env` and configure
3. Run: `docker compose up -d`

## DNS Configuration

Ensure these A records point to VPS B IP:

- `timer.cyment.com`
- `backin15.app`
- `www.backin15.app`

## Services Access

- Tempi Timer: https://timer.cyment.com
- BackIn15: https://backin15.app

## BackIn15 Web App Notes

- Keep a sibling checkout of the BackIn15 source at `../backin15` when running `docker compose build`
- The `backin15-app` image builds from `../backin15/apps/backin15_web/Dockerfile`
- Deploy with `docker compose up -d --build backin15-app caddy` to rebuild and reload Caddy
- Configure build-time environment variables in `.env` (see `.env.example`)

## Tempi Timer Notes

- Keep a sibling checkout of the Tempi source at `../Tempi.app` when running `docker compose build`; the `tempi-app` image copies that directory during the build stage.
- Deploy the timer with `docker compose up -d --build tempi-app caddy` to rebuild the static bundle and reload Caddy.


## Adding New Services

1. Add service to `docker-compose.yml`
2. Add reverse proxy rule to `Caddyfile`
3. Update DNS records in Cloudflare

## Local Development

Use `docker-compose.local.yml` for local testing:

```bash
docker compose -f docker-compose.local.yml up -d
```

Local services available at:
- Landing page: http://localhost:8080
- BackIn15: http://localhost:5002
