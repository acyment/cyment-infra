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

# Test 1: Validate Docker Compose files
echo ""
echo "📋 Test 1: Validating Docker Compose configurations"
if docker compose -f docker-compose.yml config > /dev/null 2>&1; then
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
[ -f "README.md" ] && print_status 0 "README.md exists" || print_status 1 "README.md missing"

# Test 3: Check for .env files (should not be committed)
echo ""
echo "🔒 Test 3: Checking for sensitive files"
if git ls-files | grep -q "\.env$"; then
    print_status 1 "WARNING: .env file is tracked by git!"
else
    print_status 0 ".env file is not tracked (good)"
fi

if git ls-files | grep -q "\.env\.local$"; then
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
echo "  - Deploy prod: docker compose up -d --build"
echo "  - View logs:   docker compose logs -f"

exit "$FAILED"
