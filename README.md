# Server Setup Script

## Overview

This script automates the initial security hardening and setup process for a new server, primarily targeting Ubuntu 24.04 LTS. It updates the system, installs essential security tools, configures SSH, sets up automatic updates, applies system hardening rules, and optionally installs Tailscale, Docker, UFW, Fail2ban, CrowdSec, and an additional SSH key.

## Features

- **System Updates:** Performs a full system update and package cleanup.
- **Essential Tools:** Installs fundamental packages like `curl`, `ca-certificates`, `unattended-upgrades`, `qemu-guest-agent`, and `nfs-common`.
- **SSH Hardening:** Secures SSH access by disabling password authentication, enforcing key-based login, and limiting root login.
- **Automatic Updates:** Configures `unattended-upgrades` for automatic installation of security updates.
- **System Hardening:** Applies kernel-level security settings via `sysctl` (e.g., IP spoofing protection, ICMP broadcast ignore, SYN flood protection).
- **Optional Tailscale:** Prompts to install the Tailscale VPN client.
- **Optional Docker:** Prompts to install Docker Engine.
- **Optional UFW Firewall:** Prompts to install and configure the Uncomplicated Firewall (UFW) with safe defaults (deny incoming, allow outgoing, allow SSH).
- **Optional Fail2ban:** Prompts to install and configure Fail2ban to protect SSH from brute-force attacks.
- **Optional CrowdSec:** Prompts to install the CrowdSec agent, optionally change its API port, and optionally install the nftables firewall bouncer for active threat blocking.
- **Optional SSH Key Addition:** Prompts to add a provided SSH public key to the specified user's `authorized_keys` file.

## Compatibility

- Designed primarily for **Ubuntu 24.04 LTS**.
- May work with minimal modifications on other recent Debian/Ubuntu-based distributions.

## Usage

1. **Ensure server is up to date:**

```bash
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove && sudo apt clean
```

2. **Download the script:**

```bash
curl -fsSL -o server-setup.sh https://raw.githubusercontent.com/NoorChasib/Server-Setup/main/server-setup.sh
```

3. **Make it executable:**

```bash
chmod +x server-setup.sh
```

4. **Run the script with sudo:**

```bash
sudo ./server-setup.sh
```

## Interactive Options

The script will prompt you for the following:

1.  **Install Tailscale? (y/n):** Installs Tailscale VPN client if 'y'.
2.  **Install Docker? (y/n):** Installs Docker Engine if 'y'.
3.  **Install UFW? (y/n):** Installs and configures UFW firewall if 'y'. Allows SSH and Tailscale (if installed) traffic.
4.  **Install Fail2ban? (y/n):** Installs and configures Fail2ban for SSH protection if 'y'.
5.  **Install CrowdSec? (y/n):** Installs the CrowdSec agent if 'y'.
    - If CrowdSec is installed, asks **Change CrowdSec Port? (y/n):** Prompts for a new port and updates config if 'y'.
    - If CrowdSec is installed, asks **Install CrowdSec Bouncer? (y/n):** Installs the `crowdsec-firewall-bouncer-nftables` package if 'y'.
6.  **Add SSH Key? (y/n):**
    - If 'y', asks for the username and whether to add the key for the root user.
    - Prompts you to paste your SSH public key. Adds the key to the appropriate `authorized_keys` file.
7.  **Reboot Now? (y/n):** Asks if you want to reboot immediately to apply all changes. Requires confirming you've checked essential services first.

## Features in Detail

### System Updates

- Performs a comprehensive system update using `apt update && apt full-upgrade`.
- Removes unused packages with `apt autoremove`.
- Cleans package cache with `apt clean`.

### Essential Security Tools

- Installs `curl`, `ca-certificates`, `unattended-upgrades`, `qemu-guest-agent`, `nfs-common`.

### SSH Hardening

- Creates a backup of your original SSH config (`sshd_config`).
- Restricts root login to key-based authentication only (`PermitRootLogin prohibit-password`).
- Enforces key-based authentication (`PubkeyAuthentication yes`) and disables password login (`PasswordAuthentication no`).
- Limits authentication attempts (`MaxAuthTries 3`).
- Sets client timeout parameters (`ClientAliveInterval`, `ClientAliveCountMax`).
- Disables challenge-response authentication.

### Automatic Updates (Unattended Upgrades)

