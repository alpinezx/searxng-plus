#!/bin/bash
# =============================================================
# setup.sh — Install Docker and launch SearXNG and Open WebUI
# Ubuntu Edition
#
# Architecture:
#   SearXNG    — private search, exposed LAN-wide on port 8081
#   Open WebUI — cloud model frontend (OpenAI, Anthropic, Google,
#                OpenRouter, etc.), exposed LAN-wide on chosen port
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

ok()      { echo -e "${GREEN}  [ok]   $1${NC}"; }
warn()    { echo -e "${YELLOW}  [warn] $1${NC}"; }
err()     { echo -e "${RED}  [err]  $1${NC}"; }
info()    { echo -e "${CYAN}      $1${NC}"; }
section() { echo -e "\n${BOLD}$1${NC}"; }

# --- Ensure running as root ---
if [ "$EUID" -ne 0 ]; then
  echo ""
  echo "ERROR: This script must be run as root."
  echo "       Please run: sudo bash setup.sh"
  echo ""
  exit 1
fi

echo ""
echo "============================================="
echo " SearXNG + Open WebUI"
echo " Setup — Ubuntu Edition"
echo "============================================="
echo ""
echo " This script will walk you through installing:"
echo ""
echo "   • Docker          — required for everything else"
echo "   • SearXNG         — private local search engine"
echo "   • Open WebUI      — self-hosted AI chat interface"
echo ""
echo " You will be asked before anything is installed."
echo ""
read -p " Press Enter to continue or Ctrl+C to cancel..."
echo ""

MAX_RETRIES=3
INSTALL_SEARXNG=false
INSTALL_WEBUI=false

# =============================================================
# Step 1 — Docker
# =============================================================
section "[1/3] Docker"
echo ""
echo " Docker is required to run SearXNG and Open WebUI."
echo " It will be installed as the container runtime for everything else."
echo ""
read -p " Install Docker? (y/n): " choice
echo ""
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
  echo " Docker is required. Exiting."
  echo ""
  exit 0
fi

info "Installing dependencies..."
apt-get update -qq
apt-get install -y ca-certificates curl > /dev/null 2>&1

info "Creating keyring directory..."
install -m 0755 -d /etc/apt/keyrings

info "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

info "Adding Docker apt repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

info "Updating package list..."
apt-get update -qq

info "Installing Docker packages..."
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

info "Enabling and starting Docker service..."
systemctl enable docker > /dev/null 2>&1
systemctl start docker

info "Verifying Docker..."
docker run --rm hello-world > /dev/null 2>&1 && ok "Docker is working." || {
  echo ""
  err "Docker installed but failed to run."
  echo "      Try: systemctl restart docker"
  exit 1
}

# =============================================================
# Step 2 — Component selection
# =============================================================
section "[2/3] Choose what to install..."
echo ""
echo "   1) SearXNG only"
echo "      Private search engine — use in your browser or with LM Studio / Open WebUI"
echo ""
echo "   2) Open WebUI only"
echo "      Self-hosted chat interface for cloud AI models"
echo ""
echo "   3) SearXNG + Open WebUI"
echo "      Adds web search inside Open WebUI via your local SearXNG instance"
echo "      (recommended)"
echo ""
while true; do
  read -p " Enter choice [1-3]: " combo_choice
  case "$combo_choice" in
    1) INSTALL_SEARXNG=true;  INSTALL_WEBUI=false
       info "SearXNG only selected."; break ;;
    2) INSTALL_SEARXNG=false; INSTALL_WEBUI=true
       info "Open WebUI only selected."; break ;;
    3) INSTALL_SEARXNG=true;  INSTALL_WEBUI=true
       info "SearXNG + Open WebUI selected."; break ;;
    *) warn "Invalid choice. Please enter 1, 2 or 3." ;;
  esac
done
echo ""

