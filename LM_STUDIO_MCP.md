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

SearXNG's built-in `web_url_read` tool can return cluttered output — image tags, anchor fragments, repeated boilerplate, and layout noise mixed in with the actual content. This wastes context window and makes it harder for your model to extract what it needs.

**mcp-fetch-server** replaces it with a cleaner alternative that uses Mozilla Readability (the same engine as Firefox Reader View) to extract just the article content as clean Markdown. Less noise, lower token usage, and a more reliable experience — particularly important when running local models with limited context windows.

**Privacy:** mcp-fetch-server runs entirely on your Windows machine via `npx`. Nothing leaves your network except the direct request to the target website — the same as opening the page in a browser. It is the fully private option for page reading.

**Limitation:** Like `web_url_read`, it can only read HTML that is present when the page first loads. JavaScript-heavy pages that render content dynamically after load may return incomplete or empty results. See the Jina Reader section below for how to handle those.

### Requirements

Make sure Node.js is installed on your Windows machine:

```bash
node --version
```

If it's not installed, download it from [nodejs.org](https://nodejs.org).

### Setup

Update your `mcp.json` in LM Studio → **Developer tab** to add mcp-fetch-server alongside SearXNG:

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
    }
  }
}
```

---

## Cleaner Web Page Reading with Jina Reader

Both `web_url_read` and `mcp-fetch-server` rely on extracting content from the HTML that is immediately available when a page loads. JavaScript-heavy pages — where content is rendered dynamically after load — can return empty or near-useless results with either tool.

**Jina Reader** solves this. It sends the URL to Jina AI's servers, which fetch and fully render the page in a real browser before returning clean Markdown. The result is noticeably cleaner output even on complex sites — tested against the Met Office forecast page, one of the more JavaScript-heavy pages in common use, it returned a fully structured hourly breakdown with no noise whatsoever.

It is free with no account or API key required. Anonymous usage is rate-limited to 20 requests per minute by IP, which is more than sufficient for normal research use. Node.js must be installed on your Windows machine — the same requirement as `mcp-fetch-server`.

**Privacy notice:** Jina Reader is a cloud service. URLs fetched through it are processed on Jina AI's servers and may be cached. No account is required for anonymous use, but if privacy is important to you, review Jina's current privacy policy at [jina.ai/legal](https://jina.ai/legal) before using it — noting that following their acquisition by Elastic in October 2025, their policies are in transition. For a fully local alternative, use mcp-fetch-server instead, accepting that JavaScript-heavy pages may not render cleanly.

### Setup

Update your `mcp.json` in LM Studio → **Developer tab** to add Jina Reader alongside SearXNG:

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
    "jina": {
      "command": "npx",
      "args": [
        "jina-mcp-tools",
        "--transport",
        "stdio"
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
    "jina": {
      "command": "npx",
      "args": [
        "jina-mcp-tools",
        "--transport",
        "stdio"
      ]
    }
  }
}
```

Once connected, enable `jina_reader` in the integrations panel. You can disable `web_url_read` from `mcp/searxng` — it is redundant once Jina is active.

> **Using mcp-fetch-server as well?** If you have both `mcp-fetch-server` and Jina Reader connected, your model has two reading tools available. `fetch_readable` is faster and fully local — prefer it for standard pages. `jina_reader` handles JavaScript-heavy pages that `fetch_readable` cannot render. Both can be enabled simultaneously and your model will use whichever is appropriate.

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
    "jina": {
      "command": "npx",
      "args": [
        "jina-mcp-tools",
        "--transport",
        "stdio"
      ]
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
    "jina": {
      "command": "npx",
      "args": [
        "jina-mcp-tools",
        "--transport",
        "stdio"
      ]
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

Once connected, enable `current_time` in the integrations panel alongside `searxng_web_search` and `jina_reader`.

---

## Which Tools to Enable

Every enabled tool is loaded into the model's context on every request, whether it's used or not. Keeping the list short means less wasted context and a cleaner experience.

Once all servers are connected, go to the integrations panel and **disable every tool**, then enable just these:

| Tool | Server |
|---|---|
| `searxng_web_search` | `mcp/searxng` |
| `jina_reader` | `mcp/jina` |
| `current_time` | `mcp/time` |

`searxng_web_search` finds pages. `jina_reader` reads them cleanly, including JavaScript-heavy pages that other tools cannot render. `current_time` ensures the model has accurate time context before searching.

If you also have `mcp-fetch-server` connected, add `fetch_readable` to the list. Use it for standard pages where speed matters — it is fully local and faster than Jina. Leave `web_url_read`, `fetch_raw`, and all other tools disabled; they are redundant once this set is active.

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

**jina-mcp-tools not connecting:**
Confirm Node.js is installed on your Windows machine (`node --version`). If the tool connects but returns errors on specific pages, the page may be blocking automated requests — this is normal for some sites. Try a different source for the same information.
