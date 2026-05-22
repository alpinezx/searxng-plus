# Daily Use & Quick Reference

## Daily Use

Docker, SearXNG and Open WebUI all start automatically on boot — no action needed.

| What | Where |
|------|-------|
| Open WebUI (local) | http://localhost:\<port\> |
| Open WebUI (network) | http://\<your-ubuntu-machine-ip\>:\<port\> |
| SearXNG (local) | http://localhost:8081 |
| SearXNG (network) | http://\<your-ubuntu-machine-ip\>:8081 |

SearXNG is also a fully functional private search engine usable in any browser. To set it as your default in Chrome, Edge, or Firefox, add it manually in browser settings using:
```
http://<your-ubuntu-machine-ip>:8081/search?q=%s
```

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

# Docker / system
sudo systemctl status docker
sudo systemctl restart docker
```
