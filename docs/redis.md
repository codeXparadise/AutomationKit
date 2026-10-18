<div align="center">
  <img src="../assets/logos/redis.svg" width="64" height="64" alt="Redis Logo" />
  <h1>Redis Cache & In-Memory Store — n8n Integration Guide</h1>
  <p><strong>Sub-Millisecond In-Memory Caching, Deduplication & Queue Storage</strong></p>
</div>

> **Docker Internal Host (Use in n8n):** `redis`  
> **Docker Internal Port:** `6379`  
> **Host Connection (Localhost):** `localhost:6379`  
> **RedisInsight Web GUI:** `http://localhost:5540` (or `http://redis.local`)  
> **Authentication:** Password `${REDIS_PASSWORD}`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${REDIS_PASSWORD}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

Redis provides sub-millisecond in-memory storage ideal for caching heavy API responses, rate-limiting incoming webhooks, implementing queue workers, and deduplicating events across n8n executions.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
- [2. Primary Operations in n8n](#2-primary-operations-in-n8n)
  - [2.1 Key/Value Caching with TTL (`SET` & `GET`)](#21-keyvalue-caching-with-ttl-set--get)
  - [2.2 Preventing Duplicate Webhooks (`SETNX` / Deduplication)](#22-preventing-duplicate-webhooks-setnx--deduplication)
  - [2.3 Queue & Task Buffering (`LPUSH` & `RPOP`)](#23-queue--task-buffering-lpush--rpop)
  - [2.4 Hash Storage for User State (`HSET` & `HGETALL`)](#24-hash-storage-for-user-state-hset--hgetall)
- [3. CLI Testing & Verification](#3-cli-testing--verification)
- [4. High-Performance Caching Pattern in n8n](#4-high-performance-caching-pattern-in-n8n)
- [5. Ready-to-Import n8n Workflow JSON](#5-ready-to-import-n8n-workflow-json)
- [6. Common Redis Troubleshooting](#6-common-redis-troubleshooting)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

n8n has native support for Redis out of the box:

1. In n8n, click **Credentials** → **Add Credential**.
2. Search for **Redis**.
3. Fill in the connection settings:
   - **Credential Name:** `Redis Internal Stack`
   - **Host:** `redis`
   - **Port:** `6379`
   - **Password:** `${REDIS_PASSWORD}`
   - **Database Index:** `0`
   - **SSL:** `Disabled`
4. Click **Save**.

Now you can add the native **Redis** node to any workflow without custom HTTP or shell scripts.

---

## 2. Primary Operations in n8n

### 2.1 Key/Value Caching with TTL (`SET` & `GET`)

Avoid re-fetching expensive API calls (such as Docling conversions or Crawl4AI scrapes) by caching the result in Redis with an expiration time.

#### n8n Redis Node Settings (Cache Save)
- **Resource:** `String`
- **Operation:** `Set`
- **Key:** `cache:url:{{ $json.url_hash }}`
- **Value:** `{{ $json.markdown_content }}`
- **Options → Expire Time (Seconds):** `3600` (1 hour)

#### n8n Redis Node Settings (Cache Lookup)
- **Resource:** `String`
- **Operation:** `Get`
- **Key:** `cache:url:{{ $json.url_hash }}`

---

### 2.2 Preventing Duplicate Webhooks (`SETNX` / Deduplication)

When Stripe or external payment gateways send retry webhooks, you can verify if a webhook event ID has already been processed:

1. Use the Redis node to `Set` key: `processed:webhook:{{ $json.event_id }}` with value `1` and expire time `86400` (24h).
2. Set **Options → Only if Key Doesn't Exist (NX):** `true`.
3. If the key already exists, Redis returns `null`, allowing an `If` node to stop duplicate workflow execution.

---

### 2.3 Queue & Task Buffering (`LPUSH` & `RPOP`)

Use Redis lists to build a reliable FIFO (First-In, First-Out) work queue between two separate n8n workflows:

- **Producer Workflow:** Uses `List` → `Push` to add a job payload to the left of `tasks:queue`.
- **Consumer Workflow:** Runs on a schedule and uses `List` → `Pop` to take jobs from the right of `tasks:queue`.

---

### 2.4 Hash Storage for User State (`HSET` & `HGETALL`)

Store multi-field state (such as conversational state or shopping cart items) under a single key:

- **Resource:** `Hash`
- **Operation:** `Set`
- **Key:** `user:session:{{ $json.user_id }}`
- **Fields:**
  - `last_active`: `{{ $now }}`
  - `current_step`: `verification`
  - `retry_count`: `2`

---

## 3. CLI Testing & Verification

You can verify keys directly from your terminal or Docker container:

```bash
# Test connection inside Docker
docker exec -it redis redis-cli -a ${REDIS_PASSWORD} ping
# Returns: PONG

# Inspect existing keys
docker exec -it redis redis-cli -a ${REDIS_PASSWORD} keys "*"

# Get value of a key
docker exec -it redis redis-cli -a ${REDIS_PASSWORD} get "my_test_key"
```

---

## 4. High-Performance Caching Pattern in n8n

```
[ Trigger (Webhook / URL) ]
            |
   [ Redis: Check Cache ]
            |
     [ If: Key Exists? ]
     /                 \
(True: Cache Hit)   (False: Cache Miss)
    |                      |
[ Return Fast ]    [ Call Docling / Crawl4AI ]
                           |
                   [ Redis: Save with TTL ]
                           |
                     [ Return Data ]
```

This pattern reduces processing time from 10 seconds to under 5 milliseconds on repeat queries.

---

## 5. Ready-to-Import n8n Workflow JSON

Copy this JSON, go to n8n, and press `Ctrl + V` to import a working Redis SET and GET test workflow:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "key_param",
              "name": "cache_key",
              "value": "n8n_test_key",
              "type": "string"
            },
            {
              "id": "val_param",
              "name": "cache_value",
              "value": "Automation Redis Cache is Working!",
              "type": "string"
            }
          ]
        }
      },
      "id": "set-redis-data",
      "name": "Prepare Cache Data",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "operation": "set",
        "key": "={{ $json.cache_key }}",
        "value": "={{ $json.cache_value }}",
        "options": {
          "expireTime": 300
        }
      },
      "id": "redis-set-node",
      "name": "Redis Set Key with TTL",
      "type": "n8n-nodes-base.redis",
      "typeVersion": 1,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Prepare Cache Data": {
      "main": [
        [
          {
            "node": "Redis Set Key with TTL",
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

## 6. Common Redis Troubleshooting

1. **`NOAUTH Authentication required`:**  
   Ensure you specified password `${REDIS_PASSWORD}` in the n8n Redis credential.
2. **`ECONNREFUSED redis:6379`:**  
   Ensure the `redis` container is running in your Docker manager or run `docker compose up -d redis`.
3. **Memory Limits:**  
   If storing large documents or PDFs in Redis, always set a TTL (Time To Live) so expired items automatically clear from RAM.
