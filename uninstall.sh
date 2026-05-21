#!/bin/bash
# =============================================================
# uninstall.sh — Remove Open WebUI, SearXNG, Playwright and/or Docker
# Ubuntu Edition
#
# Removes components installed by setup.sh:
#   — Open WebUI   (cloud model frontend + /root/open-webui-data)
#   — SearXNG      (private search + /root/searxng-config)
#   — Playwright   (browser service + local playwright-server images)
#   — Docker       (service, packages, keyrings, repo)
#
# Must be run as root: sudo bash uninstall.sh
# Detects what's installed and builds the menu dynamically.
# =============================================================

# --- Ensure running as root ---
if [ "$EUID" -ne 0 ]; then
  echo ""
  echo "ERROR: This script must be run as root."
  echo "       Please run: sudo bash uninstall.sh"
  echo ""
  exit 1
fi

# =============================================================
# Helper functions
# =============================================================

remove_playwright() {
  echo ""
  echo "--- Removing Playwright ---"

  if docker ps -a --format '{{.Names}}' | grep -q '^playwright-chromium$'; then
    echo "  Stopping and removing playwright-chromium container..."
    docker stop playwright-chromium > /dev/null 2>&1
    docker rm playwright-chromium > /dev/null 2>&1
    echo "  [x] Container removed."
  else
    echo "  [ ] No playwright-chromium container found — skipping."
  fi

  # Remove all local playwright-server images (versioned + latest tag)
  PW_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep '^playwright-server:' || true)
  if [ -n "$PW_IMAGES" ]; then
    echo "  Removing local Playwright images..."
    echo "$PW_IMAGES" | xargs docker rmi > /dev/null 2>&1 || true
    echo "  [x] Local Playwright images removed."
  else
    echo "  [ ] No local Playwright images found — skipping."
  fi

  # Remove the upstream base image if present
  PW_BASE=$(docker images --format '{{.Repository}}' \
    | grep '^mcr.microsoft.com/playwright$' || true)
  if [ -n "$PW_BASE" ]; then
    echo "  Removing Playwright base image..."
    docker images --format '{{.Repository}}:{{.Tag}}' \
      | grep '^mcr.microsoft.com/playwright:' \
      | xargs docker rmi > /dev/null 2>&1 || true
    echo "  [x] Base image removed."
  else
    echo "  [ ] No Playwright base image found — skipping."
  fi

  echo ""
}

remove_searxng() {
  echo ""
  echo "--- Removing SearXNG ---"

  if docker ps -a --format '{{.Names}}' | grep -q '^searxng$'; then
    echo "  Stopping and removing searxng container..."
    docker stop searxng > /dev/null 2>&1
    docker rm searxng > /dev/null 2>&1
    echo "  [x] Container removed."
  else
    echo "  [ ] No searxng container found — skipping."
  fi

  if docker images --format '{{.Repository}}' | grep -q '^searxng/searxng$'; then
    echo "  Removing searxng image..."
    docker rmi searxng/searxng > /dev/null 2>&1
    echo "  [x] Image removed."
  else
    echo "  [ ] No searxng image found — skipping."
  fi

  if [ -d /root/searxng-config ]; then
    echo "  Removing /root/searxng-config..."
    rm -rf /root/searxng-config
    echo "  [x] Config directory removed."
  else
    echo "  [ ] No searxng-config directory found — skipping."
  fi

  echo ""
}

remove_open_webui() {
  echo ""
  echo "--- Removing Open WebUI ---"

  if docker ps -a --format '{{.Names}}' | grep -q '^open-webui$'; then
    echo "  Stopping and removing open-webui container..."
    docker stop open-webui > /dev/null 2>&1
    docker rm open-webui > /dev/null 2>&1
    echo "  [x] Container removed."
  else
    echo "  [ ] No open-webui container found — skipping."
  fi

  if docker images --format '{{.Repository}}' | grep -q '^ghcr.io/open-webui/open-webui$'; then
    echo "  Removing Open WebUI image..."
    docker rmi ghcr.io/open-webui/open-webui:main > /dev/null 2>&1
    echo "  [x] Image removed."
  else
    echo "  [ ] No Open WebUI image found — skipping."
  fi

  if [ -d /root/open-webui-data ]; then
    echo "  Removing /root/open-webui-data..."
    rm -rf /root/open-webui-data
    echo "  [x] Data directory removed."
  else
    echo "  [ ] No open-webui-data directory found — skipping."
  fi

  echo ""
}

