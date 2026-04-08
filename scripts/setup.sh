#!/bin/bash
set -e

echo "🔧 Setup Script for Cyment Infrastructure"
echo "========================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Docker
if command -v docker &> /dev/null; then
    echo "✓ Docker installed ($(docker --version))"
else
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    echo "✓ Docker Compose installed ($(docker compose version --short))"
else
    echo "❌ Docker Compose not found. Please install Docker Compose."
    exit 1
fi

# Check Git
if command -v git &> /dev/null; then
    echo "✓ Git installed ($(git --version))"
else
    echo "❌ Git not found. Please install Git."
    exit 1
fi

echo ""
echo "📁 Checking directory structure..."

# Check sibling repositories
if [ -d "../Tempi.app" ]; then
    echo "✓ Tempi.app found at ../Tempi.app"
else
    echo "⚠️  Tempi.app not found at ../Tempi.app"
    echo "   Run: git clone <tempi-repo-url> ../Tempi.app"
fi

if [ -d "../backin15" ]; then
    echo "✓ backin15 found at ../backin15"
else
    echo "⚠️  backin15 not found at ../backin15"
    echo "   Run: git clone <backin15-repo-url> ../backin15"
fi

echo ""
echo "⚙️  Setting up environment..."

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✓ Created .env from .env.example"
        echo "⚠️  Please edit .env with your actual values!"
    else
        echo "❌ .env.example not found"
    fi
else
    echo "✓ .env already exists"
fi

# Create .env.local if it doesn't exist
if [ ! -f ".env.local" ]; then
    if [ -f ".env.local.example" ]; then
        cp .env.local.example .env.local
        echo "✓ Created .env.local from .env.local.example"
    else
        echo "ℹ️  No .env.local.example found (optional)"
    fi
else
    echo "✓ .env.local already exists"
fi

echo ""
echo "🔐 Checking file permissions..."

# Make scripts executable
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
    echo "✓ Scripts are executable"
fi

echo ""
echo "🧪 Running validation tests..."
if [ -f "scripts/test.sh" ]; then
    ./scripts/test.sh
else
    echo "ℹ️  Test script not found, skipping validation"
fi

echo ""
echo "========================================="
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Configure environment variables:"
echo "   nano .env"
echo ""
echo "2. Start local development:"
echo "   ./scripts/deploy.sh local"
echo ""
echo "3. Or start production:"
echo "   ./scripts/deploy.sh production"
echo ""
echo "4. View logs:"
echo "   docker compose logs -f"
echo ""
