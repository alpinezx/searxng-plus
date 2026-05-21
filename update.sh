#!/bin/bash
# =============================================================
# update.sh — Update SearXNG, Open WebUI and Playwright
# Ubuntu Edition
#
# Safe to run against a live setup.
# - Preserves all Open WebUI data and settings
# - Preserves SearXNG configuration
# - Detects Playwright version change after Open WebUI update
#   and rebuilds the local Playwright image to match
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

ok()      { echo -e "${GREEN}  ✔  $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠  $1${NC}"; }
err()     { echo -e "${RED}  ✘  $1${NC}"; }
info()    { echo -e "${CYAN}      $1${NC}"; }
section() { echo -e "\n${BOLD}$1${NC}"; }

# --- Ensure running as root ---
if [ "$EUID" -ne 0 ]; then
  echo ""
  err "This script must be run as root."
  echo "      Please run: sudo bash update.sh"
  echo ""
  exit 1
fi

echo ""
echo "============================================="
echo " SearXNG + Open WebUI + Playwright"
echo " Update — Ubuntu Edition"
echo "============================================="
echo ""
echo " This script will check for and apply updates to:"
echo ""
echo "   • SearXNG         — pulls latest image, restarts if changed"
echo "   • Open WebUI      — pulls latest image, restarts if changed"
echo "   • Playwright      — rebuilds automatically if Open WebUI's"
echo "                       internal version has changed"
echo ""
echo " Your data, settings and configuration are preserved."
echo ""
read -p " Press Enter to continue or Ctrl+C to cancel..."
echo ""

MAX_RETRIES=3
INTERVAL=3
PLAYWRIGHT_PORT=3001
PLAYWRIGHT_IMAGE_TAG="playwright-server"

# Track what actually changed for the summary
SEARXNG_UPDATED=false
WEBUI_UPDATED=false
PW_REBUILT=false
PW_INSTALLED=false

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
  # Capture current Playwright version before update
  PW_VERSION_BEFORE=$(docker exec open-webui pip show playwright 2>/dev/null \
    | grep '^Version:' | awk '{print $2}' || echo "unknown")

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

    # Wait for Open WebUI to come back up
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

  # Capture Playwright version after update (even if no image change,
  # a running container update could still change internal packages)
  sleep 5
  PW_VERSION_AFTER=$(docker exec open-webui pip show playwright 2>/dev/null \
    | grep '^Version:' | awk '{print $2}' || echo "unknown")

  if [ "$PW_VERSION_BEFORE" != "$PW_VERSION_AFTER" ]; then
    warn "Playwright version changed: v${PW_VERSION_BEFORE} → v${PW_VERSION_AFTER}"
    info "Playwright server will be rebuilt to match."
    PW_NEEDS_REBUILD=true
  else
    PW_NEEDS_REBUILD=false
    info "Playwright version unchanged at v${PW_VERSION_AFTER}."
  fi
fi

# -------------------------------------------------------
# Check Playwright — rebuild if version changed or missing
# -------------------------------------------------------
section "Checking Playwright..."

PW_VERSION=$(docker exec open-webui pip show playwright 2>/dev/null \
  | grep '^Version:' | awk '{print $2}' || echo "")

if [ -z "$PW_VERSION" ]; then
  warn "Could not detect Playwright version from Open WebUI."
else
  # Check if playwright-chromium container exists
  if ! docker ps -a --format '{{.Names}}' | grep -q '^playwright-chromium$'; then
    warn "Playwright container not found — installing it now..."
    PW_NEEDS_REBUILD=true
    PW_INSTALLED=true
  fi

  # Check if local image version matches Open WebUI
  CURRENT_PW_IMAGE=$(docker inspect playwright-chromium \
    --format='{{.Config.Image}}' 2>/dev/null || echo "")

  if [ "${PW_NEEDS_REBUILD:-false}" = false ] && \
     echo "$CURRENT_PW_IMAGE" | grep -q "$PW_VERSION"; then
    ok "Playwright server v${PW_VERSION} matches Open WebUI. Nothing to do."
  else
    PW_NEEDS_REBUILD=true
  fi
fi

