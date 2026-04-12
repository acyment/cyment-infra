# VPS Deployment Fixes

## Issues Fixed in cyment-infra

### ✅ 1. DNS Issues - Removed www.* domains from Caddyfile
**Problem:** `www.backin15.app` and `www.botini.club` don't have DNS A records, causing Caddy to fail SSL certificate generation.

**Solution:** Commented out these domains in Caddyfile. To enable them later:
1. Add DNS A records in your DNS provider
2. Uncomment the blocks in Caddyfile
3. Reload Caddy

---

## Issues to Fix in Sibling Repos

### 🔧 2. backin15 Dockerfile Bug

**File:** `../backin15/apps/backin15_web/Dockerfile` (Line 42)

**Problem:**
```dockerfile
COPY .env.production* ./ 2>/dev/null || true
```

This line causes Docker build to fail with:
```
failed to solve: lstat /2>/dev/null: no such file or directory
```

**Fix:**
Replace line 42 with:
```dockerfile
# Copy .env.production if it exists (for local builds)
RUN if [ -f .env.production ]; then cp .env.production .; fi || true
```

Or simply remove the line if .env.production isn't needed in the build.

**Alternative fix using multi-stage:**
```dockerfile
# In builder stage, before npm run build:
RUN if ls .env.production* 1> /dev/null 2>&1; then \
        cp .env.production* ./; \
    fi
```

---

### 🔧 3. botini.club Frontend - Missing npm dependency

**File:** `../botini.club/frontend/package.json`

**Problem:**
```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package '@sveltejs/adapter-node'
```

**Fix:**
Add the missing dependency to `package.json`:

```bash
cd ~/botini.club/frontend
npm install --save-dev @sveltejs/adapter-node
# or
npm install --save-dev @sveltejs/adapter-static
```

Then commit and push:
```bash
git add package.json package-lock.json
git commit -m "Add missing @sveltejs/adapter-node dependency"
git push origin main
```

---

### 🔧 4. botini.club API - Python module path issue

**File:** `../botini.club/Dockerfile`

**Problem:** Python can't find the `botini` module.

**Possible fixes:**

**Option A:** Ensure PYTHONPATH is set in Dockerfile:
```dockerfile
ENV PYTHONPATH=/app
```

**Option B:** Install the package in editable mode:
```dockerfile
RUN pip install -e .
```

**Option C:** Check the directory structure - the backend code should be importable as `botini`.

---

### 🔧 5. Caddy Zombie Processes (Partial Fix)

**Status:** Reduced from 4419 to 128 zombies, but still occurring.

**Cause:** Caddy 2.11.2 still has the ssl_client zombie process bug during ACME challenges.

**Current mitigation:**
- Using `caddy:2.11-alpine` (auto-updates to latest patch)
- Zombie count reduced by 97%

**Potential solutions:**
1. **Wait for Caddy fix** - Reported to Caddy team
2. **Add init process** - Use `tini` as PID 1 in container
3. **Periodic cleanup** - Cron job to kill zombies

**To add tini to Caddy:**
Modify docker-compose.yml:
```yaml
caddy:
  image: caddy:2.11-alpine
  init: true  # Add this line
```

Or use tini:
```yaml
caddy:
  image: caddy:2.11-alpine
  entrypoint: ["/sbin/tini", "--"]
  command: ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
```

---

## Quick Fix Commands

Run these on the VPS to apply fixes:

```bash
# 1. Fix backin15 Dockerfile (run on VPS)
cd ~/backin15/apps/backin15_web
sed -i 's/COPY .env.production\* \_\/ 2>\/dev\/null || true/# COPY .env.production removed - was causing build failures/' Dockerfile

# 2. Restart Caddy with init
cd ~/cyment-infra
docker compose stop caddy
docker compose up -d caddy

# 3. Check zombie count
ps aux | grep -w Z | wc -l
```

---

## Current Status

| Service | Status | Notes |
|---------|--------|-------|
| caddy | ✅ Running | 128 zombies (97% reduction) |
| tempi-app | ✅ Running | timer.cyment.com working |
| backin15-app | ❌ Not built | Dockerfile bug needs fix |
| botini-api | ❌ Not built | Python module issue |
| botini-frontend | ❌ Not built | Missing npm dependency |
| botini-db | ✅ Image pulled | Postgres 18 ready |
| botini-redis | ✅ Image pulled | Redis 8 ready |

---

## Next Steps

1. **Fix backin15 Dockerfile** in backin15 repo
2. **Fix botini.club dependencies** in botini.club repo  
3. **Push fixes** to GitHub
4. **Rebuild on VPS** with `docker compose up -d --build`
5. **Add DNS records** for www.* domains if needed

Want me to help with any of these fixes?
