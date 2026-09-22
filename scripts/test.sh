#!/bin/bash
set -e

echo "🧪 Running Infrastructure Tests"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
FAILED=0
PROD_COMPOSE=(
    docker compose
    --env-file .env.example
    --env-file deploy/versions.env
    --env-file .env.crowdtimer.example
    -f docker-compose.yml
)

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        FAILED=1
    fi
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

run_check() {
    local label="$1"
    shift
    local output

    if output=$("$@" 2>&1); then
        print_status 0 "$label"
    else
        [ -n "$output" ] && echo "$output"
        print_status 1 "$label"
    fi
}

# Keep repository checks portable across developer machines and the minimal
# GitHub-hosted runner image.
file_matches() {
    local pattern="$1"
    local file="$2"

    if command -v rg > /dev/null 2>&1; then
        rg -q -- "$pattern" "$file"
    else
        grep -Eq -- "$pattern" "$file"
    fi
}

# Test 1: Validate Docker Compose files
echo ""
echo "📋 Test 1: Validating Docker Compose configurations"
if "${PROD_COMPOSE[@]}" config > /dev/null 2>&1; then
    print_status 0 "Production Docker Compose is valid"
else
    print_status 1 "Production Docker Compose is valid"
fi

if docker compose -f docker-compose.local.yml config > /dev/null 2>&1; then
    print_status 0 "Local Docker Compose is valid"
else
    print_status 1 "Local Docker Compose is valid"
fi

# Test 2: Check for required files
echo ""
echo "📁 Test 2: Checking required files"
[ -f "Caddyfile" ] && print_status 0 "Caddyfile exists" || print_status 1 "Caddyfile missing"
[ -f "Caddyfile.local" ] && print_status 0 "Caddyfile.local exists" || print_status 1 "Caddyfile.local missing"
[ -f ".env.example" ] && print_status 0 ".env.example exists" || print_status 1 ".env.example missing"
[ -f ".env.crowdtimer.example" ] && print_status 0 ".env.crowdtimer.example exists" || print_status 1 ".env.crowdtimer.example missing"
[ -f "deploy/versions.env" ] && print_status 0 "deploy/versions.env exists" || print_status 1 "deploy/versions.env missing"
[ -f "README.md" ] && print_status 0 "README.md exists" || print_status 1 "README.md missing"

# Test 3: Check for .env files (should not be committed)
echo ""
echo "🔒 Test 3: Checking for sensitive files"
if git ls-files --error-unmatch -- .env > /dev/null 2>&1; then
    print_status 1 "WARNING: .env file is tracked by git!"
else
    print_status 0 ".env file is not tracked (good)"
fi

if git ls-files --error-unmatch -- .env.local > /dev/null 2>&1; then
    print_status 1 "WARNING: .env.local file is tracked by git!"
else
    print_status 0 ".env.local file is not tracked (good)"
fi

# Test 4: Validate Caddyfile syntax (if caddy is available)
echo ""
echo "🔧 Test 4: Validating Caddyfile syntax"
if command -v caddy &> /dev/null; then
    run_check "Production Caddyfile syntax is valid" caddy validate --config Caddyfile --adapter caddyfile
    run_check "Local Caddyfile syntax is valid" caddy validate --config Caddyfile.local --adapter caddyfile
elif command -v docker &> /dev/null; then
    run_check "Production Caddyfile syntax is valid" docker run --rm -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2.11-alpine caddy validate --config /etc/caddy/Caddyfile
    run_check "Local Caddyfile syntax is valid" docker run --rm -v "$PWD/Caddyfile.local:/etc/caddy/Caddyfile:ro" caddy:2.11-alpine caddy validate --config /etc/caddy/Caddyfile
else
    print_warn "Caddy and Docker are unavailable, skipping Caddyfile syntax validation"
fi

