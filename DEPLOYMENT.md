# Deployment Guide

Complete setup guide for validated, manually promoted deployment to the VPS.

## Overview

The pipeline validates configuration on every push and pull request. Production
deployment is manual: run the workflow on `main`/`master` with
`deploy_production=true`. The protected production environment then updates the
infrastructure checkout, branch-tracked sibling repositories, and the exact
CrowdTimer revision pinned in `deploy/versions.env` before rebuilding services.

## Prerequisites

- VPS with:
  - Docker 24.0+ installed
  - Docker Compose 2.20+ installed
  - Git installed
  - SSH access enabled
- GitHub repository with Actions enabled

## VPS Setup

### 1. Prepare VPS Environment

```bash
# SSH into VPS
ssh user@your-vps-ip

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com | sh

# Install Docker Compose (if needed)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create working directory
mkdir -p ~/cyment
cd ~/cyment
```

### 2. Clone Repositories

```bash
# Clone main infrastructure repository
git clone https://github.com/acyment/cyment-infra.git
cd cyment-infra

# Clone sibling repositories
git clone https://github.com/acyment/Tempi.app.git ../Tempi.app
git clone https://github.com/acyment/backin15.git ../backin15
git clone https://github.com/acyment/fichus.git ../fichus
git clone https://github.com/acyment/botini.club.git ../botini.club
git clone https://github.com/acyment/XCSteward-website.git ../XCSteward-website
git clone https://github.com/acyment/CrowdTimer.git ../CrowdTimer

# Configure environment
cp .env.example .env
nano .env  # Add your production secrets

# Initial deployment
./scripts/setup.sh
# Trigger the protected production workflow after configuring its secrets.
```

### 3. Verify Services

```bash
# Check all services are running
docker compose ps

# Test endpoints
curl -I https://timer.cyment.com
curl -I https://feliche.cyment.com
curl -I https://backin15.app
curl -I https://feria.fichusapp.com/healthz
curl -I https://botini.club
curl -I https://xcsteward.com
curl -I https://umami.cyment.com
curl -I https://crm.cyment.com
curl -I https://crowdtimer.app
curl -I https://live.crowdtimer.app/healthz
curl -I https://pb.crowdtimer.app/api/health
```

## SSH Key Setup

### 1. Generate SSH Key Pair

```bash
# On your local machine (NOT on VPS)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f github-actions-deploy

# This creates two files:
# - github-actions-deploy (private key)
# - github-actions-deploy.pub (public key)
```

### 2. Add Public Key to VPS

```bash
# Copy public key to VPS
ssh-copy-id -i github-actions-deploy.pub user@your-vps-ip

# Or manually:
cat github-actions-deploy.pub | ssh user@your-vps-ip "cat >> ~/.ssh/authorized_keys"

# Test SSH connection with the key
ssh -i github-actions-deploy user@your-vps-ip
```

### 3. Configure SSH Key Restrictions (Optional but Recommended)

```bash
# On VPS, edit authorized_keys to restrict the key
nano ~/.ssh/authorized_keys

# Add restrictions before the key:
from="github.com",command="/home/user/cyment/cyment-infra/scripts/deploy.sh production" ssh-ed25519 AAAA...

# This restricts:
# - Key only works from GitHub Actions IPs
# - Key only runs deployment script
```

## GitHub Secrets Configuration

### 1. Add Repository Secrets

Navigate to: `Settings → Secrets and variables → Actions → New repository secret`

Add these secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `VPS_HOST` | VPS IP or hostname | `192.168.1.100` or `vps.cyment.com` |
| `VPS_USER` | SSH username | `ubuntu` or `root` |
| `VPS_SSH_KEY` | Private SSH key | Contents of `github-actions-deploy` file |
| `VPS_PATH` | Path to repo on VPS | `/home/ubuntu/cyment/cyment-infra` |
| `CROWDTIMER_ENV` | Multiline CrowdTimer environment | Contents matching `.env.crowdtimer.example` |
| `CROWDTIMER_TUNNEL_TOKEN` | Named tunnel token | Cloudflare tunnel token for the admin route |

**Adding `VPS_SSH_KEY`:**
```bash
# Copy private key content
cat github-actions-deploy

# Paste entire content including:
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
...key content...
-----END OPENSSH PRIVATE KEY-----
```

### 2. Create Production Environment

Navigate to: `Settings → Environments → New environment`

- Name: `production`
- Add protection rules (optional):
  - Required reviewers (for approval before deploy)
  - Wait timer (delay deployment)
  - Deployment branches (restrict to main/master)

## Deployment Workflow

### Manual Production Deployment

