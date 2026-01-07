# Cyment Infrastructure

Docker Compose setup for running multiple services on VPS B with Caddy reverse proxy.

## Services

- **Caddy**: Reverse proxy with automatic HTTPS
- **Postiz**: Open-source social media scheduling (Buffer alternative)
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
- `timer.cyment.com`

## Services Access

- Postiz: https://postiz.cyment.com
- Tempi Timer: https://timer.cyment.com

## Tempi Timer Notes

- Keep a sibling checkout of the Tempi source at `../Tempi.app` when running `docker compose build`; the `tempi-app` image copies that directory during the build stage.
- Deploy the timer with `docker compose up -d --build tempi-app caddy` to rebuild the static bundle and reload Caddy.


## Adding New Services

1. Add service to `docker-compose.yml`
2. Add reverse proxy rule to `Caddyfile`
3. Update DNS records in Cloudflare

## Adding New Services

1. Add service to `docker-compose.yml`
2. Add reverse proxy rule to `Caddyfile`
3. Update DNS records in Cloudflare
