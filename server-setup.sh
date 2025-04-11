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
sudo apt install -y curl ca-certificates unattended-upgrades qemu-guest-agent nfs-common
echo -e "${GREEN}Base packages installed.${NC}"
echo

# Step 3 (Optional): Install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing Tailscale...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
    echo -e "${GREEN}Tailscale installed. Use 'sudo tailscale up' to connect to your tailnet.${NC}"
else
    echo -e "${BLUE}Skipping Tailscale installation.${NC}"
fi
echo

# Step 4 (Optional): Install Docker
read -p "Do you want to install Docker? (y/n): " install_docker
if [[ $install_docker =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    
    # Add Docker's official GPG key
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    # Install the Docker packages
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Configure Docker to start on boot with systemd
    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service
    
    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" != "" ] && [ "$SUDO_USER" != "root" ]; then
        sudo usermod -aG docker $SUDO_USER
        echo -e "${GREEN}Added user $SUDO_USER to the docker group. Log out and back in to apply.${NC}"
    fi
    
    echo -e "${GREEN}Docker installed and configured.${NC}"
else
    echo -e "${BLUE}Skipping Docker installation.${NC}"
fi
echo

# Step 5 (Optional): Configure UFW
read -p "Do you want to install and configure UFW firewall? (y/n): " install_ufw
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

# Step 6 (Optional): Install Fail2ban
read -p "Do you want to install and configure Fail2ban? (y/n): " install_fail2ban
if [[ $install_fail2ban =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing and configuring Fail2ban...${NC}"
    # Install Fail2ban package
    sudo apt update # Good practice to update before install
    sudo apt install -y fail2ban

    # Create a more comprehensive jail.local file for sshd
    cat > /tmp/jail.local << 'EOF'
[sshd]
enabled = true
banaction = iptables-multiport
maxretry = 3
findtime = 300
bantime = 3600
EOF

    # Move the configuration file into place
    sudo mv /tmp/jail.local /etc/fail2ban/jail.local

    # Enable and restart the Fail2ban service
    sudo systemctl enable fail2ban.service
    sudo systemctl restart fail2ban.service
    echo -e "${GREEN}Fail2ban installed, configured, and enabled.${NC}"
else
    # Message if the user chooses not to install
    echo -e "${BLUE}Skipping Fail2ban installation.${NC}"
fi
echo # Add a blank line for better readability

# Step 7 (Optional): Install CrowdSec
read -p "Do you want to install CrowdSec? (y/n): " install_crowdsec
crowdsec_installed=false
if [[ $install_crowdsec =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing CrowdSec...${NC}"
    # Add CrowdSec repository and install
    curl -s https://install.crowdsec.net | sudo bash
    sudo apt update
    sudo apt install -y crowdsec

    # Ask to change default port
    read -p "CrowdSec installed. Do you want to change the default API port (8080)? (y/n): " change_crowdsec_port
    if [[ $change_crowdsec_port =~ ^[Yy]$ ]]; then
        read -p "Enter the new port number for CrowdSec API: " new_crowdsec_port
        # Validate if it's a number (basic check)
        if [[ "$new_crowdsec_port" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}Updating CrowdSec configuration files with port $new_crowdsec_port...${NC}"
            # Change port in config.yaml
            sudo sed -i "s/listen_uri: 127.0.0.1:8080/listen_uri: 127.0.0.1:$new_crowdsec_port/" /etc/crowdsec/config.yaml
            # Change port in local_api_credentials.yaml
            sudo sed -i "s|url: http://127.0.0.1:8080|url: http://127.0.0.1:$new_crowdsec_port|" /etc/crowdsec/local_api_credentials.yaml
            echo -e "${GREEN}CrowdSec ports updated.${NC}"
        else
            echo -e "${RED}Invalid port number entered. Using default port 8080.${NC}"
        fi
    fi

    # Start CrowdSec service
    echo -e "${YELLOW}Starting CrowdSec service...${NC}"
    sudo systemctl enable crowdsec.service
    sudo systemctl start crowdsec.service

    # Optionally install firewall bouncer
    read -p "Do you want to install the CrowdSec firewall bouncer (nftables)? (y/n): " install_bouncer
    if [[ $install_bouncer =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installing CrowdSec firewall bouncer...${NC}"
        sudo apt install -y crowdsec-firewall-bouncer-nftables
        echo -e "${YELLOW}Restarting CrowdSec services...${NC}"
        # Restart services after bouncer installation
        sudo systemctl restart crowdsec-firewall-bouncer.service
        sudo systemctl restart crowdsec.service
        echo -e "${GREEN}CrowdSec firewall bouncer installed and services restarted.${NC}"

        # Check status
        echo -e "${BLUE}Checking service status:${NC}"
        sudo systemctl status crowdsec --no-pager
        sudo systemctl status crowdsec-firewall-bouncer --no-pager
    else
        echo -e "${BLUE}Skipping CrowdSec firewall bouncer installation.${NC}"
        # If bouncer skipped, still ensure main service is running and check status
        echo -e "${BLUE}Checking CrowdSec service status:${NC}"
         sudo systemctl status crowdsec --no-pager
    fi

    echo -e "${GREEN}CrowdSec installation and configuration complete.${NC}"
    echo -e "${RED}REMINDER: You may need to enroll this CrowdSec engine instance on the CrowdSec Hub.${NC}"
    crowdsec_installed=true
else
    echo -e "${BLUE}Skipping CrowdSec installation.${NC}"
fi
echo

# Step 8 (Optional): Add SSH key
read -p "Do you want to add an SSH key to authorized_keys? (y/n): " add_ssh_key
if [[ $add_ssh_key =~ ^[Yy]$ ]]; then
    # Ask if adding to root
    read -p "Add SSH key to root user? (y/n): " add_to_root
    
    if [[ $add_to_root =~ ^[Yy]$ ]]; then
        # Adding to root
        ssh_username="root"
        ssh_dir="/root/.ssh"
    else
        # Ask for username
        read -p "Enter the username to add the SSH key for: " ssh_username
        ssh_dir="/home/$ssh_username/.ssh"
    fi
    
    # Get the SSH key
    echo "Enter the SSH public key (paste the entire key):"
    read ssh_public_key
    
    if [ -n "$ssh_public_key" ]; then
        # Create .ssh directory if it doesn't exist
        sudo mkdir -p $ssh_dir
        
        # Check if authorized_keys exists, if not create it
        if [ ! -f "$ssh_dir/authorized_keys" ]; then
            sudo touch $ssh_dir/authorized_keys
        fi
        
        # Add the key - simply append to the end
        echo "$ssh_public_key" | sudo tee -a $ssh_dir/authorized_keys > /dev/null
        
        # Set proper permissions
        sudo chmod 700 $ssh_dir
        sudo chmod 600 $ssh_dir/authorized_keys
        
        # Set proper ownership (only for non-root users)
        if [[ ! $add_to_root =~ ^[Yy]$ ]]; then
            sudo chown -R $ssh_username:$ssh_username $ssh_dir
        fi
        
        echo -e "${GREEN}SSH key added to $ssh_dir/authorized_keys${NC}"
    else
        echo -e "${RED}No SSH key provided. Skipping.${NC}"
    fi
else
    echo -e "${BLUE}Skipping SSH key addition.${NC}"
fi
echo

# Step 9: Configure SSH
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

# Step 10: Configure Unattended-Upgrades
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

# Step 11: Configure System Hardening
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

# Step 12: Perform final update and upgrade
echo -e "${YELLOW}Performing final system update and upgrade...${NC}"
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove && sudo apt clean
echo -e "${GREEN}Final system update complete.${NC}"
echo

# Step 13: Summary and instructions
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}SERVER SECURITY SETUP COMPLETE!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "The following has been configured:"
echo -e " - System packages updated"
echo -e " - Essential security tools installed"
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
  echo -e " - Tailscale installed"
fi
if [[ $install_docker =~ ^[Yy]$ ]]; then
  echo -e " - Docker installed"
fi
if [[ $install_ufw =~ ^[Yy]$ ]]; then
  echo -e " - UFW firewall configured"
fi
if [[ $add_ssh_key =~ ^[Yy]$ ]]; then
  if [[ $add_to_root =~ ^[Yy]$ ]]; then
    echo -e " - Added SSH key to root user"
  else
    echo -e " - Added SSH key to user: $ssh_username"
  fi
fi
echo -e " - SSH hardened"
if [[ $install_fail2ban =~ ^[Yy]$ ]]; then
  echo -e " - Fail2ban configured"
fi
if [[ "$crowdsec_installed" = true ]]; then
  echo -e " - CrowdSec installed and configured"
  if [[ $install_bouncer =~ ^[Yy]$ ]]; then
      echo -e "   - CrowdSec firewall bouncer installed"
  fi
fi
echo -e " - Unattended upgrades set up"
echo -e " - System hardening applied"
echo
if [[ "$crowdsec_installed" = true ]]; then
    echo -e "${RED}REMINDER: If you installed CrowdSec, remember to enroll this engine instance on the CrowdSec Hub.${NC}"
    echo
fi

echo -e "${YELLOW}IMPORTANT NEXT STEPS:${NC}"
echo -e "- To check firewall status: ${BLUE}sudo ufw status${NC}"
echo -e "- To verify fail2ban is working: ${BLUE}sudo fail2ban-client status${NC}"

if [[ $add_ssh_key =~ ^[Yy]$ ]]; then
  echo -e "- Verify SSH key was added correctly: ${BLUE}cat $ssh_dir/authorized_keys${NC}"
fi

if [[ $install_tailscale =~ ^[Yy]$ ]]; then
  echo -e "- To connect to Tailscale network: ${BLUE}sudo tailscale up${NC}"
fi

if [[ $install_docker =~ ^[Yy]$ ]]; then
  echo -e "- To use Docker without sudo, reboot the system to finalize changes."
fi
echo

# Step 14: Reboot system (optional) with simple confirmation of all steps
read -p "Do you want to reboot the system now to apply all changes? (y/n): " reboot_system
if [[ $reboot_system =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Before rebooting, please confirm you have:${NC}"
    
    echo -e "- Checked firewall status (if applicable)"
    echo -e "- Verified fail2ban is working"
    
    if [[ $add_ssh_key =~ ^[Yy]$ ]]; then
        echo -e "- Verified your SSH key works correctly"
    fi

    if [[ $install_tailscale =~ ^[Yy]$ ]]; then
        echo -e "- Connected to Tailscale network"
    fi
    
    echo
    read -p "Have you completed these steps? (y/n): " steps_completed
    
    if [[ $steps_completed =~ ^[Yy]$ ]]; then
        echo -e "${RED}Rebooting system in 5 seconds...${NC}"
        sleep 5
        sudo reboot
    else
        echo -e "${BLUE}Reboot canceled. Please complete the recommended steps first and reboot manually when ready.${NC}"
        echo -e "${GREEN}Server setup complete!${NC}"
    fi
else
    echo -e "${BLUE}Skipping reboot. Please reboot manually later to apply all changes.${NC}"
    echo -e "${GREEN}Server setup complete!${NC}"
fi
