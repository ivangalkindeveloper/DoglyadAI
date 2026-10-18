#!/usr/bin/env bash
#
# Prepares a fresh VM to run one of the services. Installs Docker, the private
# network agent, the GPU stack where it is needed, and lays out /opt/doglyad.
#
# Run on the VM as root, straight from the repository:
#
#   curl -fsSL --retry 10 --retry-all-errors --retry-delay 3 \
#     -o /tmp/doglyad-bootstrap.sh \
#     https://raw.githubusercontent.com/ivangalkindeveloper/DoglyadAI/master/deploy/bootstrap.sh
#   sudo bash /tmp/doglyad-bootstrap.sh main
#   sudo bash /tmp/doglyad-bootstrap.sh inference
#
# Or run it from the repository on your laptop without opening an interactive SSH
# session:
#
#   deploy/init-vm.sh inference LOGIN@HOST
#
# The cloud-init files call exactly this, so a provider with user-data and one
# without end up with the same machine. Safe to re-run: every step checks first.
#
# Deliberately stops short of starting anything. Secrets arrive separately through
# deploy/sync-secrets.sh, and without them the service would not come up anyway.

set -euo pipefail

RAW="https://raw.githubusercontent.com/ivangalkindeveloper/DoglyadAI/master/deploy"
TARGET_DIR="/opt/doglyad"
LOG_FILE="/var/log/doglyad-bootstrap.log"

usage() {
    echo "Usage: bootstrap.sh <main|inference>" >&2
    exit 1
}

log() { echo "==> $*"; }

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

download() {
    local url="$1"
    local destination="$2"

    curl -fsSL \
        --retry 10 \
        --retry-all-errors \
        --retry-delay 3 \
        --connect-timeout 20 \
        -o "$destination" \
        "$url"
}

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y "$@"
}

ROLE="${1:-}"
case "$ROLE" in
main | inference) ;;
*)
    [ -n "$ROLE" ] && echo "Unknown role: $ROLE (expected main or inference)" >&2 && echo >&2
    usage
    ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    fail "run as root: sudo bash bootstrap.sh $ROLE"
fi

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log "starting $ROLE bootstrap at $(date -Is)"

if [ ! -r /etc/os-release ]; then
    fail "/etc/os-release is missing; this bootstrap supports Ubuntu only"
fi
# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != ubuntu ]; then
    fail "unsupported operating system: ${ID:-unknown}; expected Ubuntu"
fi
if [ "$(dpkg --print-architecture)" != amd64 ]; then
    fail "unsupported architecture: $(dpkg --print-architecture); deployment images are amd64"
fi

TEMP_DIR="$(mktemp -d /tmp/doglyad-bootstrap.XXXXXX)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

# --- apt ---------------------------------------------------------------------
# A freshly booted Ubuntu runs unattended-upgrades, which holds the dpkg lock for
# a few minutes. Waiting is the only correct answer: removing the lock file or
# killing the process leaves a half-configured package manager behind.
log "waiting for the dpkg lock"
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    sleep 5
done

log "installing base packages"
apt-get -o DPkg::Lock::Timeout=300 update
apt_install ca-certificates curl gnupg

# --- Docker ------------------------------------------------------------------
# `docker` alone is not enough: every deployment command uses the Compose v2
# plugin. Some provider images ship the engine without it, so only skip the
# installation when the complete CLI we need is usable.
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "docker and the Compose plugin already present, skipping"
else
    if command -v docker >/dev/null 2>&1; then
        log "docker is present without the Compose plugin; completing the installation"
    else
        log "installing docker"
    fi
    download https://get.docker.com "$TEMP_DIR/get-docker.sh"
    sh "$TEMP_DIR/get-docker.sh"
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker is installed, but the Compose v2 plugin is unavailable." >&2
    exit 1
fi