After the desired infrastructure revision is merged:

```
Push → Validate/Test → Manual workflow approval → Deploy → Verify
```

**Pipeline stages:**
1. **Validate** (1-2 min):
   - Docker Compose config validation
   - Caddyfile syntax check
   - Secrets scan

2. **Smoke Test** (2-3 min):
   - Start local services
   - Test health endpoints
   - Cleanup

3. **Deploy** (manual, 5-10 min):
   - SSH to VPS
   - Pull latest changes (cyment-infra + sibling repos)
   - Run deployment script
   - Rebuild containers
   - Restart services
   - Show status

### Manual Deployment

```bash
# Trigger via GitHub UI
Actions → CI/CD Pipeline → Run workflow → Branch: main/master
# Set deploy_production=true

Direct edits, checkouts, and deployments on the VPS are not part of the release
workflow. Make changes locally, commit and push them, then use the protected
manual workflow so the repository remains the source of truth.
```

## Monitoring & Troubleshooting

### Check Deployment Status

```bash
# GitHub Actions
https://github.com/acyment/cyment-infra/actions

# On VPS - view logs
docker compose logs -f

# Check service health
docker compose ps

# View specific service logs
docker compose logs caddy
docker compose logs tempi-app
docker compose logs backin15-app
docker compose logs fichus-feria
docker compose logs botini-api
docker compose logs twenty-server
docker compose logs twenty-worker
```

### Common Issues

**Deployment fails with SSH error:**
```bash
# Test SSH connection manually
ssh -i github-actions-deploy user@vps-ip

# Check authorized_keys permissions
ls -la ~/.ssh/authorized_keys  # Should be 600

# Check SSH service on VPS
sudo systemctl status sshd
```

**Services not starting after deploy:**
```bash
# Check container status
docker compose ps

# View logs for errors
docker compose logs --tail=50

# Check .env file exists
ls -la .env

# Verify sibling repos exist
ls -la ../Tempi.app ../backin15 ../fichus/backend/feria ../botini.club
```

**Certificate/SSL issues:**
```bash
# Check Caddy logs
docker compose logs caddy

# Test DNS resolution
dig timer.cyment.com
dig backin15.app
dig feria.fichusapp.com

# Check Caddyfile syntax
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
```

**Build failures:**
```bash
# Check sibling repo Dockerfiles exist
ls ../Tempi.app/Dockerfile
ls ../backin15/apps/backin15_web/Dockerfile
ls ../fichus/backend/feria/Dockerfile
ls ../botini.club/Dockerfile

# Try building specific service
docker compose build tempi-app
docker compose build fichus-feria
```

### Rollback Procedure

Revert the infrastructure commit (and any affected sibling revision pin) in the
local repositories, push the revert, then run the protected manual production
workflow. CrowdTimer's first-cutover DNS rollback is documented separately in
`CROWDTIMER_DEPLOYMENT.md`.

## Security Best Practices

1. **Never commit secrets** - `.env` stays on VPS only
2. **Restrict SSH key** - Use `command=` restriction in authorized_keys
3. **Use environment protection** - Require reviewers for production deployments
4. **Monitor deployments** - Check Actions logs after each deploy
5. **Backup regularly** - Run `./scripts/backup.sh` periodically, copy archives off the VPS, and test restores
6. **Keep Docker updated** - Regular security updates on VPS

## Testing Deployment

After initial setup, test the pipeline:

```bash
# Push a reviewed change and wait for validation to finish.
git push origin master

# Manually dispatch CI/CD Pipeline with deploy_production=true, approve the
# production environment, and watch deployment.
# https://github.com/acyment/cyment-infra/actions

# Verify on VPS
ssh user@vps-ip
docker compose ps
curl -I https://timer.cyment.com
curl -I https://feliche.cyment.com
```

## Advanced Configuration

### Zero-Downtime Deployment (Future)

Currently, deployment has brief service interruption (~30-60 seconds). 

For zero-downtime:
- Use Docker health checks with graceful shutdown
- Implement blue-green deployment
- Use Caddy's graceful reload

### Multi-Server Deployment (Future)

To deploy to multiple servers:
- Add multiple SSH secrets (`VPS_HOST_2`, `VPS_SSH_KEY_2`, etc.)
- Create matrix deployment in workflow
- Use deployment coordination script

### Deployment Notifications (Future)

Add Slack/Discord/Email notifications:
- Use GitHub Actions marketplace actions
- Configure webhook endpoints
- Add notification step to workflow

## Support

For deployment issues:
1. Check GitHub Actions logs
2. Check VPS Docker logs
3. Review this guide's troubleshooting section
4. Check GitHub repository issues
