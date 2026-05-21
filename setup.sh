#!/bin/bash
# =============================================================
# setup.sh — Install Docker, SearXNG + Open WebUI + Playwright
# Ubuntu Edition
#
# Architecture:
#   SearXNG    — private search, exposed LAN-wide on port 8081
#   Open WebUI — cloud model frontend (OpenAI, Anthropic, Google,
#                OpenRouter, etc.), exposed LAN-wide on chosen port
#   Playwright — local browser service for JS-heavy page extraction,
#                version-matched to Open WebUI, running on port 3001
#
# Must be run as root: sudo bash setup.sh
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
  echo "      Please run: sudo bash setup.sh"
  echo ""
  exit 1
fi

echo ""
echo "============================================="
echo " SearXNG + Open WebUI + Playwright Setup"
echo " Ubuntu Edition"
echo "============================================="
echo ""

MAX_RETRIES=3
PLAYWRIGHT_PORT=3001
PLAYWRIGHT_IMAGE_TAG="playwright-server"

# -------------------------------------------------------
# Step 1 — Install Docker
# -------------------------------------------------------
section "[1/11] Installing dependencies..."
apt-get update -qq
apt-get install -y ca-certificates curl
ok "Dependencies installed."

section "[2/11] Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null
ok "Docker repository added."

section "[3/11] Installing Docker..."
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker

docker run --rm hello-world > /dev/null 2>&1 && ok "Docker is working." || {
  err "Docker installed but failed to run. Try: systemctl restart docker"
  exit 1
}

# -------------------------------------------------------
# Step 2 — SearXNG configuration
# -------------------------------------------------------
section "[4/11] SearXNG configuration..."
echo ""

echo "  Search engines:"
echo "    1) Optimal   — curated engines across web, images, video, news,"
echo "                   maps, music, IT, science and more (recommended)"
echo "    2) Stock     — SearXNG stock defaults (all built-in engines)"
echo ""
while true; do
  read -p "  Enter choice [1-2]: " engine_choice
  case "$engine_choice" in
    1) ENGINE_MODE="preset";   ok "Preset engines selected.";   break ;;
    2) ENGINE_MODE="defaults"; ok "SearXNG defaults selected."; break ;;
    *) echo "  Invalid choice. Please enter 1 or 2." ;;
  esac
done
echo ""

echo "  Safe search:"
echo "    1) Off      — no filtering"
echo "    2) Moderate — filter explicit images"
echo "    3) Strict   — filter explicit content"
echo ""
while true; do
  read -p "  Enter choice [1-3]: " safe_choice
  case "$safe_choice" in
    1) SAFE_SEARCH=0; ok "Safe search off.";      break ;;
    2) SAFE_SEARCH=1; ok "Moderate safe search."; break ;;
    3) SAFE_SEARCH=2; ok "Strict safe search.";   break ;;
    *) echo "  Invalid choice. Please enter 1, 2 or 3." ;;
  esac
done
echo ""

echo "  Max results per search:"
echo "    1) 10  — faster, lighter"
echo "    2) 20  — balanced (recommended)"
echo "    3) 30  — more results, slightly slower"
echo ""
while true; do
  read -p "  Enter choice [1-3]: " results_choice
  case "$results_choice" in
    1) MAX_RESULTS=10; ok "Max results: 10."; break ;;
    2) MAX_RESULTS=20; ok "Max results: 20."; break ;;
    3) MAX_RESULTS=30; ok "Max results: 30."; break ;;
    *) echo "  Invalid choice. Please enter 1, 2 or 3." ;;
  esac
done
echo ""

echo "  Image proxy (routes images through SearXNG for privacy):"
echo "    1) On   — recommended for privacy"
echo "    2) Off  — images load directly from source"
echo ""
while true; do
  read -p "  Enter choice [1-2]: " proxy_choice
  case "$proxy_choice" in
    1) IMAGE_PROXY=true;  ok "Image proxy on.";  break ;;
    2) IMAGE_PROXY=false; ok "Image proxy off."; break ;;
    *) echo "  Invalid choice. Please enter 1 or 2." ;;
  esac
done
echo ""

