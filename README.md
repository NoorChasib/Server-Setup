# Server Setup Script

Automatically configure a new Ubuntu 24.04 LTS server with secure defaults. This script streamlines the process of hardening a fresh server with security best practices and essential configurations.

## Secure Install Method

For additional security, download and verify the script before running:

1. Download the script:

```bash
curl -fsSL -o server-setup.sh https://raw.githubusercontent.com/NoorChasib/Server-Setup/main/server-setup.sh
```

2. Verify the script contents:

```bash
less server-setup.sh
```

3. Make it executable:

```bash
chmod +x server-setup.sh
```

4. Run the script with sudo:

```bash
sudo ./server-setup.sh
```

## Features in Detail

### System Updates

- Performs a comprehensive system update using `apt update && apt full-upgrade`
- Removes unused packages with `apt autoremove`
- Cleans package cache with `apt clean`

### Essential Security Tools

- **fail2ban**: Protects against brute force attacks
- **curl**: Tool for transferring data with URLs
- **ca-certificates**: Common CA certificates for SSL
- **unattended-upgrades**: Automatic security updates
- **qemu-guest-agent**: Improves VM management (if running in a VM)
- **nfs-common**: NFS client for network filesystems

### SSH Hardening

- Creates a backup of your original SSH config
- Restricts root login to key-based authentication only (`prohibit-password`)
- Enforces key-based authentication and disables password login
- Limits authentication attempts to 3 before disconnecting
- Sets client timeout parameters (300 seconds)
- Disables challenge-response authentication

### Fail2ban Configuration

- Protects SSH against brute force attacks
- Bans IP addresses after 3 failed login attempts
- Sets a 5-minute window for tracking failed attempts
- Applies a 1-hour ban time for violators

### Automatic Updates

- Configures unattended-upgrades for automatic security updates
- Enables automatic security and regular updates
- Schedules automatic reboots at 2:00 AM when necessary
- Configures automatic removal of unused dependencies
- Sets up regular package list updates and cleanup

### System Hardening

- Applies kernel-level security parameters
- Enables IP spoofing protection
- Blocks broadcast ICMP requests
- Disables source packet routing
- Prevents redirect packet attacks
- Configures SYN flood protection
- Enables logging of suspicious network packets

## Interactive Options

The script will prompt you for the following options:

### 1. Tailscale Installation

```bash
Do you want to install Tailscale? (y/n)
```

**What it does:**

- If yes, installs Tailscale for secure, zero-config VPN
- Provides secure access to your server from anywhere
- Creates a private network between your devices

### 2. Docker Installation

```bash
Do you want to install Docker? (y/n)
```

**What it does:**

- Installs Docker Engine, CLI, containerd, and Docker Compose
- Sets up Docker to start automatically on boot
- Adds your user to the Docker group for passwordless Docker access
- Configures the official Docker repository for updates

### 3. SSH Key Addition

```bash
Do you want to add an SSH key to authorized_keys? (y/n)
```

If yes, it will ask:

```bash
Add SSH key to root user? (y/n)
```

If no, it will ask:

```bash
Enter the username to add the SSH key for:
```

Then:

```bash
Enter the SSH public key (paste the entire key):
```

**What it does:**

- Adds your SSH public key to the specified user's authorized_keys file
- Sets proper permissions and ownership on SSH directories and files
- Allows immediate key-based authentication for the specified user

### 4. UFW Firewall Configuration

```bash
Do you want to set up UFW firewall? (y/n)
```

**What it does if enabled:**

- Installs and configures Uncomplicated Firewall (UFW)
- Sets default policies to deny all incoming and allow all outgoing connections
- Explicitly allows SSH connections
- If Tailscale was installed, allows Tailscale traffic
- Enables the firewall with safe defaults

### 5. System Reboot

```bash
Do you want to reboot the system now to apply all changes? (y/n)
```

**Why this matters:**

- Some security changes require a reboot to fully take effect
- Ensures all configurations are properly applied
- If declined, you should manually reboot later

## After Running the Script

After completion, the script will:

1. Provide a summary of all configurations applied
2. List next steps for any additional configuration needed
3. Display commands to check the status of installed services

### Recommended Next Steps

- Check firewall status with: `sudo ufw status`
- Verify fail2ban is working: `sudo fail2ban-client status`
- If you installed Tailscale, check its status: `sudo tailscale status`
- If you installed Docker, log out and back in to use Docker without sudo
- Consider rebooting to ensure all changes are applied

## Compatibility

This script is designed for:

- Ubuntu 24.04 LTS
- May work with minimal modifications on other recent Ubuntu/Debian-based distributions

## Important Security Note

Running scripts directly from the internet always carries some security risk. This script will:

- Make significant changes to your system configuration
- Require root (sudo) privileges
- Modify critical security settings

Always read and understand scripts before executing them, especially with elevated privileges.

## License

MIT License - Feel free to modify and distribute as needed.

## Feedback and Contributions

Feedback and pull requests are welcome to improve this script. Please test thoroughly on a non-production system before using in production environments.
