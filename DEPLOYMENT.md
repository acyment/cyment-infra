# Deployment Guide

Complete setup guide for automated CI/CD deployment to VPS.

## Overview

The deployment pipeline automatically:
- Validates configuration on every push
- Deploys to production VPS after tests pass
- Updates all repositories (cyment-infra + sibling repos)
- Rebuilds and restarts all Docker services

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
git clone https://github.com/acyment/botini.club.git ../botini.club

# Configure environment
cp .env.example .env
nano .env  # Add your production secrets

# Initial deployment
./scripts/setup.sh
./scripts/deploy.sh production
```

### 3. Verify Services

```bash
# Check all services are running
docker compose ps

# Test endpoints
curl -I https://timer.cyment.com
curl -I https://backin15.app
curl -I https://botini.club
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

### Automatic Deployment

When you push to `main` or `master`:

```
Push → GitHub Actions → Validate → Test → Deploy → Services Restarted
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

3. **Deploy** (5-10 min):
   - SSH to VPS
   - Pull latest changes (cyment-infra + sibling repos)
   - Run deployment script
   - Rebuild containers
   - Restart services
   - Show status

### Manual Deployment

```bash
# Trigger via GitHub UI
Actions → CI/CD Pipeline → Run workflow → Branch: main

# Or on VPS directly
ssh user@vps-ip
cd /path/to/cyment-infra
git pull
./scripts/deploy.sh production
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
docker compose logs botini-api
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
ls -la ../Tempi.app ../backin15 ../botini.club
```

**Certificate/SSL issues:**
```bash
# Check Caddy logs
docker compose logs caddy

# Test DNS resolution
dig timer.cyment.com
dig backin15.app

# Check Caddyfile syntax
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
```

**Build failures:**
```bash
# Check sibling repo Dockerfiles exist
ls ../Tempi.app/Dockerfile
ls ../backin15/apps/backin15_web/Dockerfile
ls ../botini.club/Dockerfile

# Try building specific service
docker compose build tempi-app
```

### Rollback Procedure

```bash
# SSH to VPS
ssh user@vps-ip
cd /path/to/cyment-infra

# Checkout previous commit
git log --oneline -10  # Find good commit
git checkout <commit-hash>

# Or reset to previous
git reset --hard HEAD~1

# Redeploy
./scripts/deploy.sh production

# If sibling repos need rollback too
cd ../Tempi.app && git checkout <commit> && cd -
cd ../backin15 && git checkout <commit> && cd -
cd ../botini.club && git checkout <commit> && cd -
```

## Security Best Practices

1. **Never commit secrets** - `.env` stays on VPS only
2. **Restrict SSH key** - Use `command=` restriction in authorized_keys
3. **Use environment protection** - Require reviewers for production deployments
4. **Monitor deployments** - Check Actions logs after each deploy
5. **Backup regularly** - Run `./scripts/backup.sh` periodically
6. **Keep Docker updated** - Regular security updates on VPS

## Testing Deployment

After initial setup, test the pipeline:

```bash
# Make a small change
echo "# Test deployment" >> README.md
git add README.md
git commit -m "Test deployment pipeline"
git push origin main

# Watch deployment
# https://github.com/acyment/cyment-infra/actions

# Verify on VPS
ssh user@vps-ip
docker compose ps
curl -I https://timer.cyment.com
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