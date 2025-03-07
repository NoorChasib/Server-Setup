#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}        AUTOMATED SERVER SETUP         ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "This script will configure your server with secure defaults."
echo

# Step 1: Update and upgrade the system
echo -e "${YELLOW}Updating and upgrading system packages...${NC}"
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove && sudo apt clean
echo -e "${GREEN}System packages updated.${NC}"
echo

# Step 2: Install required packages
echo -e "${YELLOW}Installing base required packages...${NC}"
sudo apt install -y fail2ban curl ca-certificates unattended-upgrades qemu-guest-agent nfs-common
echo -e "${GREEN}Base packages installed.${NC}"
echo

# Optional: Install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing Tailscale...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
    echo -e "${GREEN}Tailscale installed. Use 'sudo tailscale up' to connect to your tailnet.${NC}"
else
    echo -e "${BLUE}Skipping Tailscale installation.${NC}"
fi
echo

# Optional: Configure UFW
read -p "Do you want to set up UFW firewall? (y/n): " install_ufw
if [[ $install_ufw =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing and configuring UFW firewall...${NC}"
    sudo apt install -y ufw
    
    # Reset UFW to default settings
    sudo ufw reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow OpenSSH connections
    sudo ufw allow OpenSSH
    
    # If Tailscale was installed, configure UFW for Tailscale
    if [[ $install_tailscale =~ ^[Yy]$ ]]; then
        # Allow incoming Tailscale traffic
        sudo ufw allow in on tailscale0
    fi
    
    # Enable the firewall (with confirmation prompt disabled)
    sudo ufw --force enable
    
    # Reload UFW rules
    sudo ufw reload
    
    echo -e "${GREEN}UFW firewall installed and configured.${NC}"
else
    echo -e "${BLUE}Skipping UFW installation.${NC}"
fi
echo

# Step 3: Configure SSH
echo -e "${YELLOW}Applying secure SSH configurations...${NC}"

# Create backup of SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply SSH hardening settings
sudo sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
echo "PermitRootLogin prohibit-password" | sudo tee -a /etc/ssh/sshd_config

sudo sed -i '/PubkeyAuthentication/d' /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config

sudo sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config

sudo sed -i '/MaxAuthTries/d' /etc/ssh/sshd_config
echo "MaxAuthTries 3" | sudo tee -a /etc/ssh/sshd_config

sudo sed -i '/ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" | sudo tee -a /etc/ssh/sshd_config

# Add ClientAliveInterval settings
sudo sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 300" | sudo tee -a /etc/ssh/sshd_config

sudo sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
echo "ClientAliveCountMax 2" | sudo tee -a /etc/ssh/sshd_config

sudo systemctl restart ssh.service
echo -e "${GREEN}SSH secured with best practices.${NC}"
echo -e "${RED}NOTE: Make sure you have working key-based authentication before disconnecting!${NC}"
echo

# Step 4: Set up Fail2ban
echo -e "${YELLOW}Configuring Fail2ban...${NC}"

# Create a more comprehensive jail.local file
cat > /tmp/jail.local << 'EOF'
[sshd]
enabled = true
banaction = iptables-multiport
maxretry = 3
findtime = 300
bantime = 3600
EOF

sudo mv /tmp/jail.local /etc/fail2ban/jail.local

sudo systemctl enable fail2ban.service
sudo systemctl restart fail2ban.service
echo -e "${GREEN}Fail2ban configured and enabled.${NC}"
echo

# Step 5: Configure Unattended-Upgrades
echo -e "${YELLOW}Setting up unattended-upgrades...${NC}"

# Adjust configurations in `50unattended-upgrades`
sudo sed -i 's|// "${distro_id}:${distro_codename}-updates";|"${distro_id}:${distro_codename}-updates";|' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's|Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "true";|' /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot-Time "02:00";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades

# Configure periodic updates in `20auto-upgrades`
echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Download-Upgradeable-Packages "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::AutocleanInterval "7";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades

sudo systemctl enable unattended-upgrades.service
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
echo -e "${GREEN}Unattended-upgrades configured.${NC}"
echo

# Step 6: Configure System Hardening
echo -e "${YELLOW}Applying system hardening...${NC}"

# Create sysctl hardening configuration
cat > /tmp/99-security-hardening.conf << 'EOF'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sudo mv /tmp/99-security-hardening.conf /etc/sysctl.d/99-security-hardening.conf
sudo sysctl -p /etc/sysctl.d/99-security-hardening.conf
echo -e "${GREEN}System hardening applied.${NC}"
echo

# Step 7: Perform final update and upgrade
echo -e "${YELLOW}Performing final system update and upgrade...${NC}"
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove && sudo apt clean
echo -e "${GREEN}Final system update complete.${NC}"
echo

# Step 8: Summary and instructions
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}SERVER SECURITY SETUP COMPLETE!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "The following has been configured:"
echo -e " ? System packages updated"
echo -e " ? Essential security tools installed"
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
  echo -e " ? Tailscale installed"
fi
if [[ $install_ufw =~ ^[Yy]$ ]]; then
  echo -e " ? UFW firewall configured"
fi
echo -e " ? SSH hardened"
echo -e " ? Fail2ban configured"
echo -e " ? Unattended upgrades set up"
echo -e " ? System hardening applied"
echo
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. If you installed Tailscale, run: ${BLUE}sudo tailscale up${NC}"
echo -e "2. Check firewall status: ${BLUE}sudo ufw status${NC}"
echo -e "3. Verify fail2ban is working: ${BLUE}sudo fail2ban-client status${NC}"
echo

# Step 9: Reboot system (optional)
read -p "Do you want to reboot the system now to apply all changes? (y/n): " reboot_system
if [[ $reboot_system =~ ^[Yy]$ ]]; then
    echo -e "${RED}Rebooting system in 5 seconds...${NC}"
    sleep 5
    sudo reboot
else
    echo -e "${BLUE}Skipping reboot. Please reboot manually later to apply all changes.${NC}"
    echo -e "${GREEN}Server setup complete!${NC}"
fi
