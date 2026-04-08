#!/bin/bash

# Setup script for Ansible playbook
# This prepares the SSH keys and validates the configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="$SCRIPT_DIR/files"

echo "🔧 Ansible Playbook Setup"
echo "=========================="
echo ""

# Create files directory if it doesn't exist
mkdir -p "$FILES_DIR"

echo "📋 Checking prerequisites..."

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible not found. Installing..."
    pip install ansible
fi
echo "✓ Ansible installed"

# Check SSH keys
echo ""
echo "🔑 Checking SSH keys..."

# Authorized keys
if [ -f "$FILES_DIR/authorized_keys" ]; then
    echo "✓ authorized_keys already exists in files/"
else
    echo "⚠️  authorized_keys not found in files/"
    
    # Check if we can copy from local machine
    if [ -f "$HOME/.ssh/authorized_keys" ]; then
        read -p "Copy from ~/.ssh/authorized_keys? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$HOME/.ssh/authorized_keys" "$FILES_DIR/authorized_keys"
            echo "✓ Copied authorized_keys"
        fi
    fi
fi

# GitHub deploy key
if [ -f "$FILES_DIR/github_deploy_key" ]; then
    echo "✓ github_deploy_key already exists in files/"
else
    echo "⚠️  github_deploy_key not found in files/"
    
    # Look for common GitHub key names
    GITHUB_KEYS=(
        "$HOME/.ssh/crowdtimer_github_deploy_prod"
        "$HOME/.ssh/github_actions"
        "$HOME/.ssh/id_rsa"
    )
    
    for key in "${GITHUB_KEYS[@]}"; do
        if [ -f "$key" ]; then
            read -p "Use $(basename "$key") as GitHub deploy key? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$key" "$FILES_DIR/github_deploy_key"
                cp "$key.pub" "$FILES_DIR/github_deploy_key.pub"
                echo "✓ Copied GitHub deploy key"
                break
            fi
        fi
    done
fi

# Validate files exist
echo ""
echo "🔍 Validating configuration..."

if [ ! -f "$FILES_DIR/authorized_keys" ]; then
    echo "❌ authorized_keys is required"
    exit 1
fi

if [ ! -f "$FILES_DIR/github_deploy_key" ]; then
    echo "⚠️  github_deploy_key not found - GitHub access won't work"
    echo "   You can add it later or set copy_github_key=false in inventory"
fi

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Review the inventory:"
echo "   cat ansible/inventory.ini"
echo ""
echo "2. Test connection (dry run):"
echo "   cd ansible && ansible-playbook -i inventory.ini playbook.yml --check --diff"
echo ""
echo "3. Apply configuration:"
echo "   cd ansible && ansible-playbook -i inventory.ini playbook.yml"
echo ""
