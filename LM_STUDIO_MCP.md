# LM Studio — MCP Setup & Tips

> **LM Studio on Windows.** This guide is written for LM Studio on Windows connecting to SearXNG running on an Ubuntu machine. The `mcp.json` format may work with other frontends, but the tool configuration steps described here are LM Studio specific.

---

## Connect SearXNG to LM Studio

The setup script generates your `mcp.json` automatically at the end of the install — just say yes when prompted. It will ask whether LM Studio is running on the same machine as SearXNG or on a different device, and write the correct URL automatically. No manual IP entry needed.

To configure it manually, use whichever option matches your setup.

**LM Studio on the same machine as SearXNG:**

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
        "SEARXNG_URL": "http://localhost:8081"
      }
    }
  }
}
```

**LM Studio on a different machine on the network** (e.g. a Windows PC connecting to a Ubuntu server or mini PC):

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

Replace `<your-ubuntu-machine-ip>` with the LAN IP of the machine running SearXNG — run `hostname -I` on that machine to get it, for example `http://192.168.1.50:8081`.

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

## Adding the Time MCP Server

Unlike Open WebUI, LM Studio does not inject the current date and time automatically. Without this context, models can misinterpret cached or stale search results as current — for example, treating yesterday's forecast as today's weather, or referencing outdated news as breaking.

**@mcpcentral/mcp-time** solves this by giving the model accurate time context before it searches. The system prompt instructs the model to check the time first — but it needs this MCP active to do so.

Update your `mcp.json` to add the time server. Use whichever base URL matches your setup:

**Same machine:**

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
        "SEARXNG_URL": "http://localhost:8081"
      }
    },
    "fetch": {
      "command": "npx",
      "args": ["mcp-fetch-server"],
      "env": {
        "DEFAULT_LIMIT": "50000"
      }
    },
    "time": {
      "command": "npx",
      "args": [
        "-y",
        "@mcpcentral/mcp-time"
      ]
    }
  }
}
```

**Different machine:**

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
    },
    "time": {
      "command": "npx",
      "args": [
        "-y",
        "@mcpcentral/mcp-time"
      ]
    }
  }
}
```

Once connected, enable `current_time` in the integrations panel alongside `searxng_web_search` and `fetch_readable`.

---

## Which Tools to Enable

Every enabled tool is loaded into the model's context on every request, whether it's used or not. Keeping the list short means less wasted context and a cleaner experience.

Once all three servers are connected, go to the integrations panel and **disable every tool**, then enable just these three:

| Tool | Server |
|---|---|
| `searxng_web_search` | `mcp/searxng` |
| `fetch_readable` | `mcp/fetch` |
| `current_time` | `mcp/time` |

That's all you need. `searxng_web_search` finds pages. `fetch_readable` reads them cleanly. `current_time` ensures the model has accurate time context before searching. The other tools in each server (`web_url_read`, `fetch_raw`, etc.) are redundant once this set is active.

---

## Troubleshooting

**LM Studio "SEARXNG_URL not set" error:**
The URL must go in the `"env"` block in `mcp.json` as `SEARXNG_URL`, not in the `"args"` array. Double-check the structure matches the example above.

**LM Studio can't reach SearXNG:**
If LM Studio is on a different machine, `localhost` won't work — you must use the LAN IP of the machine running SearXNG in `mcp.json`. Verify SearXNG is reachable by opening a browser on the LM Studio machine and visiting `http://<your-ubuntu-machine-ip>:8081` before troubleshooting further. If LM Studio and SearXNG are on the same machine, `localhost` is correct.

**Tools not appearing after saving mcp.json:**
Restart LM Studio, or toggle the integration off and back on in the Developer tab.

**mcp-fetch-server not connecting:**
Confirm Node.js is installed on your Windows machine (`node --version`). `npx` is bundled with Node.js and is required to run `mcp-fetch-server`.

**mcp-time not connecting:**
Same requirement as above — Node.js must be installed. Run `npx @mcpcentral/mcp-time --version` in a Windows terminal to verify it can be reached.