# --- Tailscale ---------------------------------------------------------------
# The private link between the machines: they live at different providers, so
# there is no shared subnet, and this link carries patient scans.
# Install only — `tailscale up` is run by hand so the auth key never lands in the
# metadata service.
if command -v tailscale >/dev/null 2>&1 && systemctl cat tailscaled.service >/dev/null 2>&1; then
    log "tailscale already present, skipping"
else
    log "installing tailscale"
    download https://tailscale.com/install.sh "$TEMP_DIR/tailscale-install.sh"
    sh "$TEMP_DIR/tailscale-install.sh"
fi
systemctl enable --now tailscaled
tailscale version >/dev/null

# --- Stack files -------------------------------------------------------------
# Fetched from the repository rather than written here, so they cannot drift from
# deploy/ in git. The repository is the source of truth.
log "laying out $TARGET_DIR"
mkdir -p "$TARGET_DIR/logs"
download "$RAW/docker-compose.$ROLE.yml" "$TARGET_DIR/docker-compose.yml"
if [ "$ROLE" = main ]; then
    download "$RAW/Caddyfile" "$TARGET_DIR/Caddyfile"
fi

# --- GPU stack ---------------------------------------------------------------
if [ "$ROLE" = inference ]; then
    DRIVER_READY=no
    if nvidia-smi >/dev/null 2>&1; then
        log "NVIDIA driver already present, skipping"
        DRIVER_READY=yes
    else
        log "installing the NVIDIA driver"
        apt_install ubuntu-drivers-common
        ubuntu-drivers install --gpgpu
        NEEDS_REBOOT=yes
    fi

    # Package presence, rather than a network call, makes this genuinely safe to
    # re-run. GPU provider images sometimes hold container-toolkit packages even
    # though they are not installed; release only that exact package family and
    # install all of it at one matching version. Driver packages remain untouched.
    if command -v nvidia-ctk >/dev/null 2>&1 \
        && command -v nvidia-container-cli >/dev/null 2>&1 \
        && dpkg-query -W -f='${Status}' nvidia-container-toolkit 2>/dev/null \
            | grep -Fxq 'install ok installed'; then
        log "NVIDIA Container Toolkit already present, skipping package installation"
    else
        log "installing the NVIDIA Container Toolkit"
        TOOLKIT_VERSION="$(apt-cache policy nvidia-container-toolkit | awk '/Candidate:/ && !is_printed { print $2; is_printed=1 }')"
        if [ -z "$TOOLKIT_VERSION" ] || [ "$TOOLKIT_VERSION" = "(none)" ]; then
            log "adding the NVIDIA Container Toolkit repository"
            download \
                https://nvidia.github.io/libnvidia-container/gpgkey \
                "$TEMP_DIR/nvidia-container-toolkit.gpgkey"
            gpg --dearmor --batch --yes \
                --output /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
                "$TEMP_DIR/nvidia-container-toolkit.gpgkey"

            download \
                https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
                "$TEMP_DIR/nvidia-container-toolkit.list"
            sed \
                's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
                "$TEMP_DIR/nvidia-container-toolkit.list" \
                >/etc/apt/sources.list.d/nvidia-container-toolkit.list

            apt-get -o DPkg::Lock::Timeout=300 update
            TOOLKIT_VERSION="$(apt-cache policy nvidia-container-toolkit | awk '/Candidate:/ && !is_printed { print $2; is_printed=1 }')"
            if [ -z "$TOOLKIT_VERSION" ] || [ "$TOOLKIT_VERSION" = "(none)" ]; then
                fail "no candidate version found for nvidia-container-toolkit"
            fi
        else
            log "using NVIDIA Container Toolkit $TOOLKIT_VERSION from an existing provider repository"
        fi

        HELD_PACKAGES="$(apt-mark showhold)"
        for package_name in \
            nvidia-container-toolkit \
            nvidia-container-toolkit-base \
            libnvidia-container-tools \
            libnvidia-container1; do
            if grep -Fxq "$package_name" <<<"$HELD_PACKAGES"; then
                log "releasing provider hold on $package_name"
                apt-mark unhold "$package_name"
            fi
        done

        apt_install \
            "nvidia-container-toolkit=$TOOLKIT_VERSION" \
            "nvidia-container-toolkit-base=$TOOLKIT_VERSION" \
            "libnvidia-container-tools=$TOOLKIT_VERSION" \
            "libnvidia-container1=$TOOLKIT_VERSION"
    fi

    command -v nvidia-ctk >/dev/null 2>&1 || fail "nvidia-ctk is unavailable after installation"
    command -v nvidia-container-cli >/dev/null 2>&1 \
        || fail "nvidia-container-cli is unavailable after installation"

    log "configuring the NVIDIA Docker runtime"
    nvidia-ctk runtime configure --runtime=docker

    if [ "$DRIVER_READY" = yes ]; then
        nvidia-container-cli info >/dev/null

        # Toolkit 1.18+ normally maintains the CDI file through this path unit.
        # Generate it explicitly as a fallback: recent Docker versions use CDI for
        # `--gpus all` and fail with "no known GPU vendor" when the file is absent.
        systemctl daemon-reload
        if systemctl cat nvidia-cdi-refresh.path >/dev/null 2>&1; then
            if ! systemctl enable --now nvidia-cdi-refresh.path; then
                log "automatic NVIDIA CDI refresh could not be enabled; using the explicit fallback"
            fi
            if ! systemctl restart nvidia-cdi-refresh.service; then
                log "automatic NVIDIA CDI refresh failed; using the explicit fallback"
            fi
        fi
        if ! nvidia-ctk cdi list 2>/dev/null | grep -Fxq 'nvidia.com/gpu=all'; then
            log "generating the NVIDIA CDI specification"
            mkdir -p /var/run/cdi
            nvidia-ctk cdi generate --output=/var/run/cdi/nvidia.yaml
        fi

        systemctl restart docker
        log "checking GPU access from Docker"
        GPU_TEST_OK=no
        for attempt in 1 2 3; do
            if docker run --rm --gpus all ubuntu:24.04 nvidia-smi; then
                GPU_TEST_OK=yes
                break
            fi
            log "Docker GPU check failed (attempt $attempt/3); retrying"
            sleep 5
        done
        if [ "$GPU_TEST_OK" != yes ]; then
            fail "Docker cannot access the GPU"
        fi
    else
        systemctl restart docker
        log "GPU verification deferred until reboot loads the newly installed driver"
    fi
