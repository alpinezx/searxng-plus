# Troubleshooting

## Installation

**Script not run as root:**
The setup script must be run with `sudo bash setup.sh`. Running without `sudo` will exit immediately with an error message.

**Docker service not starting:**
Docker is managed by systemd. If it fails to start, check the service status:
```bash
sudo systemctl status docker
sudo journalctl -u docker --tail 30
```

**Docker GPG signature errors on apt-get update:**
The GPG key didn't save correctly. Re-run `setup.sh` from the beginning.

**Docker image download fails with TLS error (`bad record MAC`):**
A network hiccup corrupted the download mid-way. The script retries automatically. If it still fails, re-run — it removes and replaces containers cleanly.

**Re-running the script fails with a container name conflict:**
The script detects and removes existing containers automatically before launching.

---

## Containers & Services

**Open WebUI takes a long time to start:**
This is normal on first launch — it initialises its database and downloads some assets. The script waits up to 90 seconds. If it times out, check the logs:
```bash
sudo docker logs open-webui --tail 30
```

**Can't reach Open WebUI or SearXNG from another device:**
Make sure you're using your Ubuntu machine's LAN IP, not `localhost`. Run `hostname -I` on the Ubuntu machine to get it. Also check whether your firewall is blocking the ports:
```bash
sudo ufw status
```
If UFW is active, allow the ports:
```bash
sudo ufw allow 8081/tcp
sudo ufw allow <webui-port>/tcp
```

**SearXNG defaulting to port 8080 instead of 8081:**
The port must be passed as `-e SEARXNG_PORT=8081` in the docker run command. The port setting in `settings.yml` is ignored by the container.

**settings.yml permission denied:**
This shouldn't happen with the current script, but if you created the config manually, fix ownership and try again:
```bash
chown -R root:root /root/searxng-config
```

**Some 403 errors in SearXNG logs (e.g. Wikidata):**
Normal. Individual search engines occasionally block automated queries. Ignore these.

---

## Playwright

**Playwright WebSocket connection error (428 Precondition Required):**
The Playwright server version doesn't match Open WebUI. This can happen if Open WebUI updated and changed its internal Playwright version. Fix it by running the update script:
```bash
sudo bash update.sh
```
The update script detects the mismatch and rebuilds Playwright automatically.

**Playwright logs show no activity:**
The official Playwright server is intentionally quiet — it only logs errors. No log output during normal use is expected behaviour, not a problem.

**Playwright times out on some pages:**
Some sites actively block headless browsers. This is normal and not a fault with your setup — the Playwright container is working correctly. Most pages will load fine.

---

## Open WebUI Search

**Open WebUI web search not returning results:**
Go to **Admin Panel → Settings → Web Search** and verify the SearXNG URL is set to `http://localhost:8081/search?q=<query>&format=json`. Also make sure **Function Calling** is set to **Native** for the model in use.

**Anthropic / Google / OpenRouter models not appearing:**
These providers require an OpenAI-compatible connection entry. Make sure the URL and key are entered under **Admin Panel → Settings → Connections → Add OpenAI-compatible**.

---

## LM Studio

**LM Studio "SEARXNG_URL not set" error:**
The URL must go in the `"env"` block in `mcp.json` as `SEARXNG_URL`, not in the `"args"` array. Make sure you're using your Ubuntu machine's LAN IP, not `localhost`.

**LM Studio can't reach SearXNG:**
`localhost` won't work from a Windows machine — use the Ubuntu machine's LAN IP in `mcp.json`. Verify SearXNG is reachable from Windows by opening a browser and visiting `http://<your-ubuntu-machine-ip>:8081` before troubleshooting LM Studio further.

**Tools not appearing after saving mcp.json:**
Restart LM Studio, or toggle the integration off and back on in the Developer tab.