# --- Open WebUI port (only if installing) ---
if $INSTALL_WEBUI; then
  echo " Open WebUI port:"
  echo "   1) 3000  — default"
  echo "   2) 8080  — alternative if 3000 is in use"
  echo "   3) Custom"
  echo ""
  while true; do
    read -p " Enter choice [1-3]: " port_choice
    case "$port_choice" in
      1) WEBUI_PORT=3000; info "Port: 3000."; break ;;
      2) WEBUI_PORT=8080; info "Port: 8080."; break ;;
      3)
        read -p " Enter port number: " WEBUI_PORT
        if [[ "$WEBUI_PORT" =~ ^[0-9]+$ ]] && \
           [ "$WEBUI_PORT" -ge 1024 ] && [ "$WEBUI_PORT" -le 65535 ]; then
          info "Port: $WEBUI_PORT."; break
        else
          warn "Invalid port. Enter a number between 1024 and 65535."
        fi
        ;;
      *) warn "Invalid choice. Please enter 1, 2 or 3." ;;
    esac
  done

  echo ""
fi

# --- SearXNG configuration (only if installing) ---
if $INSTALL_SEARXNG; then
  echo " Search engines:"
  echo "   1) Optimal   — curated engines across web, images, video, news,"
  echo "                  maps, music, IT, science and more (recommended)"
  echo "   2) Stock     — SearXNG stock defaults (all built-in engines)"
  echo ""
  while true; do
    read -p " Enter choice [1-2]: " engine_choice
    case "$engine_choice" in
      1) ENGINE_MODE="preset";   info "Preset engines selected.";   break ;;
      2) ENGINE_MODE="defaults"; info "SearXNG defaults selected."; break ;;
      *) warn "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
  echo ""

  echo " Safe search:"
  echo "   1) Off      — no filtering"
  echo "   2) Moderate — filter explicit images"
  echo "   3) Strict   — filter explicit content"
  echo ""
  while true; do
    read -p " Enter choice [1-3]: " safe_choice
    case "$safe_choice" in
      1) SAFE_SEARCH=0; info "Safe search off.";      break ;;
      2) SAFE_SEARCH=1; info "Moderate safe search."; break ;;
      3) SAFE_SEARCH=2; info "Strict safe search.";   break ;;
      *) warn "Invalid choice. Please enter 1, 2 or 3." ;;
    esac
  done
  echo ""

  echo " Max results per search:"
  echo "   1) 10  — faster, lighter"
  echo "   2) 20  — balanced (recommended)"
  echo "   3) 30  — more results, slightly slower"
  echo ""
  while true; do
    read -p " Enter choice [1-3]: " results_choice
    case "$results_choice" in
      1) MAX_RESULTS=10; info "Max results: 10."; break ;;
      2) MAX_RESULTS=20; info "Max results: 20."; break ;;
      3) MAX_RESULTS=30; info "Max results: 30."; break ;;
      *) warn "Invalid choice. Please enter 1, 2 or 3." ;;
    esac
  done
  echo ""

  echo " Image proxy (routes images through SearXNG for privacy):"
  echo "   1) On   — recommended for privacy"
  echo "   2) Off  — images load directly from source"
  echo ""
  while true; do
    read -p " Enter choice [1-2]: " proxy_choice
    case "$proxy_choice" in
      1) IMAGE_PROXY=true;  info "Image proxy on.";  break ;;
      2) IMAGE_PROXY=false; info "Image proxy off."; break ;;
      *) warn "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
  echo ""
fi

# =============================================================
# Step 3 — Install selected components
# =============================================================
section "[3/3] Installing selected components..."

# --- SearXNG ---
if $INSTALL_SEARXNG; then
  echo ""
  info "Setting up SearXNG..."

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

  info "Config written."

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

  $success && ok "SearXNG is running at http://localhost:8081" || {
    err "SearXNG did not respond after ${MAX_WAIT}s."
    echo "      Check logs: docker logs searxng --tail 20"
    exit 1
  }
fi

# --- Open WebUI ---
if $INSTALL_WEBUI; then
  echo ""
  info "Setting up Open WebUI..."

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

  info "Waiting for Open WebUI to be ready (this can take up to 90s on first launch)..."
  MAX_WAIT=90; INTERVAL=3; elapsed=0; success=false
  while [ $elapsed -lt $MAX_WAIT ]; do
    if curl -sf "http://localhost:$WEBUI_PORT" > /dev/null 2>&1; then
      success=true; break
    fi
    info "Not ready yet... (${elapsed}s elapsed)"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
  done

  $success && ok "Open WebUI is running at http://localhost:${WEBUI_PORT}" || {
    err "Open WebUI did not respond after ${MAX_WAIT}s."
    echo "      Check logs: docker logs open-webui --tail 20"
    exit 1
  }