remove_docker() {
  echo ""
  echo "--- Removing Docker ---"

  if docker images --format '{{.Repository}}' | grep -q '^hello-world$'; then
    echo "  Removing hello-world image..."
    docker rmi hello-world > /dev/null 2>&1
    echo "  [x] hello-world image removed."
  fi

  echo "  Stopping Docker service..."
  systemctl stop docker 2>/dev/null || true
  systemctl disable docker 2>/dev/null || true

  echo "  Uninstalling Docker packages..."
  apt-get purge -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin 2>/dev/null
  rm -rf /var/lib/docker
  rm -rf /var/lib/containerd
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.asc
  echo "  [x] Docker removed."
  echo ""
}

ubuntu_cleanup() {
  echo "--- Running Ubuntu cleanup ---"
  apt-get autoremove -y
  apt-get clean
  echo "  [x] Cleanup complete."
  echo ""
}

confirm() {
  read -p " Are you sure? (y/n): " answer
  echo ""
  [[ "$answer" =~ ^[Yy]$ ]]
}

# =============================================================
# Main loop — re-runs after each action to refresh the menu
# =============================================================

while true; do

  # --- Detect what's installed ---
  has_searxng=false
  has_open_webui=false
  has_playwright=false
  has_docker=false

  if command -v docker &>/dev/null && docker info > /dev/null 2>&1; then
    has_docker=true
  fi

  if $has_docker; then
    docker ps -a --format '{{.Names}}' | grep -q '^searxng$' \
      && has_searxng=true || true
    docker ps -a --format '{{.Names}}' | grep -q '^open-webui$' \
      && has_open_webui=true || true
    docker ps -a --format '{{.Names}}' | grep -q '^playwright-chromium$' \
      && has_playwright=true || true
  fi

  # --- Header ---
  echo ""
  echo "============================================="
  echo " SearXNG + Open WebUI + Playwright"
  echo " Uninstaller — Ubuntu Edition"
  echo "============================================="
  echo ""
  echo " System status:"
  echo ""
  $has_open_webui  && echo "   [x] Open WebUI  — installed" \
                   || echo "   [ ] Open WebUI  — not found"
  $has_searxng     && echo "   [x] SearXNG     — installed" \
                   || echo "   [ ] SearXNG     — not found"
  $has_playwright  && echo "   [x] Playwright  — installed" \
                   || echo "   [ ] Playwright  — not found"
  $has_docker      && echo "   [x] Docker      — installed" \
                   || echo "   [ ] Docker      — not found"
  echo ""

  # --- Build dynamic menu ---
  options=()

  # Individual removal options — only shown when multiple services exist
  # so the menu doesn't show redundant single-item options
  any_service=false
  $has_open_webui && any_service=true
  $has_searxng    && any_service=true
  $has_playwright && any_service=true

  service_count=0
  $has_open_webui && service_count=$((service_count + 1))
  $has_searxng    && service_count=$((service_count + 1))
  $has_playwright && service_count=$((service_count + 1))

  if [ $service_count -gt 1 ]; then
    $has_open_webui && options+=("Remove Open WebUI only")
    $has_searxng    && options+=("Remove SearXNG only")
    $has_playwright && options+=("Remove Playwright only")

    if $has_open_webui && $has_searxng && $has_playwright; then
      options+=("Remove Open WebUI, SearXNG and Playwright")
    elif $has_open_webui && $has_searxng; then
      options+=("Remove Open WebUI and SearXNG")
    elif $has_open_webui && $has_playwright; then
      options+=("Remove Open WebUI and Playwright")
    elif $has_searxng && $has_playwright; then
      options+=("Remove SearXNG and Playwright")
    fi
  elif [ $service_count -eq 1 ]; then
    $has_open_webui && options+=("Remove Open WebUI")
    $has_searxng    && options+=("Remove SearXNG")
    $has_playwright && options+=("Remove Playwright")
  fi

  if $has_docker; then
    options+=("Remove everything (all services, Docker, Ubuntu cleanup)")
  fi

  options+=("Exit")

  # --- Nothing meaningful to remove ---
  if [ ${#options[@]} -eq 1 ]; then
    echo " Nothing installed to remove. Exiting."
    echo ""
    exit 0
  fi

  # --- Print menu ---
  echo " What would you like to do?"
  echo ""
  for i in "${!options[@]}"; do
    echo "   $((i+1))) ${options[$i]}"
  done
  echo ""
  read -p " Enter choice [1-${#options[@]}]: " choice
  echo ""

  # --- Validate input ---
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || \
     [ "$choice" -lt 1 ] || \
     [ "$choice" -gt "${#options[@]}" ]; then
    echo " Invalid choice. Please try again."
    continue
  fi

  selected="${options[$((choice-1))]}"

  # --- Handle selection ---
  case "$selected" in

    "Remove Open WebUI only"|"Remove Open WebUI")
      echo " This will remove the Open WebUI container, image and data directory."
      if confirm; then
        remove_open_webui
        ubuntu_cleanup
        echo "============================================="
        echo " Open WebUI has been removed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove SearXNG only"|"Remove SearXNG")
      echo " This will remove the SearXNG container, image and config directory."
      if confirm; then
        remove_searxng
        ubuntu_cleanup
        echo "============================================="
        echo " SearXNG has been removed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove Playwright only"|"Remove Playwright")
      echo " This will remove the Playwright container and all local Playwright images."
      if confirm; then
        remove_playwright
        ubuntu_cleanup
        echo "============================================="
        echo " Playwright has been removed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove Open WebUI and SearXNG")
      echo " This will remove Open WebUI and SearXNG, but keep Playwright and Docker."
      if confirm; then
        remove_open_webui
        remove_searxng
        ubuntu_cleanup
        echo "============================================="
        echo " Open WebUI and SearXNG have been removed."
        echo " Playwright and Docker are still installed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove Open WebUI and Playwright")
      echo " This will remove Open WebUI and Playwright, but keep SearXNG and Docker."
      if confirm; then
        remove_open_webui
        remove_playwright
        ubuntu_cleanup
        echo "============================================="
        echo " Open WebUI and Playwright have been removed."
        echo " SearXNG and Docker are still installed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove SearXNG and Playwright")
      echo " This will remove SearXNG and Playwright, but keep Open WebUI and Docker."
      if confirm; then
        remove_searxng
        remove_playwright
        ubuntu_cleanup
        echo "============================================="
        echo " SearXNG and Playwright have been removed."
        echo " Open WebUI and Docker are still installed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove Open WebUI, SearXNG and Playwright")
      echo " This will remove all three services, but keep Docker."
      if confirm; then
        remove_open_webui
        remove_searxng
        remove_playwright
        ubuntu_cleanup
        echo "============================================="
        echo " Open WebUI, SearXNG and Playwright removed."
        echo " Docker is still installed."
        echo "============================================="
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Remove everything (all services, Docker, Ubuntu cleanup)")
      echo " WARNING: This will remove all services and Docker entirely."
      echo " All data and config directories will be permanently deleted."
      if confirm; then
        remove_open_webui
        remove_searxng
        remove_playwright
        remove_docker
        ubuntu_cleanup
        echo "============================================="
        echo " Uninstall complete."
        echo "============================================="
        echo ""
        exit 0
      else
        echo " Cancelled. Nothing was removed."
      fi
      ;;

    "Exit")
      echo " Exiting. Nothing was removed."
      echo ""
      exit 0
      ;;

  esac

done