- Configures `unattended-upgrades` for automatic security updates via `/etc/apt/apt.conf.d/20auto-upgrades` and `/etc/apt/apt.conf.d/50unattended-upgrades`.
- Enables automatic package list updates, download of upgradeable packages, and the unattended upgrade process itself.
- Configures automatic cleanup of old packages (`AutocleanInterval "7"`).
- Enables the `unattended-upgrades.service`.

### System Hardening (Sysctl)

- Applies kernel parameters via `/etc/sysctl.d/99-security-hardening.conf` (created from a temporary file).
- Enables IP spoofing protection (`rp_filter`).
- Blocks broadcast ICMP requests (`icmp_echo_ignore_broadcasts`).
- Disables source packet routing (`accept_source_route`).
- Disables sending/accepting ICMP redirects to prevent MITM attacks.
- Configures SYN flood protection (`tcp_syncookies`, `tcp_max_syn_backlog`, etc.).
- Enables logging of suspicious network packets (`log_martians`).

### Tailscale Configuration (Optional)

- Installed only if the user confirms.
- Sets up Tailscale to start automatically on boot.
- Adds your user to the Tailscale group for passwordless Tailscale access.
- Configures Tailscale to start automatically on boot.

### Docker Configuration (Optional)

- Installed only if the user confirms.
- Sets up Docker to start automatically on boot.
- Adds your user to the Docker group for passwordless Docker access.
- Configures the official Docker repository for updates.

### UFW Firewall Configuration (Optional)

- Installed only if the user confirms.
- Sets default policies to deny incoming and allow outgoing traffic.
- Explicitly allows SSH connections.
- If Tailscale was installed, allows Tailscale traffic.
- Enables the firewall.

### Fail2ban Configuration (Optional)

- Installed only if the user confirms.
- Protects SSH against brute force attacks.
- Configures a jail for `sshd`.
- Bans IP addresses after 3 failed login attempts (`maxretry = 3`) within a 5-minute window (`findtime = 300`).
- Applies a 1-hour ban time (`bantime = 3600`).

### CrowdSec Installation (Optional)

- Installed only if the user confirms.
- Uses the official `install.crowdsec.net` script and `apt`.
- Optionally allows changing the default API port (8080) in relevant config files (`/etc/crowdsec/config.yaml`, `/etc/crowdsec/local_api_credentials.yaml`) via `sed`.
- Optionally installs `crowdsec-firewall-bouncer-nftables` via `apt` for active blocking if confirmed by the user.
- Enables and starts/restarts `crowdsec.service` and `crowdsec-firewall-bouncer.service` (if installed).

### SSH Key Configuration (Optional)

- If 'y', asks for the username and whether to add the key for the root user.
- Prompts you to paste your SSH public key. Adds the key to the appropriate `authorized_keys` file.

## Recommended Optional Install Configuration

- **Tailscale:** Yes
- **Docker:** Yes
- **UFW:** No
- **Fail2ban:** No
- **CrowdSec:** Yes
- **SSH Key:** Optional

## After Running the Script

The script will provide a summary of the configurations applied.

### Recommended Next Steps & Checks

- **Tailscale:** If installed, check status: `sudo tailscale status`.
- **Docker:** If installed, log out and back in to use Docker without `sudo`. Check status: `sudo systemctl status docker`.
- **UFW Firewall:** Check UFW status: `sudo ufw status`.
- **Fail2ban:** If installed, check status: `sudo fail2ban-client status` or `sudo systemctl status fail2ban`.
- **CrowdSec:** If installed, check status: `sudo systemctl status crowdsec` and `sudo cscli metrics`.
  - **Enrol your engine on the CrowdSec Hub:** `sudo cscli console enroll <your_enroll_key>`.
- **CrowdSec Bouncer:** If installed, check status: `sudo systemctl status crowdsec-firewall-bouncer`. Consider enrolling: `sudo cscli console enroll <your_enroll_key>`.
- **SSH:** Ensure you can log in with your SSH key _before_ logging out of your current session, especially if you added a key.
- **Reboot:** Consider rebooting if you skipped the prompt or if recommended.

## Cleanup

**Remove the script after running:**

```bash
rm -rf server-setup.sh
```

## Important Security Note

Running scripts directly from the internet, especially with `sudo`, carries risks.

- This script makes significant changes to system configuration and security settings.
- **Always review and understand scripts before executing them**.

## License

MIT License - Feel free to modify and distribute as needed.

## Feedback and Contributions

Feedback and pull requests are welcome to improve this script. Please test thoroughly on a non-production system before using in production environments.
