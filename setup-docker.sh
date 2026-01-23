#!/usr/bin/env bash
set -euo pipefail

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

#usermod -aG docker $USER

########################################
# DONE
########################################
echo "✅ Docker setup complete!"
echo "ℹ️ Re-login required for docker group"
echo "ℹ️ To use docker by non root user run: sudo usermod -aG docker <non_root_user>"
echo "ℹ️ See: https://docs.docker.com/engine/install/linux-postinstall#manage-docker-as-a-non-root-user"
