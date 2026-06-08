#!/bin/bash
set -euo pipefail

echo "🚀 Deploying Cyment Infrastructure"
echo "===================================="

# Default to production
ENV=${1:-production}

require_dir() {
    local path="$1"
    local label="$2"

    if [ ! -d "$path" ]; then
        echo "❌ $label not found at $path"
        exit 1
    fi

    echo "✓ $label found"
}

require_env() {
    local name="$1"
    local value="${!name:-}"

    if [ -z "$value" ] || [ "$value" = "your_secure_password_here" ] || [ "$value" = "your_jwt_secret_here" ]; then
        echo "❌ $name must be set in .env"
        exit 1
    fi
}

if [ "$ENV" = "local" ]; then
    COMPOSE_FILE="docker-compose.local.yml"
    echo "🖥️  Deploying to LOCAL environment"
    
    # Check if .env exists, if not copy from example
    if [ ! -f ".env" ]; then
        echo "⚠️  .env file not found, copying from .env.example"
        cp .env.example .env
    fi
    
    # Start services
    echo "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d --build
    
    echo ""
    echo "✅ Local deployment complete!"
    echo ""
    echo "Services available at:"
    echo "  - Landing page: http://localhost:8080"
    echo "  - BackIn15:     http://localhost:5002"
    echo "  - Fichus Feria: http://localhost:8787/healthz"
    echo ""
    echo "Commands:"
    echo "  - View logs:   docker compose -f $COMPOSE_FILE logs -f"
    echo "  - Stop:        docker compose -f $COMPOSE_FILE down"
    echo "  - Health:      docker compose -f $COMPOSE_FILE ps"
    
elif [ "$ENV" = "production" ] || [ "$ENV" = "prod" ]; then
    COMPOSE_FILE="docker-compose.yml"
    echo "🌐 Deploying to PRODUCTION environment"
    
    # Pre-deployment checks
    echo ""
    echo "🔍 Running pre-deployment checks..."
    
    if [ ! -f ".env" ]; then
        echo "❌ .env file not found! Create it from .env.example"
        exit 1
    fi

    # Load .env so variable checks below work
    set -a; source .env; set +a
    
    require_dir "../Tempi.app" "Tempi.app"
    require_dir "../backin15" "backin15"
    require_dir "../fichus/backend/feria" "Fichus Feria backend"
    require_dir "../botini.club" "botini.club"
    require_dir "../XCSteward-website" "XCSteward-website"

    # Check required botini secrets
    require_env "BOTINI_DB_PASSWORD"
    require_env "BOTINI_JWT_SECRET"

    # Check required umami secrets (empty Postgres password breaks the container)
    require_env "UMAMI_DB_PASSWORD"
    require_env "UMAMI_APP_SECRET"

    # Validate compose file
    echo "Validating Docker Compose configuration..."
    docker compose -f "$COMPOSE_FILE" config > /dev/null
    echo "✓ Configuration valid"
    
    # Build and deploy
    echo ""
    echo "🏗️  Building and deploying..."
    docker compose -f "$COMPOSE_FILE" up -d --build --wait --wait-timeout "${COMPOSE_WAIT_TIMEOUT:-180}"

    # The Caddyfile is bind-mounted, so `up -d` does not recreate the caddy
    # container when only its contents change. Reload Caddy explicitly so
    # Caddyfile edits (e.g. redirects) actually take effect. `caddy reload`
    # validates first and keeps the running config if the new one is invalid.
    echo "🔁 Reloading Caddy configuration..."
    docker compose -f "$COMPOSE_FILE" exec -T caddy caddy reload --config /etc/caddy/Caddyfile

    # Check health
    echo ""
    echo "📊 Service status:"
    docker compose -f "$COMPOSE_FILE" ps

    if docker compose -f "$COMPOSE_FILE" ps --status exited -q | grep -q .; then
        echo "❌ One or more services exited after deployment"
        docker compose -f "$COMPOSE_FILE" ps --status exited
        exit 1
    fi

    if docker compose -f "$COMPOSE_FILE" ps | grep -qi "unhealthy"; then
        echo "❌ One or more services are unhealthy after deployment"
        exit 1
    fi
    
    echo ""
    echo "✅ Production deployment complete!"
    echo ""
    echo "Services:"
    echo "  - Tempi Timer:  https://timer.cyment.com"
    echo "  - BackIn15:     https://backin15.app"
    echo "  - Fichus Feria: https://feria.fichusapp.com/healthz"
    echo "  - Botini Club:  https://botini.club"
    echo "  - XCSteward:    https://xcsteward.com"
    echo "  - Umami:        https://umami.cyment.com"
    echo ""
    echo "Commands:"
    echo "  - View logs:   docker compose logs -f"
    echo "  - Restart:     docker compose restart"
    echo "  - Health:      docker compose ps"
else
    echo "❌ Unknown environment: $ENV"
    echo "Usage: ./scripts/deploy.sh [local|production]"
    exit 1
fi