fi

# =============================================================
# Summary
# =============================================================
LAN_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "============================================="
echo " Setup complete!"
echo ""
echo " Installed:"
$INSTALL_SEARXNG && echo "   [ok]  SearXNG    → http://$LAN_IP:8081"
$INSTALL_WEBUI   && echo "   [ok]  Open WebUI → http://$LAN_IP:${WEBUI_PORT}"
echo ""
echo " All services start automatically on boot."
echo ""
if $INSTALL_WEBUI; then
  echo " Open WebUI next steps:"
  echo "   1. Open http://$LAN_IP:${WEBUI_PORT} in your browser"
  echo "   2. Create your admin account"
  if $INSTALL_SEARXNG; then
    echo "   3. Go to Admin Panel → Settings → Web Search"
    echo "      Set SearXNG Query URL to:"
    echo "      http://localhost:8081/search?q=<query>&format=json"
  fi
  echo ""
fi
echo " Useful commands:"
echo "   docker ps                                   # check all containers"
$INSTALL_SEARXNG && echo "   docker logs searxng --tail 20               # SearXNG logs"
$INSTALL_WEBUI   && echo "   docker logs open-webui --tail 20            # Open WebUI logs"
echo "============================================="
echo ""

# =============================================================
# mcp.json generation (only if SearXNG installed)
# =============================================================
if $INSTALL_SEARXNG; then
  echo "---------------------------------------------"
  echo " Generate mcp.json for LM Studio?"
  echo ""
  echo " This creates the config to connect LM Studio"
  echo " to SearXNG via MCP. Paste it into:"
  echo " LM Studio → Developer tab → mcp.json"
  echo ""
  echo " Note: Requires Node.js LTS on this machine."
  echo ""
  read -p " Generate mcp.json? (y/n): " gen_mcp
  echo ""

  if [[ "$gen_mcp" =~ ^[Yy]$ ]]; then
    echo " Where will LM Studio be running?"
    echo "   1) This machine  — SearXNG URL will use localhost"
    echo "   2) Another machine on the network — enter its IP address"
    echo ""
    while true; do
      read -p " Enter choice [1-2]: " lms_choice
      case "$lms_choice" in
        1)
          SEARXNG_URL="http://localhost:8081"
          info "Using localhost."
          break
          ;;
        2)
          LAN_IP=$(hostname -I | awk '{print $1}')
          echo ""
          info "This machine's IP address is: $LAN_IP"
          info "Enter the IP of the machine where LM Studio is running."
          echo ""
          while true; do
            read -p " Enter the IP address of the machine running LM Studio: " lms_ip
            if [[ "$lms_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
              SEARXNG_URL="http://${lms_ip}:8081"
              info "Using $SEARXNG_URL"
              break
            else
              warn "Invalid IP address. Please enter a valid IPv4 address (e.g. 192.168.1.100)."
            fi
          done
          break
          ;;
        *) warn "Invalid choice. Please enter 1 or 2." ;;
      esac
    done
    echo ""

    # Resolve the actual user's home — SUDO_USER is set by sudo,
    # HOME may still point to /root when running as sudo bash
    ACTUAL_USER="${SUDO_USER:-}"
    if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
      ACTUAL_USER=$(who | awk 'NR==1{print $1}')
    fi
    if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
      USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
    else
      USER_HOME="/root"
    fi
    MCP_PATH="${USER_HOME}/mcp.json"
    cat > "$MCP_PATH" << EOF
{
  "mcpServers": {
    "searxng": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-searxng"
      ],
      "env": {
        "SEARXNG_URL": "${SEARXNG_URL}"
      }
    },
    "fetch": {
      "command": "npx",
      "args": ["mcp-fetch-server"],
      "env": {
        "DEFAULT_LIMIT": "50000"
      }
    }
  }
}
EOF
    chown "${ACTUAL_USER}:${ACTUAL_USER}" "$MCP_PATH" 2>/dev/null || true
    ok "mcp.json written to $MCP_PATH"
    echo ""
    echo "---------------------------------------------"
    cat "$MCP_PATH"
    echo "---------------------------------------------"
    echo ""
    info "Copy the above into LM Studio → Developer tab → mcp.json"
    echo ""
  fi
fi