echo "  Open WebUI port:"
echo "    1) 3000  — default"
echo "    2) 8080  — alternative"
echo "    3) Custom"
echo ""
while true; do
  read -p "  Enter choice [1-3]: " port_choice
  case "$port_choice" in
    1) WEBUI_PORT=3000; ok "Open WebUI port: 3000."; break ;;
    2) WEBUI_PORT=8080; ok "Open WebUI port: 8080."; break ;;
    3)
      read -p "  Enter custom port number: " WEBUI_PORT
      if [[ "$WEBUI_PORT" =~ ^[0-9]+$ ]] && [ "$WEBUI_PORT" -ge 1024 ] && [ "$WEBUI_PORT" -le 65535 ]; then
        ok "Open WebUI port: $WEBUI_PORT."
        break
      else
        echo "  Invalid port. Please enter a number between 1024 and 65535."
      fi
      ;;
    *) echo "  Invalid choice. Please enter 1, 2 or 3." ;;
  esac
done

# Port 3001 is reserved for Playwright
if [ "$WEBUI_PORT" -eq "$PLAYWRIGHT_PORT" ]; then
  echo ""
  err "Port $PLAYWRIGHT_PORT is reserved for Playwright. Please choose a different port for Open WebUI."
  exit 1
fi
echo ""

# -------------------------------------------------------
# Step 3 — Write SearXNG config
# -------------------------------------------------------
section "[5/11] Writing SearXNG configuration..."
mkdir -p /root/searxng-config
SECRET_KEY=$(openssl rand -hex 20)

if [ "$ENGINE_MODE" = "preset" ]; then
  tee /root/searxng-config/settings.yml > /dev/null << EOF
use_default_settings:
  engines:
    keep_only:
      - google
      - duckduckgo
      - brave
      - startpage
      - wikipedia
      - google images
      - bing images
      - brave.images
      - qwant
      - qwant images
      - startpage images
      - google videos
      - bing videos
      - brave.videos
      - qwant videos
      - youtube
      - google news
      - bing news
      - brave.news
      - duckduckgo news
      - qwant news
      - reuters
      - openstreetmap
      - photon
      - genius
      - soundcloud
      - arch linux wiki
      - mdn
      - arxiv
      - google scholar
      - semantic scholar
      - reddit

engines:
  - name: google
    disabled: false
  - name: duckduckgo
    disabled: false
  - name: brave
    disabled: false
  - name: startpage
    disabled: false
  - name: wikipedia
    disabled: false
  - name: google images
    disabled: false
  - name: bing images
    disabled: false
  - name: brave.images
    disabled: false
  - name: qwant
    disabled: true
  - name: qwant images
    disabled: false
  - name: startpage images
    disabled: false
  - name: google videos
    disabled: false
  - name: bing videos
    disabled: false
  - name: brave.videos
    disabled: false
  - name: qwant videos
    disabled: false
  - name: youtube
    disabled: false
  - name: google news
    disabled: false
  - name: bing news
    disabled: false
  - name: brave.news
    disabled: false
  - name: duckduckgo news
    disabled: false
  - name: qwant news
    disabled: false
  - name: reuters
    disabled: false
  - name: openstreetmap
    disabled: false
  - name: photon
    disabled: false
  - name: genius
    disabled: false
  - name: soundcloud
    disabled: false
  - name: arch linux wiki
    disabled: false
  - name: mdn
    disabled: false
  - name: arxiv
    disabled: false
  - name: google scholar
    disabled: false
  - name: semantic scholar
    disabled: false
  - name: reddit
    disabled: false

server:
  secret_key: "$SECRET_KEY"
  limiter: false
  image_proxy: $IMAGE_PROXY
  port: 8081
  bind_address: "0.0.0.0"

search:
  safe_search: $SAFE_SEARCH
  autocomplete: ""
  default_lang: ""
  max_results: $MAX_RESULTS
  formats:
    - html
    - json

ui:
  static_use_hash: true
EOF
else
  tee /root/searxng-config/settings.yml > /dev/null << EOF
use_default_settings: true

server:
  secret_key: "$SECRET_KEY"
  limiter: false
  image_proxy: $IMAGE_PROXY
  port: 8081
  bind_address: "0.0.0.0"

search:
  safe_search: $SAFE_SEARCH
  autocomplete: ""
  default_lang: ""
  max_results: $MAX_RESULTS
  formats:
    - html
    - json

ui:
  static_use_hash: true
EOF
fi
ok "SearXNG config written."

# -------------------------------------------------------
# Step 4 — Launch SearXNG
# -------------------------------------------------------
section "[6/11] Pulling and starting SearXNG..."

if docker ps -a --format '{{.Names}}' | grep -q '^searxng$'; then
  info "Found existing searxng container — removing it..."
  docker rm -f searxng > /dev/null
fi

