#!/bin/bash
set -e

echo "🚀 Deploying Cyment Infrastructure"
echo "===================================="

# Default to production
ENV=${1:-production}

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
    
    if [ ! -d "../Tempi.app" ]; then
        echo "⚠️  Tempi.app not found at ../Tempi.app"
    fi
    
    if [ ! -d "../backin15" ]; then
        echo "⚠️  backin15 not found at ../backin15"
    fi

    if [ ! -d "../botini.club" ]; then
        echo "⚠️  botini.club not found at ../botini.club"
    fi

    # Check required botini secrets
    if [ -z "${BOTINI_DB_PASSWORD:-}" ] || [ -z "${BOTINI_JWT_SECRET:-}" ]; then
        echo "❌ BOTINI_DB_PASSWORD and BOTINI_JWT_SECRET must be set in .env"
        exit 1
    fi
    
    # Validate compose file
    echo "Validating Docker Compose configuration..."
    docker compose -f "$COMPOSE_FILE" config > /dev/null
    echo "✓ Configuration valid"
    
    # Build and deploy
    echo ""
    echo "🏗️  Building and deploying..."
    docker compose -f "$COMPOSE_FILE" up -d --build
    
    # Wait for services
    echo ""
    echo "⏳ Waiting for services to be healthy..."
    sleep 5
    
    # Check health
    echo ""
    echo "📊 Service status:"
    docker compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "✅ Production deployment complete!"
    echo ""
    echo "Services:"
    echo "  - Tempi Timer:  https://timer.cyment.com"
    echo "  - BackIn15:     https://backin15.app"
    echo "  - Botini Club:  https://botini.club"
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
