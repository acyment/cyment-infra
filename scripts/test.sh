#!/bin/bash
set -e

echo "🧪 Running Infrastructure Tests"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Test 1: Validate Docker Compose files
echo ""
echo "📋 Test 1: Validating Docker Compose configurations"
docker compose -f docker-compose.yml config > /dev/null 2>&1
print_status $? "Production Docker Compose is valid"

docker compose -f docker-compose.local.yml config > /dev/null 2>&1
print_status $? "Local Docker Compose is valid"

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
    caddy validate --config Caddyfile --adapter caddyfile > /dev/null 2>&1
    print_status $? "Production Caddyfile syntax is valid"
    
    caddy validate --config Caddyfile.local --adapter caddyfile > /dev/null 2>&1
    print_status $? "Local Caddyfile syntax is valid"
else
    echo -e "${YELLOW}⚠${NC} Caddy not installed locally, skipping syntax validation"
fi

# Test 5: Check for common security issues
echo ""
echo "🔐 Test 5: Security checks"
if grep -r "password\|secret\|token\|key" --include="*.yml" --include="*.yaml" --include="*.json" . 2>/dev/null | grep -v ".env.example\|README\|node_modules\|.git\|scripts/" | head -3; then
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
        print_status 1 ".env and .env.example have different variables"
        echo "Run: diff <(grep -E '^[A-Z_]+=' .env | cut -d= -f1 | sort) <(grep -E '^[A-Z_]+=' .env.example | cut -d= -f1 | sort)"
    fi
else
    echo -e "${YELLOW}⚠${NC} .env file not found (copy from .env.example)"
fi

# Test 7: Check sibling repositories
echo ""
echo "🔗 Test 7: Checking sibling repositories"
if [ -d "../Tempi.app" ]; then
    print_status 0 "Tempi.app repository found"
else
    echo -e "${YELLOW}⚠${NC} Tempi.app repository not found at ../Tempi.app"
fi

if [ -d "../backin15" ]; then
    print_status 0 "backin15 repository found"
else
    echo -e "${YELLOW}⚠${NC} backin15 repository not found at ../backin15"
fi

echo ""
echo "================================"
echo "🎉 Tests complete!"
echo ""
echo "Next steps:"
echo "  - Start local: docker compose -f docker-compose.local.yml up -d"
echo "  - Deploy prod: docker compose up -d --build"
echo "  - View logs:   docker compose logs -f"