# Test 5: Check for common security issues
echo ""
echo "🔐 Test 5: Security checks"
if command -v rg > /dev/null 2>&1; then
    SECRET_HITS=$(rg -n -i '(password|secret|token|api[_-]?key|private[_-]?key)\s*[:=]\s*["'\'']?[A-Za-z0-9+/=._-]{16,}' \
        --glob '!README.md' \
        --glob '!DEPLOYMENT.md' \
        --glob '!VPS_FIXES.md' \
        --glob '!ansible/README.md' \
        --glob '!ansible/files/**' \
        --glob '!scripts/**' \
        --glob '!node_modules/**' \
        --glob '!.git/**' \
        . 2>/dev/null | grep -v '\${' | grep -v 'your_' | grep -v '_here' | head -5 || true)
else
    SECRET_HITS=$(grep -RInE \
        --exclude='README.md' \
        --exclude='DEPLOYMENT.md' \
        --exclude='VPS_FIXES.md' \
        --exclude-dir='.git' \
        --exclude-dir='node_modules' \
        --exclude-dir='scripts' \
        '(password|secret|token|api[_-]?key|private[_-]?key)[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9+/=._-]{16,}' \
        . 2>/dev/null | grep -v '\${' | grep -v 'your_' | grep -v '_here' | head -5 || true)
fi

if [ -n "$SECRET_HITS" ]; then
    echo "$SECRET_HITS"
    print_status 1 "Potential secrets found in code"
else
    print_status 0 "No obvious secrets found in committed files"
fi

# Test 6: Check environment variable consistency
echo ""
echo "📝 Test 6: Environment variable checks"
if [ -f ".env" ]; then
    ENV_VARS=$(grep -E "^[A-Z_]+=" .env | cut -d= -f1 | sort)
    EXAMPLE_VARS=$(grep -E "^[A-Z_]+=" .env.example | cut -d= -f1 | sort)
    
    if [ "$ENV_VARS" = "$EXAMPLE_VARS" ]; then
        print_status 0 ".env and .env.example have matching variables"
    else
        print_warn ".env and .env.example have different variables"
        echo "Run: diff <(grep -E '^[A-Z_]+=' .env | cut -d= -f1 | sort) <(grep -E '^[A-Z_]+=' .env.example | cut -d= -f1 | sort)"
    fi
else
    print_warn ".env file not found (copy from .env.example for local/prod deploys)"
fi

# Test 7: Check sibling repositories
echo ""
echo "🔗 Test 7: Checking sibling repositories"
if [ -d "../Tempi.app" ]; then
    print_status 0 "Tempi.app repository found"
else
    print_warn "Tempi.app repository not found at ../Tempi.app"
fi

if [ -d "../backin15" ]; then
    print_status 0 "backin15 repository found"
else
    print_warn "backin15 repository not found at ../backin15"
fi

if [ -d "../fichus/backend/feria" ]; then
    print_status 0 "Fichus Feria backend found"
else
    print_warn "Fichus Feria backend not found at ../fichus/backend/feria"
fi

# Test 8: CrowdTimer shared-hosting contract
echo ""
echo "⏱️  Test 8: Checking CrowdTimer shared-hosting contract"

for service in \
    crowdtimer-pocketbase \
    crowdtimer-app \
    crowdtimer-cloudflared \
    crowdtimer-pb-superuser \
    crowdtimer-pb-init \
    crowdtimer-site-publish; do
    if file_matches "^  ${service}:" docker-compose.yml; then
        print_status 0 "CrowdTimer service ${service} is declared"
    else
        print_status 1 "CrowdTimer service ${service} is declared"
    fi
done

for hostname in crowdtimer.app live.crowdtimer.app pb.crowdtimer.app; do
    if file_matches "${hostname}" Caddyfile; then
        print_status 0 "Caddy routes ${hostname}"
    else
        print_status 1 "Caddy routes ${hostname}"
    fi
done

if file_matches "pb-admin\\.crowdtimer\\.app" Caddyfile; then
    print_status 1 "PocketBase admin is tunnel-only (not routed by Caddy)"
else
    print_status 0 "PocketBase admin is tunnel-only (not routed by Caddy)"
fi

if [ -f "deploy/versions.env" ] && file_matches '^CROWDTIMER_REF=[0-9a-f]{40}$' deploy/versions.env; then
    print_status 0 "CrowdTimer production revision is pinned"
else
    print_status 1 "CrowdTimer production revision is pinned"
fi

if file_matches 'CROWDTIMER_REF' scripts/deploy.sh && file_matches 'CROWDTIMER_REF' .github/workflows/ci.yml; then
    print_status 0 "Deploy paths enforce the CrowdTimer revision pin"
else
    print_status 1 "Deploy paths enforce the CrowdTimer revision pin"
fi

if file_matches 'git -C "\$path" fetch "\$repo_url" "\$branch"' .github/workflows/ci.yml &&
    file_matches 'git -C "\$path" fetch "\$repo_url" "\$ref"' .github/workflows/ci.yml; then
    print_status 0 "Deployment fetches declared repository URLs instead of stale origins"
else
    print_status 1 "Deployment fetches declared repository URLs instead of stale origins"
fi

if file_matches 'ensure_repo \.\./(backin15|Tempi\.app|fichus|botini\.club|XCSteward-website)' .github/workflows/ci.yml; then
    print_status 1 "CrowdTimer deployment leaves unrelated sibling checkouts untouched"
else
    print_status 0 "CrowdTimer deployment leaves unrelated sibling checkouts untouched"
fi

echo ""
echo "================================"
if [ "$FAILED" -eq 0 ]; then
    echo "🎉 Tests complete!"
else
    echo "❌ Tests failed!"
fi
echo ""
echo "Next steps:"
echo "  - Start local: docker compose -f docker-compose.local.yml up -d"
echo "  - Deploy prod: protected manual GitHub Actions workflow"
echo "  - View logs:   docker compose logs -f"

exit "$FAILED"
