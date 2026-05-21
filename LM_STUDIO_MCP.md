# LM Studio — MCP Setup & Tips

> **LM Studio on Windows.** This guide is written for LM Studio on Windows connecting to SearXNG running on an Ubuntu machine. The `mcp.json` format may work with other frontends, but the tool configuration steps described here are LM Studio specific.

---

## Connect SearXNG to LM Studio

The setup script can generate your `mcp.json` automatically at the end of the install — just say yes when prompted. Or configure it manually:

In LM Studio → **Developer tab** → `mcp.json`, replace the entire contents with:

```json
{
  "mcpServers": {
    "searxng": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-searxng"
      ],
      "env": {
        "SEARXNG_URL": "http://<your-ubuntu-machine-ip>:8081"
      }
    }
  }
}
```

Replace `<your-ubuntu-machine-ip>` with the IP address from `hostname -I` on your Ubuntu machine — for example `http://192.168.1.50:8081`.

> **Running LM Studio on the same machine as SearXNG?** Use `http://localhost:8081` instead of the LAN IP.

Save. Confirm `mcp/searxng` appears in the integrations panel with `searxng_web_search` and `web_url_read` tools active.

---

## Cleaner Web Page Reading with mcp-fetch-server

SearXNG includes a `web_url_read` tool for reading web pages, but it can return cluttered output — navbars, footers, ads, and other boilerplate mixed in with the actual content.

**mcp-fetch-server** is a free, no-API-key alternative that uses Mozilla Readability (the same engine as Firefox Reader View) to extract just the article content as clean Markdown. This means less noise for your model and significantly lower token usage — particularly important when running local models with limited context windows.

It runs entirely on your Windows machine via `npx` — nothing is installed on the Ubuntu server.

### Requirements

Make sure Node.js is installed on your Windows machine:

```bash
node --version
```

If it's not installed, download it from [nodejs.org](https://nodejs.org).

### Setup

Update your `mcp.json` in LM Studio → **Developer tab** to add the fetch server alongside SearXNG:

```json
{
  "mcpServers": {
    "searxng": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-searxng"
      ],
      "env": {
        "SEARXNG_URL": "http://<your-ubuntu-machine-ip>:8081"
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
```

---

## Which Tools to Enable

Every enabled tool is loaded into the model's context on every request, whether it's used or not. Keeping the list short means less wasted context and a cleaner experience.

Once both servers are connected, go to the integrations panel and **disable every tool**, then enable just these two:

| Tool | Server |
|---|---|
| `searxng_web_search` | `mcp/searxng` |
| `fetch_readable` | `mcp/fetch` |

That's all you need. `searxng_web_search` finds pages. `fetch_readable` reads them cleanly. The other tools in each server (`web_url_read`, `fetch_raw`, etc.) are redundant once this pair is active.

---

## Troubleshooting

**LM Studio "SEARXNG_URL not set" error:**
The URL must go in the `"env"` block in `mcp.json` as `SEARXNG_URL`, not in the `"args"` array. Double-check the structure matches the example above.

**LM Studio can't reach SearXNG:**
`localhost` won't work from a Windows machine — you must use the Ubuntu machine's LAN IP address in `mcp.json`. Verify SearXNG is reachable from Windows by opening a browser and visiting `http://<your-ubuntu-machine-ip>:8081` before troubleshooting LM Studio further.

**Tools not appearing after saving mcp.json:**
Restart LM Studio, or toggle the integration off and back on in the Developer tab.

**mcp-fetch-server not connecting:**
Confirm Node.js is installed on your Windows machine (`node --version`). `npx` is bundled with Node.js and is required to run `mcp-fetch-server`.
