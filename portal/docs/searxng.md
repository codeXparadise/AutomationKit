<div align="center">
  <img src="../assets/logos/searxng.svg" width="64" height="64" alt="SearXNG Logo" />
  <h1>SearXNG — n8n Integration & API Guide</h1>
  <p><strong>Privacy-Respecting Metasearch Engine for Real-Time AI Agent Browsing</strong></p>
</div>

> **Docker Internal URL (Use in n8n):** `http://searxng:8080`  
> **Host URL (Browser / Postman):** `http://localhost:8080` (or mapped port)  
> **Authentication:** None (No API key required on internal network)  

SearXNG is an open-source, privacy-respecting metasearch engine that aggregates results from over 70 search services (Google, DuckDuckGo, Bing, Wikipedia, GitHub, Reddit, ArXiv). It allows your n8n AI workflows and agents to browse the live web in real time with **zero external API fees** (replacing paid tools like SerpAPI, Tavily, or Google Search API).

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
- [2. Search Endpoints Reference](#2-search-endpoints-reference)
  - [2.1 Basic Web Search (`GET /search`)](#21-basic-web-search-get-search)
  - [2.2 News Search (`GET /search?categories=news`)](#22-news-search-get-searchcategoriesnews)
  - [2.3 Science & Academic Papers (`GET /search?categories=science`)](#23-science--academic-papers-get-searchcategoriesscience)
  - [2.4 Code & GitHub Search (`GET /search?categories=it`)](#24-code--github-search-get-searchcategoriesit)
- [3. Query Parameters Reference](#3-query-parameters-reference)
- [4. Creating a Real-Time Web Search Tool for n8n AI Agents](#4-creating-a-real-time-web-search-tool-for-n8n-ai-agents)
- [5. Ready-to-Import n8n Workflow JSON](#5-ready-to-import-n8n-workflow-json)
- [6. Performance & Search Tips](#6-performance--search-tips)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

SearXNG runs inside the Docker network without requiring API tokens or passwords:

- In your n8n **HTTP Request** node:
  - **Authentication:** `None`
  - **URL:** `http://searxng:8080/search`

---

## 2. Search Endpoints Reference

> [!IMPORTANT]
> **Always include `format=json` in your query parameters!**  
> Without `format=json`, SearXNG returns HTML intended for browsers rather than parsable JSON for n8n.

### 2.1 Basic Web Search (`GET /search`)

Performs a standard web query aggregating Google, DuckDuckGo, and Bing.

#### cURL Command
```bash
curl -X GET "http://searxng:8080/search?q=latest+advances+in+artificial+intelligence&format=json"
```

#### n8n HTTP Request Configuration
- **Method:** `GET`
- **URL:** `http://searxng:8080/search`
- **Authentication:** `None`
- **Send Query Parameters:** `true`
- **Specify Query Parameters:** `Using Fields Below`
  - Parameter 1:
    - **Name:** `q`
    - **Value:** `={{ $json.query }}`
  - Parameter 2:
    - **Name:** `format`
    - **Value:** `json`

#### Response Structure
```json
{
  "query": "latest advances in artificial intelligence",
  "number_of_results": 184000,
  "results": [
    {
      "url": "https://example.com/ai-breakthrough",
      "title": "Major Breakthroughs in AI 2026",
      "content": "Researchers have announced new multimodal foundation models...",
      "engine": "duckduckgo",
      "score": 2.45
    }
  ]
}
```

---

### 2.2 News Search (`GET /search?categories=news`)

Restricts the search to current news outlets.

#### cURL Command
```bash
curl -X GET "http://searxng:8080/search?q=technology&categories=news&time_range=day&format=json"
```

#### Query Parameters
- `categories`: `news`
- `time_range`: `day` (or `week`)
- `format`: `json`

---

### 2.3 Science & Academic Papers (`GET /search?categories=science`)

Aggregates scientific publications from ArXiv, CrossRef, PubMed, and Google Scholar.

#### cURL Command
```bash
curl -X GET "http://searxng:8080/search?q=quantum+computing+algorithms&categories=science&format=json"
```

---

### 2.4 Code & GitHub Search (`GET /search?categories=it`)

Searches repositories, documentation, and technical forums (GitHub, StackOverflow, GitLab).

#### cURL Command
```bash
curl -X GET "http://searxng:8080/search?q=fastapi+jwt+authentication&categories=it&format=json"
```

---

## 3. Query Parameters Reference

| Parameter | Type | Default | Description | Example Values |
| :--- | :--- | :--- | :--- | :--- |
| `q` | string | *required* | The search keywords | `n8n self hosted automation` |
| `format` | string | `html` | Must be `json` for n8n | `json` |
| `categories` | string | `general` | Category filter | `general`, `news`, `science`, `it`, `images` |
| `engines` | string | all | Specific engines | `google,duckduckgo,bing,wikipedia` |
| `time_range` | string | none | Time recency | `day`, `week`, `month`, `year` |
| `language` | string | `all` | Results language | `en`, `hi`, `es`, `de` |
| `pageno` | integer | `1` | Page number | `1`, `2`, `3` |

---

## 4. Creating a Real-Time Web Search Tool for n8n AI Agents

You can turn SearXNG into a live web-browsing tool for n8n's **AI Agent** node:

```
[ Chat / Webhook Input ]
           |
     [ AI Agent ]  <---> [ Ollama Chat Model (http://ollama:11434) ]
           ^
           | (Tool Port)
           v
  [ Custom n8n Tool: Web Search ]
           |
  [ HTTP Request: http://searxng:8080/search?q={query}&format=json ]
```

1. Drag a **Custom n8n Tool** node onto the canvas.
2. In the tool settings:
   - **Name:** `web_search`
   - **Description:** `Search the live internet for recent news, technical documentation, or real-time information.`
3. Connect the output of the tool to an **HTTP Request** node configured with:
   - **URL:** `http://searxng:8080/search`
   - **Query Parameters:** `q` = `={{ $fromAI('query', 'The search query string') }}`, `format` = `json`
4. Connect the Tool to the **Tools** input port on your **AI Agent** node.

---

## 5. Ready-to-Import n8n Workflow JSON

Copy this JSON and paste (`Ctrl + V`) into your n8n workflow canvas to immediately test querying SearXNG:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "search_term",
              "name": "search_query",
              "value": "n8n automation best practices",
              "type": "string"
            }
          ]
        }
      },
      "id": "set-search-query",
      "name": "Set Search Query",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "GET",
        "url": "http://searxng:8080/search",
        "sendQuery": true,
        "queryParameters": {
          "parameters": [
            {
              "name": "q",
              "value": "={{ $json.search_query }}"
            },
            {
              "name": "format",
              "value": "json"
            }
          ]
        },
        "options": {
          "timeout": 30000
        }
      },
      "id": "searxng-request",
      "name": "SearXNG Web Search",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Set Search Query": {
      "main": [
        [
          {
            "node": "SearXNG Web Search",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  }
}
```

---

## 6. Performance & Search Tips

1. **Filtering Results:**  
   The response returns an array under `results`. Use an n8n **Code** or **Item Lists** node to extract only the top 3-5 results (`$json.results.slice(0, 5)`) before passing them to an LLM context to prevent token overflow.
2. **Rate Limits:**  
   SearXNG itself does not rate limit, but upstream search engines (like Google) may occasionally throttle rapid bursts. Distributing requests across DuckDuckGo and Bing ensures 100% uptime.
