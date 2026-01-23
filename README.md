# VPS Setup

If you want to set up a production ready VPS, there are a few steps you should take.

This document goes through the list of steps that I personally take.

References:
    
- [Setting up a production ready VPS is a lot easier than I thought.](https://blog.dreamsofcode.io/setting-up-a-production-ready-vps-is-a-lot-easier-than-i-thought) - blog
- [Setting up a production ready VPS is a lot easier than I thought.](https://www.youtube.com/watch?v=F-9KWQByeU0) - youtube
- [vps-setup.md](https://github.com/dreamsofcode-io/zenstats/blob/main/docs/vps-setup.md) by github.com/dreamsofcode-io

## Set Up VPS using one time Script

Provisions a Linux VPS with Docker, security hardening, and an application
user. Safe to run multiple times (idempotent).

### Requirements

- Run as root (or via sudo)
- Ubuntu / Debian based system
- Internet access

### Required environment variables

1. `APP_USER` - Name of the application user to create
2. `APP_USER_PASSWORD` - Password for the application user

### Optional environment variables

1. `SSH_PORT` - SSH port (default: 22)
2. `SWAP_SIZE` - Swap size (example: 2G)

### Usage (recommended):

```
curl -fsSL <SCRIPT_URL> | sudo -E \
    APP_USER="appuser" \
    APP_USER_PASSWORD="StrongPasswordHere" \
    SSH_PORT=22 \
    SWAP_SIZE=2G \
    bash
```

1. Log in as root
    ```
    ssh -i ~/.ssh/id_ed25519 root@<server-ip>
    ```

2. Run the setup script

    > [tmsperera/vps-setup/setup.sh](https://github.com/tmsperera/vps-setup/blob/main/setup.sh)

    ```
    curl -fsSL https://raw.githubusercontent.com/tmsperera/vps-setup/refs/heads/main/setup.sh | sudo -E \
    APP_USER="appuser" \
    APP_USER_PASSWORD="secret" \
    SSH_PORT=22 \
    SWAP_SIZE=2G \
    bash
    ```

> NOTES:
> - Re-running this script will NOT duplicate users, keys, or services
> - SSH keys from root will be copied to APP_USER

## Manually Set Up VPS

Reference: [vps-setup.md](https://github.com/dreamsofcode-io/zenstats/blob/main/docs/vps-setup.md) by github.com/dreamsofcode-io

### 1. Create a New User with Sudo Permissions:

1. Log in as root
    ```
    ssh -i ~/.ssh/walt/id_ed25519 root@<server-ip>
    ```
2. Create a new user with a strong password
    ```
    adduser appuser
    ```
3. Add the user to the sudo group
    ```
    usermod -aG sudo appuser
    ```

### 2. Set Up SSH for new user:

1. Switch to new user
    ```
    su - appuser
    ```
2. Generate an SSH key pair
    ```
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```
3. Copy local SSH Public key to the new user on the server
   ```
   echo "[local-public-key]" >> ~/.ssh/authorized_keys
   ```

### 3. Harden SSH

1. Reconnect as the new user
   ```
   ssh -i ~/.ssh/walt/host/id_ed25519 appuser@<server-ip>
   ```
2. Open the SSH configuration file
   ```
   sudo nano /etc/ssh/sshd_config
   ```
3. Modify the following in the file:
   ```
   PermitRootLogin no # Disable root login
   PasswordAuthentication no  # Disable password based auth
   ```
4. Restart SSH service
   ```
   sudo systemctl restart ssh
   ```
5. Test SSH with new settings before logging out
   ```
   ssh appuser@<server-ip>
   ```

### 4. Set Up a Firewall (UFW)

1. Install UFW if not already installed
    ```
    sudo apt install ufw
    ```
2. Allow necessary ports
    ```
    sudo ufw allow OpenSSH    # SSH
    sudo ufw allow 80/tcp     # HTTP
    sudo ufw allow 443/tcp    # HTTPS
    ```
3. Enable UFW
    ```
    sudo ufw enable
    ```
4. Check UFW status
    ```
    sudo ufw status
    ```

### 5. (Optional) Install and Configure Fail2Ban

1. Install Fail2Ban
    ```
   sudo apt install fail2ban
   ```
2. Create a local configuration file
    ```
   sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
   ```
3. Edit Fail2Ban configuration for SSH: `sudo nano /etc/fail2ban/jail.local`
   ```
   [sshd]
   enabled = true
   port = 22 # Change this if you've modified your SSH port.
   maxretry = 5
   bantime = 3600
   ```
4. Restart Fail2Ban service
   ```
   sudo systemctl restart fail2ban
   ```
5. Check Fail2Ban status
   ```
   sudo fail2ban-client status
   sudo fail2ban-client status sshd
   ```

