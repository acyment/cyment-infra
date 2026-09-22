# CrowdTimer production migration

CrowdTimer runs on the shared `infra.cyment.com` VPS under the central Compose
project and Caddy instance. Production is promoted manually from the
`CI/CD Pipeline` GitHub Actions workflow; do not edit the VPS checkout or its
configuration over SSH.

## Production topology

| Public hostname | Origin path |
| --- | --- |
| `crowdtimer.app`, `www.crowdtimer.app` | Caddy serves the published static site volume |
| `live.crowdtimer.app` | Caddy proxies `crowdtimer-app:3000` |
| `pb.crowdtimer.app` | Caddy proxies the public PocketBase API and realtime endpoint |
| `pb-admin.crowdtimer.app` | Cloudflare named tunnel proxies PocketBase directly; Cloudflare Access is mandatory |

The admin hostname is intentionally absent from `Caddyfile` and must not have a
public `A`/`AAAA` record. The `crowdtimer-cloudflared` container is its only
ingress path.

## One-time setup

1. Create a Cloudflare Access self-hosted application for
   `pb-admin.crowdtimer.app` before publishing the tunnel route. Allow only the
   operator identity/group, require MFA, and use a short session duration.
2. Create a named Cloudflare Tunnel and map `pb-admin.crowdtimer.app` to
   `http://crowdtimer-pocketbase:8090`. Enable **Protect with Access** for the
   published application.
3. Add the tunnel token as the `CROWDTIMER_TUNNEL_TOKEN` secret in the protected
   GitHub `production` environment.
4. Add `CROWDTIMER_ENV` to that environment. Its multiline value must follow
   `.env.crowdtimer.example`; use a new PocketBase superuser password rather
   than copying the retired server's password.
5. Confirm `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, and `VPS_PATH` are present in
   the same environment.

The workflow writes both CrowdTimer secret files atomically beneath
`~/.config/cyment-infra/` with mode `0600`. They are never stored in Git.

## Promote a CrowdTimer revision

1. Ensure the selected CrowdTimer commit has passed unit/DOM tests, real
   PocketBase E2E, typecheck, lint, and both production Docker builds.
2. Set `CROWDTIMER_REF` in `deploy/versions.env` to the full 40-character commit
   SHA and merge the infrastructure change.
3. In GitHub Actions, run `CI/CD Pipeline` on `master` with
   `deploy_production=true`, then approve the protected `production`
   environment.
4. Verify the deployment job checked out exactly that SHA and that all
   CrowdTimer services are healthy.

The deploy script creates the PocketBase superuser, starts PocketBase, applies
the idempotent schema seed, publishes the static site volume, and starts the app
sequentially. The initial migration deliberately starts with a fresh PocketBase
volume; no data is copied from the retired host.

## First cutover

Before changing DNS, confirm the deployment job reports the app and PocketBase
as healthy and use read-only SSH inspection to test their container-local
endpoints. A public TLS probe cannot be used yet because Caddy obtains the
hostname certificates only after traffic is routed to the new host.

```bash
docker compose --env-file .env --env-file deploy/versions.env \
  --env-file ~/.config/cyment-infra/crowdtimer.env \
  exec -T crowdtimer-app curl --fail http://127.0.0.1:3000/healthz
docker compose --env-file .env --env-file deploy/versions.env \
  --env-file ~/.config/cyment-infra/crowdtimer.env \
  exec -T crowdtimer-pocketbase wget -qO- http://127.0.0.1:8090/api/health
```

Then move proxied DNS records in this order, verifying each hostname before the
next: `pb.crowdtimer.app`, `crowdtimer.app` plus `www`, then
`live.crowdtimer.app`. Keep the old CrowdTimer VPS (`46.62.234.158`) running and
unchanged for 24 hours.

Verify after cutover:

```bash
curl --fail https://pb.crowdtimer.app/api/health
curl --fail https://live.crowdtimer.app/healthz
curl --fail --head https://crowdtimer.app/
```

Open `pb-admin.crowdtimer.app` in a private browser session and confirm the
Cloudflare Access login appears before PocketBase. An unauthenticated request
must never reach the PocketBase admin UI.

## Rollback during the 24-hour window

Point the three public DNS records back to `46.62.234.158`. Do not copy or merge
the new disposable PocketBase data into the old host. Investigate and fix the
infrastructure locally, commit and push the fix, then use the protected manual
deployment workflow again. After 24 healthy hours, decommission the old VPS in
a separate, explicitly approved operation.
