<div align="center">
  <img src="../assets/logos/crawl4ai.svg" width="64" height="64" alt="Crawl4AI Logo" />
  <h1>Crawl4AI — n8n Integration & API Guide</h1>
  <p><strong>High-Performance Playwright Web Crawler & Markdown Scraper for LLMs</strong></p>
</div>

> **Docker Internal URL (Use in n8n):** `http://crawl4ai:11235`  
> **Host URL (Browser / Postman):** `http://localhost:11235`  
> **Interactive Swagger UI:** `http://localhost:11235/docs`  
> **OpenAPI Schema:** `http://localhost:11235/openapi.json`  
> **Authentication Header:** `Authorization: Bearer ${CRAWL4AI_API_KEY}`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${CRAWL4AI_API_KEY}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

Crawl4AI is an open-source, asynchronous web crawler and scraper optimized for LLM applications. Powered by headless Playwright, it renders full single-page JavaScript apps (React, Vue, Next.js), bypasses anti-bot scripts, extracts structured Markdown, takes screenshots, and returns clean text ready for AI agents.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
- [2. Health & Status Check](#2-health--status-check)
  - [2.1 Health Status (`GET /health`)](#21-health-status-get-health)
- [3. Core Scraping & Extraction Endpoints](#3-core-scraping--extraction-endpoints)
  - [3.1 Full Crawl to LLM Markdown (`POST /crawl`)](#31-full-crawl-to-llm-markdown-post-crawl)
  - [3.2 Quick Direct Markdown (`POST /md`)](#32-quick-direct-markdown-post-md)
  - [3.3 Rendered HTML Extraction (`POST /html`)](#33-rendered-html-extraction-post-html)
- [4. Advanced Browser Actions](#4-advanced-browser-actions)
  - [4.1 Capturing Page Screenshots (`POST /screenshot`)](#41-capturing-page-screenshots-post-screenshot)
  - [4.2 Generating Page PDFs (`POST /pdf`)](#42-generating-page-pdfs-post-pdf)
  - [4.3 Running Custom JavaScript (`POST /execute_js`)](#43-running-custom-javascript-post-execute_js)
- [5. Structured Schema & LLM Extraction (`POST /llm/job`)](#5-structured-schema--llm-extraction-post-llmjob)
- [6. Ready-to-Import n8n Workflow JSON](#6-ready-to-import-n8n-workflow-json)
- [7. Common Scraper Tricks & Gotchas](#7-common-scraper-tricks--gotchas)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

To set up credentials once in n8n and reuse them in any HTTP Request node:

1. In n8n, click **Credentials** → **Add Credential**.
2. Select **Header Auth**.
3. Configure the credential:
   - **Credential Name:** `Crawl4AI Auth`
   - **Name:** `Authorization`
   - **Value:** `Bearer ${CRAWL4AI_API_KEY}`
4. Click **Save**.

Now, inside your HTTP Request node, select **Authentication** → **Predefined Credential Type** → **Header Auth** → **Crawl4AI Auth**.

---

## 2. Health & Status Check

### 2.1 Health Status (`GET /health`)

#### cURL Command
```bash
curl -X GET "http://crawl4ai:11235/health" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}"
```

#### n8n HTTP Request Configuration
- **Method:** `GET`
- **URL:** `http://crawl4ai:11235/health`
- **Authentication:** `Header Auth`

#### Expected Response
```json
{
  "status": "healthy"
}
```

---

## 3. Core Scraping & Extraction Endpoints

### 3.1 Full Crawl to LLM Markdown (`POST /crawl`)

This is the primary endpoint for extracting clean, semantic Markdown from dynamic web pages with full Playwright rendering.

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/crawl" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "urls": ["https://news.ycombinator.com"],
    "priority": 10,
    "crawler_params": {
      "headless": true,
      "page_timeout": 30000
    },
    "extra": {
      "word_count_threshold": 10
    }
  }'
```

#### n8n HTTP Request Node Configuration
- **Method:** `POST`
- **URL:** `http://crawl4ai:11235/crawl`
- **Authentication:** `Header Auth`
- **Send Body:** `true`
- **Body Content Type:** `JSON`
- **Specify Body:** `Using JSON`
- **JSON Body:**
  ```json
  {
    "urls": ["={{ $json.url }}"],
    "priority": 10,
    "crawler_params": {
      "headless": true,
      "page_timeout": 30000
    }
  }
  ```

#### Response Structure
```json
{
  "success": true,
  "results": [
    {
      "url": "https://news.ycombinator.com",
      "markdown": "# Hacker News\n\n1. Show HN: Docling (github.com)...",
      "cleaned_html": "...",
      "media": { "images": [], "videos": [] },
      "links": { "internal": [], "external": [] },
      "metadata": {
        "title": "Hacker News",
        "description": "..."
      }
    }
  ]
}
```

---

### 3.2 Quick Direct Markdown (`POST /md`)

A simplified, fast endpoint designed specifically to retrieve only the converted Markdown text.

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/md" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://en.wikipedia.org/wiki/Artificial_intelligence"
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `POST`
- **URL:** `http://crawl4ai:11235/md`
- **Authentication:** `Header Auth`
- **JSON Body:**
  ```json
  {
    "url": "={{ $json.url }}"
  }
  ```

---

### 3.3 Rendered HTML Extraction (`POST /html`)

Retrieves the post-JavaScript executed DOM HTML tree.

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/html" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://react.dev"
  }'
```

---

## 4. Advanced Browser Actions

### 4.1 Capturing Page Screenshots (`POST /screenshot`)

Takes a high-resolution screenshot of a website (full page or viewport).

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/screenshot" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://github.com",
    "screenshot_wait_for": 2,
    "full_page": true
  }'
```

#### Response
Returns a JSON object containing a base64-encoded image string:
```json
{
  "success": true,
  "screenshot": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
}
```

---

### 4.2 Generating Page PDFs (`POST /pdf`)

Renders the webpage as a clean PDF document.

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/pdf" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://stripe.com/docs",
    "pdf_options": {
      "format": "A4",
      "print_background": true
    }
  }'
```

---

### 4.3 Running Custom JavaScript (`POST /execute_js`)

Execute browser actions prior to extraction (e.g. clicking "Accept Cookies", closing popups, or scrolling down infinitely).

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/execute_js" \
  -H "Authorization: Bearer ${CRAWL4AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "js_code": "window.scrollTo(0, document.body.scrollHeight); return document.title;"
  }'
```

---

## 5. Structured Schema & LLM Extraction (`POST /llm/job`)

Use Crawl4AI to automatically extract structured entities (e.g. product names, prices, reviews) by passing a target schema:

#### cURL Command
```bash
curl -X POST "http://crawl4ai:11235/llm/job" \
  -H "Authorization: Bearer ${CRAWL4AI_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://ecommerce-example.com/product/123",
    "extraction_strategy": "LLMExtractionStrategy",
    "schema": {
      "title": "Product",
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "price": { "type": "number" },
        "in_stock": { "type": "boolean" }
      }
    }
  }'
```

---

## 6. Ready-to-Import n8n Workflow JSON

Copy this JSON, go to n8n, and press `Ctrl + V` to import a working web scraper workflow that takes a URL, crawls it via Crawl4AI, and extracts clean Markdown:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "target_url",
              "name": "target_url",
              "value": "https://news.ycombinator.com",
              "type": "string"
            }
          ]
        }
      },
      "id": "scraper-input",
      "name": "Input Scrape Target",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://crawl4ai:11235/crawl",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": true,
        "contentType": "json",
        "body": "={\n  \"urls\": [\"{{ $json.target_url }}\"],\n  \"priority\": 10,\n  \"crawler_params\": {\n    \"headless\": true,\n    \"page_timeout\": 30000\n  }\n}",
        "options": {
          "timeout": 60000
        }
      },
      "id": "crawl4ai-scrape",
      "name": "Crawl4AI Scraping Node",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Input Scrape Target": {
      "main": [
        [
          {
            "node": "Crawl4AI Scraping Node",
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

## 7. Common Scraper Tricks & Gotchas

1. **Anti-Bot & Cloudflare Protection:**  
   If a website blocks standard headless requests, enable `magic: true` or pass custom `user_agent` in `crawler_params`.
2. **Infinite Scroll Pages:**  
   Provide a `wait_for` condition or a JS scroll snippet so the crawler allows dynamic items to populate before serializing the DOM.
3. **Bypassing Cookie Banners:**  
   Use `js_code` in the crawler config to simulate clicking the `#accept-cookies` button.