fi

# --- Rights ------------------------------------------------------------------
# Given to every non-system user rather than to a named login, which keeps this
# script identical across machines and providers.
#
# UID 1000 is not a reliable stand-in for "the user I log in as" — measured on
# Yandex Cloud: their Ubuntu image already ships a built-in `ubuntu` at 1000, so
# the login from the creation form lands on 1001 and the rights went to the wrong
# account.
log "granting rights to the machine's users"
while IFS= read -r user_name; do
    usermod -aG docker "$user_name"
done < <(awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd)
chgrp -R docker "$TARGET_DIR"
chmod -R g+rwX "$TARGET_DIR"

echo
log "$ROLE: done"
echo
echo "  Reboot before going further — the docker group applies to new sessions only,"
if [ "${NEEDS_REBOOT:-no}" = yes ]; then
    echo "  and the NVIDIA kernel module wants a clean boot:"
else
    echo "  and it costs nothing here since nothing is running yet:"
fi
echo "      sudo reboot"
echo
if [ "$ROLE" = inference ]; then
    echo "  Then confirm the card is visible to the host and to Docker — the second"
    echo "  command is the one that catches a missing Container Toolkit:"
    echo "      nvidia-smi"
    echo "      docker run --rm --gpus all ubuntu nvidia-smi"
    echo
fi
echo "  Join the private network and note the address:"
echo "      sudo tailscale up && tailscale ip -4"
echo
echo "  Then write $TARGET_DIR/.env for this machine and, from your laptop:"
echo "      deploy/sync-secrets.sh $ROLE LOGIN@HOST"
echo
echo "  Bootstrap log: $LOG_FILE"
