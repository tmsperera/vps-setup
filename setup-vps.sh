#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################
: "${NEW_USER:=appuser}"
: "${NEW_USER_PASSWORD:?NEW_USER_PASSWORD is required}"
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
if ! id "$NEW_USER" &>/dev/null; then
  echo "👤 Creating user: $NEW_USER"

  adduser --disabled-password --gecos "" --shell /bin/bash "$NEW_USER"
  echo "$NEW_USER:$NEW_USER_PASSWORD" | chpasswd
  usermod -aG sudo "$NEW_USER"
else
  echo "✅ User $NEW_USER already exists"
fi

########################################
# SSH KEYS (DEDUPED)
########################################
echo "🔐 Configuring SSH access..."

install -d -m 700 /home/"$NEW_USER"/.ssh
install -m 600 /dev/null /home/"$NEW_USER"/.ssh/authorized_keys

if [ -f /root/.ssh/authorized_keys ]; then
  sort -u \
    /root/.ssh/authorized_keys \
    /home/"$NEW_USER"/.ssh/authorized_keys \
    > /tmp/authorized_keys.tmp

  mv /tmp/authorized_keys.tmp /home/"$NEW_USER"/.ssh/authorized_keys
fi

chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh

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
config_sshd Port "${SSH_PORT}"

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

# Disable all incoming traffic by default
ufw default deny incoming

# Allow all outgoing traffic by default
ufw default allow outgoing

# Allow SSH (CRITICAL - do this before enabling the firewall)
ufw allow "${SSH_PORT}/tcp"

ufw allow 80/tcp
ufw allow 443/tcp

# Enable the firewall
ufw --force enable

########################################
# DONE
########################################
echo "✅ VPS setup complete!"
echo "➡️ ssh -p ${SSH_PORT} ${NEW_USER}@<server-ip>"