attempt=1
until docker pull searxng/searxng; do
  if [ $attempt -ge $MAX_RETRIES ]; then
    err "Failed to pull SearXNG image after $MAX_RETRIES attempts."
    exit 1
  fi
  warn "Pull failed (attempt $attempt/$MAX_RETRIES) — retrying in 3s..."
  attempt=$((attempt + 1))
  sleep 3
done

docker run -d \
  --name searxng \
  --network=host \
  --restart always \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -e SEARXNG_PORT=8081 \
  -v /root/searxng-config:/etc/searxng \
  searxng/searxng

info "Waiting for SearXNG to be ready..."
MAX_WAIT=60; INTERVAL=3; elapsed=0; success=false
while [ $elapsed -lt $MAX_WAIT ]; do
  if curl -sf "http://localhost:8081/search?q=test&format=json" > /dev/null 2>&1; then
    success=true; break
  fi
  info "Not ready yet... (${elapsed}s elapsed)"
  sleep $INTERVAL
  elapsed=$((elapsed + INTERVAL))
done

$success && ok "SearXNG is ready." || {
  err "SearXNG did not respond after ${MAX_WAIT}s."
  info "Check logs with: docker logs searxng --tail 20"
  exit 1
}

# -------------------------------------------------------
# Step 5 — Launch Open WebUI
# -------------------------------------------------------
section "[7/11] Pulling and starting Open WebUI..."

if docker ps -a --format '{{.Names}}' | grep -q '^open-webui$'; then
  info "Found existing open-webui container — removing it..."
  docker rm -f open-webui > /dev/null
fi

attempt=1
until docker pull ghcr.io/open-webui/open-webui:main; do
  if [ $attempt -ge $MAX_RETRIES ]; then
    err "Failed to pull Open WebUI image after $MAX_RETRIES attempts."
    exit 1
  fi
  warn "Pull failed (attempt $attempt/$MAX_RETRIES) — retrying in 3s..."
  attempt=$((attempt + 1))
  sleep 3
done

mkdir -p /root/open-webui-data

docker run -d \
  --name open-webui \
  --network=host \
  --restart always \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -e PORT=$WEBUI_PORT \
  -e WEBUI_SECRET_KEY=$(openssl rand -hex 32) \
  -e ENABLE_OLLAMA_API=false \
  -e ENABLE_RAG_WEB_SEARCH=true \
  -e RAG_WEB_SEARCH_ENGINE=searxng \
  -e "SEARXNG_QUERY_URL=http://localhost:8081/search?q=<query>&format=json" \
  -e ENABLE_SIGNUP=true \
  -e DEFAULT_USER_ROLE=user \
  -v /root/open-webui-data:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

info "Waiting for Open WebUI to be ready..."
MAX_WAIT=90; elapsed=0; success=false
while [ $elapsed -lt $MAX_WAIT ]; do
  if curl -sf "http://localhost:$WEBUI_PORT" > /dev/null 2>&1; then
    success=true; break
  fi
  info "Not ready yet... (${elapsed}s elapsed)"
  sleep $INTERVAL
  elapsed=$((elapsed + INTERVAL))
done

$success && ok "Open WebUI is ready." || {
  err "Open WebUI did not respond after ${MAX_WAIT}s."
  info "Check logs with: docker logs open-webui --tail 20"
  exit 1
}

# -------------------------------------------------------
# Step 6 — Detect Playwright version from Open WebUI
# -------------------------------------------------------
section "[8/11] Detecting Playwright version from Open WebUI..."

# Give Open WebUI a moment to fully settle before querying it
sleep 5

PW_VERSION=$(docker exec open-webui pip show playwright 2>/dev/null \
  | grep '^Version:' | awk '{print $2}')

if [ -z "$PW_VERSION" ]; then
  err "Could not detect Playwright version from Open WebUI container."
  warn "Playwright will not be installed. Run: sudo bash add-playwright.sh"
  PW_FAILED=true
else
  ok "Open WebUI is running Playwright v${PW_VERSION}."
  PW_FAILED=false
fi

# -------------------------------------------------------
# Step 7 — Pull the matching Playwright base image
# -------------------------------------------------------
if [ "$PW_FAILED" = false ]; then
  section "[9/11] Pulling Playwright base image (v${PW_VERSION})..."

  PW_BASE_IMAGE="mcr.microsoft.com/playwright:v${PW_VERSION}-noble"

  attempt=1
  until docker pull "$PW_BASE_IMAGE"; do
    if [ $attempt -ge $MAX_RETRIES ]; then
      err "Failed to pull Playwright image after $MAX_RETRIES attempts."
      warn "Playwright will not be installed. Run: sudo bash add-playwright.sh"
      PW_FAILED=true
      break
    fi
    warn "Pull failed (attempt $attempt/$MAX_RETRIES) — retrying in 3s..."
    attempt=$((attempt + 1))
    sleep 3
  done
