# SearXNG-Plus

> **Ubuntu only.** This script has only been tested on Ubuntu and is built on Ubuntu/Debian-specific tooling (`apt-get`, Docker's Ubuntu repository). Other distributions are not supported.

Automated setup script for a private local search engine (SearXNG), with optional Open WebUI and Playwright — all accessible across your local network.

**SearXNG** is a self-hosted, privacy-respecting meta search engine. It queries Google, Bing, DuckDuckGo and others simultaneously, strips out all ads and tracking, and returns clean results — served entirely from your own machine.

**Open WebUI** is a self-hosted chat interface for cloud AI models (OpenAI, Anthropic, Google, OpenRouter and others). It runs entirely on your network, keeps your conversations local, and connects to SearXNG for private web search inside chat.

**Playwright** is a local headless browser service that Open WebUI uses to extract content from JavaScript-heavy pages. It runs as a Docker container, version-matched automatically to Open WebUI, and starts instantly on every boot.

---

## Before You Start

- Make sure your Ubuntu installation is up to date:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- Note your machine's local IP address — you'll need it to access services from other devices:
  ```bash
  hostname -I
  ```

> **Running this on your main machine?** If Ubuntu is your primary desktop rather than a dedicated device, you can use `localhost` instead of the LAN IP when accessing services from the same machine.

---

## Installation

Open a terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/alpinezx/searxng-plus/refs/heads/main/setup.sh -o setup.sh && sudo bash setup.sh
```

The script installs Docker, walks you through a short configuration menu, launches all three containers, and verifies everything is working — all in one go. No restart required.

At the end, it prints your LAN IP with exact URLs for all services and the Playwright WebSocket URL to paste into Open WebUI.

---

## Daily Use

Docker, SearXNG, Open WebUI and Playwright all start automatically on boot — no action needed.

| What | Where |
|------|-------|
| Open WebUI (local) | http://localhost:\<port\> |
| Open WebUI (network) | http://\<your-ubuntu-machine-ip\>:\<port\> |
| SearXNG (local) | http://localhost:8081 |
| SearXNG (network) | http://\<your-ubuntu-machine-ip\>:8081 |
| Playwright | ws://localhost:3001 (internal only) |

SearXNG is also a fully functional private search engine usable in any browser. To set it as your default in Chrome, Edge, or Firefox, add it manually in browser settings using:
```
http://<your-ubuntu-machine-ip>:8081/search?q=%s
```

---

## Updates

When Open WebUI shows a "new version available" notification, run:

```bash
curl -fsSL https://raw.githubusercontent.com/alpinezx/searxng-plus/refs/heads/main/update.sh -o update.sh && sudo bash update.sh
```

The update script pulls the latest Open WebUI image, detects whether the internal Playwright version has changed, rebuilds the Playwright container if needed, and prints a summary of what was updated.

---

## Quick Reference Commands

```bash
# Check all containers are running
sudo docker ps

# SearXNG
sudo docker restart searxng
sudo docker logs searxng --tail 20
curl "http://localhost:8081/search?q=test&format=json"

# Open WebUI
sudo docker restart open-webui
sudo docker logs open-webui --tail 20

# Playwright
sudo docker restart playwright-chromium
sudo docker logs playwright-chromium --tail 20

# Docker / system
sudo systemctl status docker
sudo systemctl restart docker
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/alpinezx/searxng-plus/refs/heads/main/uninstall.sh -o uninstall.sh && sudo bash uninstall.sh
```

The script detects what is currently installed and presents a menu — remove individual services or everything at once. Each option asks for confirmation before doing anything.

For manual removal commands, see [Uninstall manually](UNINSTALL.md).

---

## Guides & Reference

- [Open WebUI Setup Guide](OPENWEBUI_SETUP.md)
- [SearXNG Configuration](SEARXNG_CONFIG.md)
- [LM Studio MCP Setup & Tips](LM_STUDIO_MCP.md)
- [System Prompt](SYSTEM_PROMPT.md)
- [Troubleshooting](TROUBLESHOOTING.md)
