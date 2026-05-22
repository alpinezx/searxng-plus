# Open WebUI — Setup Guide

On first launch, Open WebUI will ask you to create an admin account. This is local only — no external registration required.

Once logged in, go to **Admin Panel → Settings** to complete the setup below.

---

## 1. Add your API keys

Go to **Admin Panel → Settings → Connections**. Click the **+** button next to OpenAI API to add a new connection for each provider you want to use.

In the Edit Connection dialog, set the URL and paste your API key into the API Key field:

| Provider | URL | Key |
|---|---|---|
| OpenAI | `https://api.openai.com/v1` | Your `sk-...` key |
| Anthropic | `https://api.anthropic.com/v1` | Your Anthropic key |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | Your Google AI key |
| OpenRouter | `https://openrouter.ai/api/v1` | Your OpenRouter key |

Click **Save** after each one.

---

## 2. Set up SearXNG web search

All settings below are in **Admin Panel → Settings → Web Search**.

### General section

| Setting | Recommended value | Why |
|---|---|---|
| Web Search | On | Enables web search in chat |
| Web Search Engine | `searxng` | Your local private search engine |
| SearXNG Query URL | `http://localhost:8081/search?q=<query>&format=json` | Required for SearXNG to work |
| SearXNG Search Language | `all` | Results in any language; change to `en` for English only |
| Search Result Count | `3` | Enough for quality answers without excessive page loading |
| Concurrent Requests | `1` | Sequential is fast enough and avoids multiple simultaneous requests |
| Fetch URL Content Length Limit | No limit | Leave as is unless the AI is overwhelmed by very long pages |
| Domain Filter List | Empty | Leave empty unless you want to permanently block specific sites |
| Bypass Embedding and Retrieval | **Off** | Enabling this causes unreliable model behaviour — leave it off |
| Bypass Web Loader | Off | Leave off |
| Trust Proxy Environment | Either | Only relevant if you use a network proxy |

Click **Save** when done.

> **Web Loader Engine:** Leave this on `default`. The other options (Firecrawl, etc.) require external API keys and are outside the scope of this setup.

> **Not using SearXNG?** The General section settings apply regardless of which search engine you use.

---

## 3. Enable web search per model (optional)

By default, the web search button does not appear in the chat input. To enable it permanently for a model:

Go to **Admin Panel → Settings → Models**, select a model, scroll down to **Default Features**, and tick **Web Search**. Click **Save & Update**.

The web search icon will now appear next to the chat input box whenever that model is selected.

---

## 4. Set Function Calling to Native for every model

While in **Admin Panel → Models**, open each model you use and scroll down to **Advanced Params**. Find **Function Calling** and set it to **Native**.

> **This is strongly recommended.** Leaving Function Calling on its default setting causes web search to behave unreliably. Setting it to Native for every model is essential for stable search results.

---

## 5. Set a system prompt for reliable web search

Without a system prompt, models will often give up after hitting a failed or empty search result — asking for guidance instead of pushing through. A good system prompt fixes this.

Add this to the **System Prompt** field when setting up a model in **Admin Panel → Models**, or paste it into the chat system prompt box:

```
You are a research-focused AI assistant with access to web search and URL-reading tools.

SEARCH STRATEGY
- Use web search and URL-reading tools proactively without waiting to be asked.
- Keep searching and fetching until the request is comprehensively covered,
  not just partially answerable.
- If results are weak, conflicting, or outdated, reformulate and search again.

URL READING
- Always read full pages rather than relying on snippets, headlines, or previews.
- If a source fails, times out, or returns empty results, immediately try alternative
  sources — do not stop or ask for guidance.

DEFAULT OPERATING PRINCIPLE
A good answer is accurate and complete, not just fast.
```

> **This makes a significant difference to search reliability.** Models without this guidance tend to stop at the first obstacle and ask what to do next. With it, they push through failed sources and return complete, well-supported answers.

For a full research-grade system prompt covering source quality, reasoning, response style, and more, see [SYSTEM_PROMPT.md](SYSTEM_PROMPT.md).