if [ "${PW_NEEDS_REBUILD:-false}" = true ] && [ -n "$PW_VERSION" ]; then
  info "Rebuilding Playwright server for v${PW_VERSION}..."

  PW_BASE_IMAGE="mcr.microsoft.com/playwright:v${PW_VERSION}-noble"

  # Pull base image
  attempt=1
  until docker pull "$PW_BASE_IMAGE"; do
    if [ $attempt -ge $MAX_RETRIES ]; then
      err "Failed to pull Playwright base image after $MAX_RETRIES attempts."
      PW_VERSION=""
      break
    fi
    warn "Pull failed (attempt $attempt/$MAX_RETRIES) — retrying in 3s..."
    attempt=$((attempt + 1))
    sleep 3
  done

  if [ -n "$PW_VERSION" ]; then
    # Build local cached image
    DOCKERFILE_DIR=$(mktemp -d)
    cat > "$DOCKERFILE_DIR/Dockerfile" << EOF
FROM mcr.microsoft.com/playwright:v${PW_VERSION}-noble
RUN npx --yes playwright@${PW_VERSION} run-server --version 2>/dev/null || true
ENV PLAYWRIGHT_DEFAULT_NAVIGATION_TIMEOUT=10000
ENTRYPOINT ["npx", "--yes", "playwright@${PW_VERSION}", "run-server", "--port", "3001", "--host", "0.0.0.0"]
EOF

    if docker build -t "${PLAYWRIGHT_IMAGE_TAG}:${PW_VERSION}" \
        "$DOCKERFILE_DIR" > /dev/null 2>&1; then
      ok "Local Playwright image built (v${PW_VERSION})."
      docker tag "${PLAYWRIGHT_IMAGE_TAG}:${PW_VERSION}" \
        "${PLAYWRIGHT_IMAGE_TAG}:latest" > /dev/null 2>&1

      # Remove old container and start fresh with new image
      if docker ps -a --format '{{.Names}}' | grep -q '^playwright-chromium$'; then
        docker rm -f playwright-chromium > /dev/null
      fi

      docker run -d \
        --name playwright-chromium \
        --network=host \
        --restart always \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        --shm-size=1g \
        "${PLAYWRIGHT_IMAGE_TAG}:latest"

      # Wait for it to be ready
      MAX_WAIT=60; elapsed=0; success=false
      while [ $elapsed -lt $MAX_WAIT ]; do
        if docker logs playwright-chromium 2>&1 | grep -q "Listening on"; then
          success=true; break
        fi
        info "Waiting for Playwright... (${elapsed}s elapsed)"
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
      done

      $success && {
        ok "Playwright v${PW_VERSION} is ready on ws://localhost:${PLAYWRIGHT_PORT}."
        PW_REBUILT=true
      } || {
        err "Playwright did not start after rebuild."
        info "Check logs with: docker logs playwright-chromium --tail 20"
      }

      # Clean up old images to save disk space
      docker image prune -f --filter \
        "label=playwright-server" > /dev/null 2>&1 || true

    else
      err "Failed to build local Playwright image."
    fi

    rm -rf "$DOCKERFILE_DIR"
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
echo "   SearXNG    → http://$LAN_IP:8081"
echo "   Open WebUI → http://$LAN_IP:${WEBUI_PORT:-3000}"
if docker ps --format '{{.Names}}' | grep -q '^playwright-chromium$'; then
  echo "   Playwright → ws://localhost:$PLAYWRIGHT_PORT"
fi
echo ""
echo "---------------------------------------------"
echo " What changed:"
if [ "$SEARXNG_UPDATED" = true ]; then
  echo "   ✔  SearXNG        — updated to latest"
else
  echo "   —  SearXNG        — already up to date"
fi
if [ "$WEBUI_UPDATED" = true ]; then
  echo "   ✔  Open WebUI     — updated to latest"
else
  echo "   —  Open WebUI     — already up to date"
fi
if [ "$PW_REBUILT" = true ] && [ "$PW_INSTALLED" = true ]; then
  echo "   ✔  Playwright     — installed v${PW_VERSION}"
elif [ "$PW_REBUILT" = true ]; then
  echo "   ✔  Playwright     — rebuilt to match Open WebUI v${PW_VERSION}"
else
  echo "   —  Playwright     — already up to date"
fi
echo "---------------------------------------------"
echo ""
echo " Settings and data preserved."
echo "============================================="
echo ""
