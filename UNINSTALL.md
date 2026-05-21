# Manual Uninstall

If you prefer to remove things by hand rather than using the uninstall script, use the commands below.

## Playwright only

```bash
sudo docker rm -f playwright-chromium
sudo docker rmi playwright-server:latest
```

## Open WebUI only

```bash
sudo docker stop open-webui
sudo docker rm open-webui
sudo docker rmi ghcr.io/open-webui/open-webui:main
sudo rm -rf /root/open-webui-data
```

## SearXNG only

```bash
sudo docker stop searxng
sudo docker rm searxng
sudo docker rmi searxng/searxng
sudo rm -rf /root/searxng-config
```

## Docker

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
