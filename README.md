# VPS Setup

If you want to set up a production ready VPS, there are a few steps you should take.

This document goes through the list of steps that I personally take.

References:
    
- [Setting up a Production-Ready VPS from Scratch](https://blog.dreamsofcode.io/setting-up-a-production-ready-vps-is-a-lot-easier-than-i-thought) - Blog post
- [Setting up a production ready VPS is a lot easier than I thought.](https://www.youtube.com/watch?v=F-9KWQByeU0) - YouTube
- [Setting up a production ready VPS is a lot easier than I thought.](https://dreamsofcode.io/blog/setting-up-a-production-ready-vps-from-scratch) - Blog post
- [vps-setup.md](https://github.com/dreamsofcode-io/zenstats/blob/main/docs/vps-setup.md) - github.com/dreamsofcode-io

## Set Up VPS using scripts

Provisions a Linux VPS with Docker, security hardening, and an application
user. Safe to run multiple times (idempotent).

> ℹ️
> - Re-running those scripts will NOT duplicate users, keys, or services
> - SSH keys from the root will be copied to NEW_USER

### Requirements

- Run as root (or via sudo)
- Ubuntu / Debian based system
- Internet access

### Environment variables

1. `NEW_USER` - (Required) - Name of the application user to create
2. `NEW_USER_PASSWORD` - (Required) - Password for the application user
3. `SSH_PORT` - (Optional) - SSH port (default: 22)
4. `SWAP_SIZE` - (Optional) - Swap size (example: 2G)

### Usage

#### 1. Log in as root

```
ssh -i ~/.ssh/id_ed25519 root@<server-ip>
```

#### 2. Run the setup script

```
curl -fsSL https://raw.githubusercontent.com/tmsperera/vps-setup/refs/heads/main/setup-vps.sh | sudo -E \
NEW_USER="appuser" \
NEW_USER_PASSWORD="secret" \
SSH_PORT=22 \
SWAP_SIZE=2G \
bash
```

> [tmsperera/vps-setup/setup-vps.sh](https://github.com/tmsperera/vps-setup/blob/main/setup-vps.sh)

#### 3. Install Docker (Optional)

1. Install Docker and start the service

   ```
   curl -fsSL https://raw.githubusercontent.com/tmsperera/vps-setup/refs/heads/main/setup-docker.sh | sudo -E bash
   ```

   > 🔗 [https://docs.docker.com/engine/install/ubuntu/](https://docs.docker.com/engine/install/ubuntu/)

2. Allowing managing Docker as a non-root user

   ```
   sudo usermod -aG docker <non_root_user>
   ```

   > 🔗 [https://docs.docker.com/engine/install/linux-postinstall](https://docs.docker.com/engine/install/linux-postinstall)

#### 4. Install Git (Optional)
   ```
   sudo apt install git
   ```

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

