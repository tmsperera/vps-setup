#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# VPS SETUP SCRIPT (Idempotent)
# ------------------------------------------------------------------------------
#
# DESCRIPTION:
#   Provisions a Linux VPS with Docker, security hardening, and an application
#   user. Safe to run multiple times (idempotent).
#
# REQUIREMENTS:
#   - Run as root (or via sudo)
#   - Ubuntu / Debian based system
#   - Internet access
#
# REQUIRED ENVIRONMENT VARIABLES:
#   APP_USER            Name of the application user to create
#   APP_USER_PASSWORD   Password for the application user
#
# OPTIONAL ENVIRONMENT VARIABLES:
#   SSH_PORT            SSH port (default: 22)
#   SWAP_SIZE           Swap size (example: 2G)
#
# USAGE (recommended):
#   curl -fsSL <SCRIPT_URL> | sudo -E \
#     APP_USER="appuser" \
#     APP_USER_PASSWORD="StrongPasswordHere" \
#     SSH_PORT=22 \
#     SWAP_SIZE=2G \
#     bash
#
# EXAMPLE:
#   curl -fsSL https://example.com/setup-vps.sh | sudo -E \
#     APP_USER="appuser" \
#     APP_USER_PASSWORD="220{}290><?Q" \
#     SSH_PORT=22 \
#     SWAP_SIZE=2G \
#     bash
#
# NOTES:
#   - Re-running this script will NOT duplicate users, keys, or services
#   - SSH keys from root will be copied to APP_USER
#
# ------------------------------------------------------------------------------

set -euo pipefail

########################################
# CONFIG
########################################
: "${APP_USER:=appuser}"
: "${APP_USER_PASSWORD:?APP_USER_PASSWORD is required}"
: "${SSH_PORT:=22}"
: "${SWAP_SIZE:=2G}"

########################################
# ROOT CHECK
########################################
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

########################################
# APT VERSION CHECK (deb822 support)
########################################
MIN_APT_MAJOR=2
MIN_APT_MINOR=5

APT_VERSION=$(apt --version | awk '{print $2}')
APT_MAJOR=${APT_VERSION%%.*}
APT_MINOR=$(echo "$APT_VERSION" | cut -d. -f2)

if (( APT_MAJOR < MIN_APT_MAJOR )) || \
   (( APT_MAJOR == MIN_APT_MAJOR && APT_MINOR < MIN_APT_MINOR )); then
  echo "❌ Your APT version is $APT_VERSION, but this script requires >= $MIN_APT_MAJOR.$MIN_APT_MINOR"
  exit 1
fi

echo "🚀 Starting VPS setup..."

########################################
# SWAP
########################################
if swapon --show | grep -q "/swapfile"; then
  echo "✅ Swap already exists"
else
  echo "➕ Creating swap (${SWAP_SIZE})..."

  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  if ! grep -q "^/swapfile" /etc/fstab; then
    # Make swap permanent
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
  fi
fi

########################################
# USER
########################################
if ! id "$APP_USER" &>/dev/null; then
  echo "👤 Creating user: $APP_USER"

  adduser --disabled-password --gecos "" --shell /bin/bash "$APP_USER"
  echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
  usermod -aG sudo "$APP_USER"
else
  echo "✅ User $APP_USER already exists"
fi

########################################
# SSH KEYS (DEDUPED)
########################################
echo "🔐 Configuring SSH access..."

install -d -m 700 /home/"$APP_USER"/.ssh
install -m 600 /dev/null /home/"$APP_USER"/.ssh/authorized_keys

if [ -f /root/.ssh/authorized_keys ]; then
  sort -u \
    /root/.ssh/authorized_keys \
    /home/"$APP_USER"/.ssh/authorized_keys \
    > /tmp/authorized_keys.tmp

  mv /tmp/authorized_keys.tmp /home/"$APP_USER"/.ssh/authorized_keys
fi

chown -R "$APP_USER":"$APP_USER" /home/"$APP_USER"/.ssh

########################################
# SSH HARDENING
########################################
echo "🛡️ Hardening SSH..."

config_sshd () {
  local key="$1"
  local value="$2"
  if grep -q "^[[:space:]]*#\?$key" /etc/ssh/sshd_config; then
    sed -i "s|^[[:space:]]*#\?$key.*|$key $value|" /etc/ssh/sshd_config
  else
    echo "$key $value" >> /etc/ssh/sshd_config
  fi
}

config_sshd PermitRootLogin no
config_sshd PasswordAuthentication no
config_sshd Port "$SSH_PORT"

sshd -t
systemctl restart ssh

########################################
# FAIL2BAN
########################################
echo "🔒 Installing Fail2Ban..."

apt install -y fail2ban

systemctl enable fail2ban
systemctl start fail2ban

F2B_SSH_JAIL="/etc/fail2ban/jail.d/sshd.local"

if [ ! -f "$F2B_SSH_JAIL" ]; then
  cat > "$F2B_SSH_JAIL" <<EOF
[sshd]
enabled = true
port = ssh
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
else
  echo "✅ Fail2Ban SSH jail already exists"
fi

systemctl restart fail2ban

########################################
# SETUP FIREWALL
########################################
echo "🔥 Configuring UFW..."

apt update -y
apt install -y ufw

ufw allow "$SSH_PORT/tcp"
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

########################################
# INSTALL GIT
########################################
echo "📦 Installing Git..."

apt install -y git

########################################
# INSTALL DOCKER
########################################
if command -v docker >/dev/null 2>&1; then
  echo "✅ Docker already installed"
else
  echo "🐳 Installing Docker..."

  # Add Docker's official GPG key:
  apt update
  apt install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt update

  # Install docker latest version
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Enable and start Docker service
  systemctl enable docker
  systemctl start docker
fi

########################################
# DOCKER GROUP
########################################
usermod -aG docker "$APP_USER"

########################################
# DONE
########################################
echo "✅ VPS setup complete!"
echo "➡️ ssh -p ${SSH_PORT} ${APP_USER}@<server-ip>"
echo "ℹ️ Re-login required for docker group"