fi

# -------------------------------------------------------
# Step 8 — Build local cached Playwright image
# -------------------------------------------------------
if [ "$PW_FAILED" = false ]; then
  section "[10/11] Building local Playwright image..."

  # Build a local image with Playwright pre-installed so startup
  # is instant on every reboot with no network dependency
  DOCKERFILE_DIR=$(mktemp -d)
  cat > "$DOCKERFILE_DIR/Dockerfile" << EOF
FROM mcr.microsoft.com/playwright:v${PW_VERSION}-noble
RUN npx --yes playwright@${PW_VERSION} run-server --version 2>/dev/null || true
ENV PLAYWRIGHT_DEFAULT_NAVIGATION_TIMEOUT=10000
ENTRYPOINT ["npx", "--yes", "playwright@${PW_VERSION}", "run-server", "--port", "3001", "--host", "0.0.0.0"]
EOF

  if docker build -t "${PLAYWRIGHT_IMAGE_TAG}:${PW_VERSION}" \
      "$DOCKERFILE_DIR" > /dev/null 2>&1; then
    ok "Local Playwright image built (${PLAYWRIGHT_IMAGE_TAG}:${PW_VERSION})."
    docker tag "${PLAYWRIGHT_IMAGE_TAG}:${PW_VERSION}" \
      "${PLAYWRIGHT_IMAGE_TAG}:latest" > /dev/null 2>&1
  else
    err "Failed to build local Playwright image."
    warn "Playwright will not be installed. Run: sudo bash add-playwright.sh"
    PW_FAILED=true
  fi

  rm -rf "$DOCKERFILE_DIR"
fi

# -------------------------------------------------------
# Step 9 — Launch Playwright container
# -------------------------------------------------------
if [ "$PW_FAILED" = false ]; then
  section "[11/11] Starting Playwright..."

  if docker ps -a --format '{{.Names}}' | grep -q '^playwright-chromium$'; then
    info "Found existing playwright-chromium container — removing it..."
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

  info "Waiting for Playwright to be ready..."
  MAX_WAIT=60; elapsed=0; success=false
  while [ $elapsed -lt $MAX_WAIT ]; do
    if docker logs playwright-chromium 2>&1 | grep -q "Listening on"; then
      success=true; break
    fi
    info "Not ready yet... (${elapsed}s elapsed)"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
  done

  $success && ok "Playwright is ready on ws://localhost:${PLAYWRIGHT_PORT}." || {
    err "Playwright did not start after ${MAX_WAIT}s."
    info "Check logs with: docker logs playwright-chromium --tail 20"
    PW_FAILED=true
  }
fi

# -------------------------------------------------------
# Final summary
# -------------------------------------------------------
LAN_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "============================================="
echo " Setup complete!"
echo ""
echo " SearXNG    → http://$LAN_IP:8081"
echo " Open WebUI → http://$LAN_IP:$WEBUI_PORT"
if [ "$PW_FAILED" = false ]; then
  echo " Playwright → ws://localhost:$PLAYWRIGHT_PORT"
fi
echo ""
echo " All services start automatically on boot."
echo ""
if [ "$PW_FAILED" = false ]; then
  echo "---------------------------------------------"
  echo " Playwright WebSocket URL for Open WebUI:"
  echo ""
  echo "   ws://localhost:$PLAYWRIGHT_PORT"
  echo ""
  echo " To configure in Open WebUI:"
  echo "   Admin Panel → Settings → Web Search"
  echo "   → Web Loader Engine  → playwright"
  echo "   → Playwright WebSocket URL → paste above"
  echo "   → Save"
  echo "---------------------------------------------"
else
  echo "---------------------------------------------"
  echo " Playwright was not installed."
  echo " Run this when ready:"
  echo "   sudo bash add-playwright.sh"
  echo "---------------------------------------------"
fi
echo ""
echo " Useful commands:"
echo "   docker ps                                   # check all containers"
echo "   docker logs searxng --tail 20               # SearXNG logs"
echo "   docker logs open-webui --tail 20            # Open WebUI logs"
if [ "$PW_FAILED" = false ]; then
  echo "   docker logs playwright-chromium --tail 20  # Playwright logs"
fi
echo "============================================="
echo ""
