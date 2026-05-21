# SearXNG — Configuration

## Editing the Configuration File

The config file lives at `/root/searxng-config/settings.yml`. Because the setup runs as root, you'll need `sudo` to edit it:

```bash
sudo nano /root/searxng-config/settings.yml
```

After saving, restart SearXNG for the changes to take effect:

```bash
sudo docker restart searxng
```

A few things worth knowing:

- **`use_default_settings: true`** at the top of the file is important — it means you only need to include the settings you want to override. SearXNG fills in everything else from its own defaults. Don't remove this line.
- **The port setting in `settings.yml` is ignored.** The port is controlled by the `-e SEARXNG_PORT=8081` flag in the docker run command. Don't bother changing it in the file.
- The full list of configurable options is documented at [docs.searxng.org](https://docs.searxng.org/admin/settings/index.html).

---

## Open WebUI Data

Open WebUI stores all user accounts, chat history, and settings in `/root/open-webui-data`. This directory persists across container restarts and updates.

To back it up:

```bash
sudo cp -r /root/open-webui-data /root/open-webui-data.bak
```
