#!/usr/bin/env bash
# Prepare an existing DGX OS installation without replacing its NVIDIA stack.
# Run on DGX: sudo bash prepare-host.sh LOGIN_USER
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
login_user="${1:-}"
[ "$(id -u)" = 0 ] || fail "Run with sudo."
[[ "$login_user" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail "Specify the existing login user."
id "$login_user" >/dev/null || fail "The login user does not exist."
[ "$(id -u "$login_user")" -ge 1000 ] || fail "Use a non-system login user."
[ "$(uname -m)" = aarch64 ] || fail "This script is for an ARM64 DGX Spark."
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = ubuntu ] && [ "${VERSION_CODENAME:-}" = noble ] \
    || fail "Expected Ubuntu 24.04 (noble) DGX OS."
nvidia-smi >/dev/null || fail "Repair the NVIDIA driver through DGX OS first."
docker version >/dev/null || fail "The preinstalled Docker daemon is unavailable."
docker compose version >/dev/null || fail "Install the Docker Compose plugin first."
nvidia-ctk --version >/dev/null || fail "The NVIDIA Container Toolkit is unavailable."
command -v curl >/dev/null || fail "Install curl before running this script."
getent group docker >/dev/null || fail "The Docker group is missing."

if ! command -v tailscale >/dev/null || ! systemctl cat tailscaled.service >/dev/null 2>&1; then
    echo "Installing Tailscale from its signed Ubuntu noble repository."
    package_directory=$(mktemp -d /tmp/doglyad-tailscale.XXXXXX)
    trap 'rm -rf -- "$package_directory"' EXIT
    curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 \
        https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
        -o "$package_directory/tailscale-archive-keyring.gpg"
    curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 \
        https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
        -o "$package_directory/tailscale.list"
    install -m 0644 "$package_directory/tailscale-archive-keyring.gpg" /usr/share/keyrings/tailscale-archive-keyring.gpg
    install -m 0644 "$package_directory/tailscale.list" /etc/apt/sources.list.d/tailscale.list
    apt-get -o DPkg::Lock::Timeout=300 update
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y tailscale
fi

systemctl enable --now docker tailscaled
docker volume create doglyad-dgx-huggingface >/dev/null
usermod -aG docker "$login_user"
# The trusted login user can authenticate/manage this device without another sudo prompt.
tailscale set --operator="$login_user"

for directory in /opt/doglyad /opt/doglyad/inference; do
    [ ! -L "$directory" ] || fail "Refusing a symbolic link at $directory."
    if [ ! -d "$directory" ]; then
        install -d -o "$login_user" -g docker -m 2770 "$directory"
    fi
done

echo "Host preparation completed. NVIDIA packages and existing containers were preserved."
echo "New SSH sessions receive Docker group access."
echo "Next: authenticate this DGX in the project's Tailscale network."
