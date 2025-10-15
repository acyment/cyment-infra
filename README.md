# Cyment Infrastructure

Docker Compose setup for running multiple services on VPS B with Caddy reverse proxy.

## Services

- **Caddy**: Reverse proxy with automatic HTTPS
- **Postiz**: Open-source social media scheduling (Buffer alternative)
- **PocketBase**: Backend for CrowdTimer and future apps
- **PostgreSQL**: Database for Postiz
- **Redis**: Cache/session store for Postiz
- **Tempi Timer**: Static Svelte timer served behind Caddy at https://timer.cyment.com

## Setup

1. Clone repository to VPS B
2. Copy `.env.example` to `.env` and configure
3. Run: `docker compose up -d`

## DNS Configuration

Ensure these A records point to VPS B IP:

- `postiz.cyment.com`
- `zoom.crowdclock.app`
- `timer.cyment.com`

## Services Access

- Postiz: https://postiz.cyment.com
- PocketBase Admin: https://zoom.crowdclock.app/pb/_/
- Tempi Timer: https://timer.cyment.com

## Tempi Timer Notes

- Keep a sibling checkout of the Tempi source at `../Tempi.app` when running `docker compose build`; the `tempi-app` image copies that directory during the build stage.
- Deploy the timer with `docker compose up -d --build tempi-app caddy` to rebuild the static bundle and reload Caddy.

## One‑Shot Init

- `pocketbase-admin-init` (run once per fresh volume): creates or updates the admin using `PB_ADMIN_EMAIL`/`PB_ADMIN_PASSWORD` from `.env`.
  - `docker compose up -d --no-deps pocketbase-admin-init`

- `crowdtimer-pb-init` (idempotent): waits for PocketBase and seeds required collections.
  - `docker compose up -d --no-deps crowdtimer-pb-init`

Both services exit after success. Re-run them safely if you change credentials (admin) or schema (seed).

## Adding New Services

1. Add service to `docker-compose.yml`
2. Add reverse proxy rule to `Caddyfile`
3. Update DNS records in Cloudflare

## Adding New Services

1. Add service to `docker-compose.yml`
2. Add reverse proxy rule to `Caddyfile`
3. Update DNS records in Cloudflare
