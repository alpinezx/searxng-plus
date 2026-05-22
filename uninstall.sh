#!/bin/bash
# =============================================================
# uninstall.sh — Remove Open WebUI, SearXNG and/or Docker
# Ubuntu Edition
#
# Removes components installed by setup.sh:
#   — Open WebUI   (cloud model frontend + /root/open-webui-data)
#   — SearXNG      (private search + /root/searxng-config)
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
  has_docker=false

  if command -v docker &>/dev/null && docker info > /dev/null 2>&1; then
    has_docker=true
  fi

  if $has_docker; then
    docker ps -a --format '{{.Names}}' | grep -q '^searxng$' \
      && has_searxng=true || true
    docker ps -a --format '{{.Names}}' | grep -q '^open-webui$' \
      && has_open_webui=true || true
  fi

  # --- Header ---
  echo ""
  echo "============================================="
  echo " SearXNG + Open WebUI"
  echo " Uninstaller — Ubuntu Edition"
  echo "============================================="
  echo ""
  echo " System status:"
  echo ""
  $has_open_webui  && echo "   [x] Open WebUI  — installed" \
                   || echo "   [ ] Open WebUI  — not found"
  $has_searxng     && echo "   [x] SearXNG     — installed" \
                   || echo "   [ ] SearXNG     — not found"
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

  service_count=0
  $has_open_webui && service_count=$((service_count + 1))
  $has_searxng    && service_count=$((service_count + 1))

  if [ $service_count -gt 1 ]; then
    $has_open_webui && options+=("Remove Open WebUI only")
    $has_searxng    && options+=("Remove SearXNG only")

    if $has_open_webui && $has_searxng; then
      options+=("Remove Open WebUI and SearXNG")
    fi
  elif [ $service_count -eq 1 ]; then
    $has_open_webui && options+=("Remove Open WebUI")
    $has_searxng    && options+=("Remove SearXNG")
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

    "Remove Open WebUI and SearXNG")
      echo " This will remove Open WebUI and SearXNG, but keep Docker."
      if confirm; then
        remove_open_webui
        remove_searxng
        ubuntu_cleanup
        echo "============================================="
        echo " Open WebUI and SearXNG have been removed."
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
