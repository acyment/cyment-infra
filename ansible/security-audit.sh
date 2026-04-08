#!/bin/bash

# Security audit script for VPS
# Run this after the Ansible playbook to verify security settings

echo "🔒 Security Audit Report"
echo "========================"
echo ""
echo "Running on: $(date)"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "📋 SSH Configuration"
echo "--------------------"

# Check PermitRootLogin
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    check_pass "Root login is disabled"
else
    check_fail "Root login is NOT disabled"
fi

# Check PasswordAuthentication
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    check_pass "Password authentication is disabled"
else
    check_fail "Password authentication is NOT disabled"
fi

# Check PubkeyAuthentication
if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    check_pass "Public key authentication is enabled"
else
    check_warn "Public key authentication status unclear"
fi

# Check SSH port
SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
if [ "$SSH_PORT" = "22" ]; then
    check_pass "SSH is running on port 22"
else
    check_warn "SSH is running on non-standard port: $SSH_PORT"
fi

echo ""
echo "🛡️ Firewall Status"
echo "------------------"

if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        check_pass "UFW firewall is active"
        echo ""
        echo "Active rules:"
        sudo ufw status numbered | grep -E "^\["
    else
        check_fail "UFW firewall is NOT active"
    fi
else
    check_fail "UFW is not installed"
fi

echo ""
echo "🔐 Fail2ban Status"
echo "------------------"

if command -v fail2ban-client &> /dev/null; then
    if sudo systemctl is-active --quiet fail2ban; then
        check_pass "Fail2ban is running"
        echo ""
        echo "SSH jail status:"
        sudo fail2ban-client status sshd 2>/dev/null || echo "  SSH jail not configured"
    else
        check_fail "Fail2ban is NOT running"
    fi
else
    check_fail "Fail2ban is not installed"
fi

echo ""
echo "📊 System Updates"
echo "-----------------"

if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    check_pass "Automatic updates are configured"
    echo ""
    echo "Configuration:"
    grep -E "^APT::Periodic" /etc/apt/apt.conf.d/20auto-upgrades
else
    check_fail "Automatic updates are NOT configured"
fi

echo ""
echo "🔍 Auditd Status"
echo "----------------"

if command -v auditd &> /dev/null; then
    if sudo systemctl is-active --quiet auditd; then
        check_pass "Auditd is running"
    else
        check_fail "Auditd is NOT running"
    fi
else
    check_fail "Auditd is not installed"
fi

echo ""
echo "🐳 Docker Security"
echo "------------------"

if command -v docker &> /dev/null; then
    check_pass "Docker is installed"
    
    # Check if user is in docker group
    if groups "$USER" | grep -q "docker"; then
        check_pass "User $USER is in docker group"
    else
        check_warn "User $USER is NOT in docker group"
    fi
    
    # Check Docker service
    if sudo systemctl is-active --quiet docker; then
        check_pass "Docker service is running"
    else
        check_fail "Docker service is NOT running"
    fi
else
    check_fail "Docker is not installed"
fi

echo ""
echo "🔑 SSH Key Permissions"
echo "----------------------"

if [ -d ~/.ssh ]; then
    SSH_DIR_PERMS=$(stat -c "%a" ~/.ssh)
    if [ "$SSH_DIR_PERMS" = "700" ]; then
        check_pass "~/.ssh directory has correct permissions (700)"
    else
        check_fail "~/.ssh directory has incorrect permissions ($SSH_DIR_PERMS, should be 700)"
    fi
    
    if [ -f ~/.ssh/authorized_keys ]; then
        AUTH_KEYS_PERMS=$(stat -c "%a" ~/.ssh/authorized_keys)
        if [ "$AUTH_KEYS_PERMS" = "600" ]; then
            check_pass "authorized_keys has correct permissions (600)"
        else
            check_fail "authorized_keys has incorrect permissions ($AUTH_KEYS_PERMS, should be 600)"
        fi
    fi
    
    if [ -f ~/.ssh/github_deploy_key ]; then
        GITHUB_KEY_PERMS=$(stat -c "%a" ~/.ssh/github_deploy_key)
        if [ "$GITHUB_KEY_PERMS" = "600" ]; then
            check_pass "github_deploy_key has correct permissions (600)"
        else
            check_fail "github_deploy_key has incorrect permissions ($GITHUB_KEY_PERMS, should be 600)"
        fi
    fi
else
    check_fail "~/.ssh directory does not exist"
fi

echo ""
echo "📝 Recent Login Attempts"
echo "-----------------------"
echo "Failed SSH attempts (last 10):"
sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 || echo "  No failed attempts found or log not accessible"

echo ""
echo "========================"
echo "Audit complete!"
echo ""
echo "If any checks failed, review the Ansible playbook and re-run:"
echo "  ansible-playbook -i inventory.ini playbook.yml"
