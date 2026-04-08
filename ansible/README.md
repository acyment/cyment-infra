# Ansible Playbook for Cyment Infrastructure VPS

This Ansible playbook configures the VPS with security hardening and proper SSH key management.

## Security Features Implemented

### 🔐 SSH Hardening
- **Root login disabled** - Prevents direct root access
- **Password authentication disabled** - Forces key-based auth only
- **MaxAuthTries = 3** - Limits brute force attempts
- **ClientAliveInterval = 300** - Closes idle connections
- **LoginGraceTime = 60** - Shortens authentication window
- **AllowUsers = acyment** - Only specific user can login

### 🛡️ Intrusion Prevention
- **Fail2ban** - Bans IPs after 3 failed SSH attempts
- **UFW Firewall** - Blocks all ports except 22, 80, 443
- **Auditd** - Monitors changes to SSH config and user files

### 🔑 SSH Key Management
- Copies authorized_keys from local machine
- Configures GitHub deploy key for repository access
- Sets up SSH config for automatic GitHub authentication
- Adds GitHub to known_hosts automatically

### 🐳 Docker Security
- Runs Docker as non-root user (acyment in docker group)
- Auto-updates Docker packages
- Log rotation for container logs (7 days, 10MB max)

### 📊 Monitoring & Auditing
- **Auditd** - Tracks SSH config changes, user/group modifications
- **Logrotate** - Prevents log files from filling disk
- **Unattended-upgrades** - Auto-installs security patches

### 🚫 Disabled Services
- Telnet (plaintext protocol)
- FTP (insecure, use SFTP instead)

## Prerequisites

1. Install Ansible locally:
   ```bash
   pip install ansible
   ```

2. Prepare SSH keys in `files/` directory:
   ```bash
   mkdir -p ansible/files
   
   # Copy your authorized_keys
   cp ~/.ssh/authorized_keys ansible/files/
   
   # Copy GitHub deploy key (for repository access)
   cp ~/.ssh/crowdtimer_github_deploy_prod ansible/files/github_deploy_key
   cp ~/.ssh/crowdtimer_github_deploy_prod.pub ansible/files/github_deploy_key.pub
   ```

3. Update inventory:
   ```bash
   # Edit ansible/inventory.ini with your VPS details
   ```

## Usage

### Dry run (check mode)
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml --check --diff
```

### Apply configuration
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

### Copy only SSH keys
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml --tags ssh-keys
```

## What Gets Configured

### System Updates
- Updates apt cache and upgrades all packages
- Installs essential tools (vim, htop, git, jq, etc.)

### Security
- Configures SSH with strong settings
- Sets up Fail2ban (bans after 3 failed attempts)
- Configures UFW firewall (allows only 22, 80, 443)
- Enables automatic security updates
- Sets up system auditing with auditd

### SSH Keys
- Copies authorized_keys for passwordless login
- Configures GitHub deploy key
- Sets up SSH client config for GitHub
- Adds GitHub to known_hosts

### Docker
- Installs Docker CE and Docker Compose plugin
- Adds deploy user to docker group
- Configures log rotation for containers

## Security Checklist

✅ Root login disabled  
✅ Password auth disabled  
✅ Key-based auth only  
✅ Fail2ban protection  
✅ Firewall enabled (UFW)  
✅ Automatic security updates  
✅ System auditing enabled  
✅ SSH config monitored  
✅ Insecure services disabled  
✅ File permissions secured  

## Troubleshooting

### Connection refused after playbook
The playbook changes SSH port to 22 (default). If you have issues:
```bash
ssh -p 22 acyment@infra.cyment.com
```

### Check fail2ban status
```bash
sudo fail2ban-client status sshd
```

### View audit logs
```bash
sudo ausearch -k ssh_config_changes
```

### Check UFW status
```bash
sudo ufw status verbose
```

## Rollback

If something goes wrong, you can manually restore SSH access:
```bash
# From VPS console (not SSH)
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication yes
sudo systemctl restart ssh
```
