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
sudo apt update
sudo apt upgrade -y
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
    
    # Allow OpenSSH connections
    sudo ufw allow OpenSSH
    
    # Enable the firewall (with confirmation prompt disabled)
    sudo ufw --force enable
    
    echo -e "${GREEN}UFW firewall installed and configured.${NC}"
else
    echo -e "${BLUE}Skipping UFW installation.${NC}"
fi
echo

# Step 3: Configure SSH
echo -e "${YELLOW}Applying secure SSH configurations...${NC}"

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

sudo systemctl restart ssh.service
echo -e "${GREEN}SSH secured with best practices.${NC}"
echo -e "${RED}NOTE: Make sure you have working key-based authentication before disconnecting!${NC}"
echo

# Step 4: Set up Fail2ban
echo -e "${YELLOW}Configuring Fail2ban...${NC}"
echo -e "[sshd]\nenabled = true\nbanaction = iptables-multiport" | sudo tee /etc/fail2ban/jail.local

sudo systemctl enable fail2ban.service
sudo systemctl start fail2ban.service
echo -e "${GREEN}Fail2ban configured and enabled.${NC}"
echo

# Step 5: Configure Unattended-Upgrades
echo -e "${YELLOW}Setting up unattended-upgrades...${NC}"
sudo sed -i 's|// "${distro_id}:${distro_codename}-updates";|"${distro_id}:${distro_codename}-updates";|' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's|Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "true";|' /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot-Time "02:00";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades

echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Download-Upgradeable-Packages "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::AutocleanInterval "7";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades

sudo systemctl enable unattended-upgrades.service
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
echo -e "${GREEN}Unattended-upgrades configured.${NC}"
echo

# Step 6: Perform final update and upgrade
echo -e "${YELLOW}Performing final system update and upgrade...${NC}"
sudo apt update
sudo apt upgrade -y --allow-downgrades --allow-remove-essential --allow-change-held-packages
echo -e "${GREEN}Final system update complete.${NC}"
echo

# Step 7: Reboot system (optional)
read -p "Do you want to reboot the system now to apply all changes? (y/n): " reboot_system
if [[ $reboot_system =~ ^[Yy]$ ]]; then
    echo -e "${RED}Rebooting system in 5 seconds...${NC}"
    sleep 5
    sudo reboot
else
    echo -e "${BLUE}Skipping reboot. Please reboot manually later to apply all changes.${NC}"
    echo -e "${GREEN}Server setup complete!${NC}"
fi
