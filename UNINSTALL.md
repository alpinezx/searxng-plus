# Uninstall

## Using the uninstall script (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/alpinezx/ubuntu-searxng-openwebui-playwright/refs/heads/main/uninstall.sh -o uninstall.sh && sudo bash uninstall.sh
```

The script detects what is currently installed and builds a menu based on what it finds. Each option asks for confirmation before doing anything. Options that no longer apply are removed automatically after each action.

---

## Manual uninstall

### Playwright only

```bash
sudo docker rm -f playwright-chromium
sudo docker rmi playwright-server:latest
```

### Open WebUI only

```bash
sudo docker stop open-webui
sudo docker rm open-webui
sudo docker rmi ghcr.io/open-webui/open-webui:main
sudo rm -rf /root/open-webui-data
```

### SearXNG only

```bash
sudo docker stop searxng
sudo docker rm searxng
sudo docker rmi searxng/searxng
sudo rm -rf /root/searxng-config
```

### Docker

```bash
sudo systemctl stop docker
sudo systemctl disable docker
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.asc
sudo apt-get autoremove -y
```
