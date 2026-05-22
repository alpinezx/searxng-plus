#!/bin/bash
# =============================================================
# update.sh — Update SearXNG and Open WebUI
# Ubuntu Edition
#
# Safe to run against a live setup.
# - Preserves all Open WebUI data and settings
# - Preserves SearXNG configuration
#
# Must be run as root: sudo bash update.sh
# =============================================================

set -e

# --- Colour helpers ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()      { echo -e "${GREEN}  [ok]   $1${NC}"; }
warn()    { echo -e "${YELLOW}  [warn] $1${NC}"; }
err()     { echo -e "${RED}  [err]  $1${NC}"; }
info()    { echo -e "${CYAN}      $1${NC}"; }
section() { echo -e "\n${BOLD}$1${NC}"; }

# --- Ensure running as root ---
if [ "$EUID" -ne 0 ]; then
  echo ""
  echo "ERROR: This script must be run as root."
  echo "       Please run: sudo bash update.sh"
  echo ""
  exit 1
fi

echo ""
echo "============================================="
echo " SearXNG + Open WebUI"
echo " Update — Ubuntu Edition"
echo "============================================="
echo ""
echo " This script will check for and apply updates to:"
echo ""
echo "   • SearXNG         — pulls latest image, restarts if changed"
echo "   • Open WebUI      — pulls latest image, restarts if changed"
echo ""
echo " Your data, settings and configuration are preserved."
echo ""
read -p " Press Enter to continue or Ctrl+C to cancel..."
echo ""

MAX_RETRIES=3
INTERVAL=3

# Track what actually changed for the summary
SEARXNG_UPDATED=false
WEBUI_UPDATED=false

# -------------------------------------------------------
# Check Docker is running
# -------------------------------------------------------
section "Checking Docker..."
if ! systemctl is-active --quiet docker; then
  warn "Docker is not running — starting it..."
  systemctl start docker
  sleep 3
fi
docker info > /dev/null 2>&1 && ok "Docker is running." || {
  err "Docker is not responding. Try: systemctl restart docker"
  exit 1
}

# -------------------------------------------------------
# Update SearXNG
# -------------------------------------------------------
section "Updating SearXNG..."

if ! docker ps -a --format '{{.Names}}' | grep -q '^searxng$'; then
  warn "SearXNG container not found — skipping."
else
  # Get the current image digest before pulling
  OLD_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' \
    searxng/searxng 2>/dev/null || echo "none")

  attempt=1
  until docker pull searxng/searxng; do
    if [ $attempt -ge $MAX_RETRIES ]; then
      err "Failed to pull SearXNG image after $MAX_RETRIES attempts."
      break
    fi
    warn "Pull failed (attempt $attempt/$MAX_RETRIES) — retrying in 3s..."
    attempt=$((attempt + 1))
    sleep 3
  done

  NEW_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' \
    searxng/searxng 2>/dev/null || echo "none")

  if [ "$OLD_DIGEST" != "$NEW_DIGEST" ]; then
    info "New SearXNG image found — restarting container..."
    docker restart searxng > /dev/null

    # Wait for SearXNG to come back up
    MAX_WAIT=60; elapsed=0; success=false
    while [ $elapsed -lt $MAX_WAIT ]; do
      if curl -sf "http://localhost:8081/search?q=test&format=json" \
          > /dev/null 2>&1; then
        success=true; break
      fi
      info "Waiting for SearXNG... (${elapsed}s elapsed)"
      sleep $INTERVAL
      elapsed=$((elapsed + INTERVAL))
    done

    $success && {
      ok "SearXNG updated and ready."
      SEARXNG_UPDATED=true
    } || {
      err "SearXNG did not come back up after update."
      info "Check logs with: docker logs searxng --tail 20"
    }
  else
    ok "SearXNG is already up to date."
  fi
fi

# -------------------------------------------------------
# Update Open WebUI
# -------------------------------------------------------
section "Updating Open WebUI..."

if ! docker ps -a --format '{{.Names}}' | grep -q '^open-webui$'; then
  warn "Open WebUI container not found — skipping."
else
  OLD_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' \
    ghcr.io/open-webui/open-webui:main 2>/dev/null || echo "none")

  attempt=1
  until docker pull ghcr.io/open-webui/open-webui:main; do
    if [ $attempt -ge $MAX_RETRIES ]; then
      err "Failed to pull Open WebUI image after $MAX_RETRIES attempts."
      break
    fi
    warn "Pull failed (attempt $attempt/$MAX_RETRIES) — retrying in 3s..."
    attempt=$((attempt + 1))
    sleep 3
  done

  NEW_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' \
    ghcr.io/open-webui/open-webui:main 2>/dev/null || echo "none")

  if [ "$OLD_DIGEST" != "$NEW_DIGEST" ]; then
    info "New Open WebUI image found — restarting container..."
    # Data volume is preserved — only the container is replaced
    docker restart open-webui > /dev/null

    # Detect which port it's running on
    WEBUI_PORT=$(docker inspect open-webui \
      --format='{{range .Config.Env}}{{println .}}{{end}}' \
      | grep '^PORT=' | cut -d= -f2)
    WEBUI_PORT=${WEBUI_PORT:-3000}

    MAX_WAIT=90; elapsed=0; success=false
    while [ $elapsed -lt $MAX_WAIT ]; do
      if curl -sf "http://localhost:$WEBUI_PORT" > /dev/null 2>&1; then
        success=true; break
      fi
      info "Waiting for Open WebUI... (${elapsed}s elapsed)"
      sleep $INTERVAL
      elapsed=$((elapsed + INTERVAL))
    done

    $success && {
      ok "Open WebUI updated and ready."
      WEBUI_UPDATED=true
    } || {
      err "Open WebUI did not come back up after update."
      info "Check logs with: docker logs open-webui --tail 20"
    }
  else
    ok "Open WebUI is already up to date."
  fi
fi

# -------------------------------------------------------
# Final summary
# -------------------------------------------------------
LAN_IP=$(hostname -I | awk '{print $1}')
WEBUI_PORT=$(docker inspect open-webui \
  --format='{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
  | grep '^PORT=' | cut -d= -f2 || echo "3000")

echo ""
echo "============================================="
echo " Update complete!"
echo ""
echo " Services running:"
if docker ps --format '{{.Names}}' | grep -q '^searxng$'; then
  echo "   SearXNG    → http://$LAN_IP:8081"
fi
if docker ps --format '{{.Names}}' | grep -q '^open-webui$'; then
  echo "   Open WebUI → http://$LAN_IP:${WEBUI_PORT:-3000}"
fi
echo ""
echo "---------------------------------------------"
echo " What changed:"
if [ "$SEARXNG_UPDATED" = true ]; then
  echo "   [ok]  SearXNG    — updated to latest"
else
  echo "   [--]  SearXNG    — already up to date"
fi
if [ "$WEBUI_UPDATED" = true ]; then
  echo "   [ok]  Open WebUI — updated to latest"
else
  echo "   [--]  Open WebUI — already up to date"
fi
echo "---------------------------------------------"
echo ""
echo " Settings and data preserved."
echo "============================================="
echo ""
