<div align="center">
  <img src="../assets/logos/openwa.svg" width="64" height="64" alt="OpenWA Logo" />
  <h1>OpenWA WhatsApp API Gateway — n8n Integration Guide</h1>
  <p><strong>Free, Open-Source, Self-Hosted WhatsApp API Gateway with Redis Queue & PostgreSQL</strong></p>
</div>

> **Docker Internal Host (Use in n8n):** `openwa`  
> **Docker Internal Port:** `2785`  
> **Host Web & API URL:** `http://localhost:2785` (or `http://openwa.local`)  
> **Swagger API Docs:** `http://localhost:2785/api/docs`  
> **Database:** PostgreSQL (`postgres:5432`, DB: `openwa`)  
> **Cache & Queue:** Redis (`redis:6379`, Password: `${REDIS_PASSWORD}`)  
> **Local Storage:** `./data/openwa` (media stored under `./data/openwa/media`)  
> **Authentication:** `X-API-Key: ${OPENWA_API_KEY}` (or token from `./data/openwa/.api-key`)  
> **Official n8n Node:** `@rmyndharis/n8n-nodes-openwa`  

> [!TIP]
> **Dynamic Environment Resolution:** OpenWA is fully orchestrated inside AutomationKit. PostgreSQL handles persistent message records, session metadata, and migrations, while Redis powers BullMQ background webhook dispatching and deduplication. All session data, authentication tokens, and downloaded media are strictly persisted under the project's local `./data/openwa/` directory.

---

## Table of Contents

- [1. OpenWA Setup in n8n](#1-openwa-setup-in-n8n)
  - [1.1 Installed Community Nodes](#11-installed-community-nodes)
  - [1.2 Configuring OpenWA Credentials in n8n](#12-configuring-openwa-credentials-in-n8n)
- [2. Quick Start: Pairing WhatsApp via QR Code](#2-quick-start-pairing-whatsapp-via-qr-code)
- [3. Primary Node Actions in Workflows](#3-primary-node-actions-in-workflows)
  - [3.1 Sending Text Messages](#31-sending-text-messages)
  - [3.2 Sending Media (Images, Documents, Audio)](#32-sending-media-images-documents-audio)
  - [3.3 Managing WhatsApp Sessions](#33-managing-whatsapp-sessions)
- [4. Real-Time Webhook Triggers](#4-real-time-webhook-triggers)
  - [4.1 Automatic Webhook Lifecycle](#41-automatic-webhook-lifecycle)
  - [4.2 Supported Event Types](#42-supported-event-types)
- [5. Direct REST API & cURL Verification](#5-direct-rest-api--curl-verification)
- [6. Ready-to-Import n8n Workflow JSON](#6-ready-to-import-n8n-workflow-json)
- [7. Common Troubleshooting](#7-common-troubleshooting)

---

## 1. OpenWA Setup in n8n

### 1.1 Installed Community Nodes

The official community package **`@rmyndharis/n8n-nodes-openwa`** is installed directly in n8n:

- **OpenWA Action Node (`OpenWa`):** Send messages, media, location, polls, fetch contacts, manage chats, and manipulate session states.
- **OpenWA Trigger Node (`OpenWaTrigger`):** Instantly triggers n8n workflows when incoming messages or status changes arrive from WhatsApp.
- **OpenWA API Credential (`OpenWaApi`):** Securely stores the server URL and API key.

### 1.2 Configuring OpenWA Credentials in n8n

1. In your n8n dashboard (`http://localhost:5678` or `http://n8n.local`), go to **Credentials** → **Add Credential**.
2. Search for **OpenWA API**.
3. Fill in the connection settings:
   - **Server URL:** `http://openwa:2785` *(Use internal Docker service name)*
   - **API Key:** `${OPENWA_API_KEY}` *(Found in your `.env` or in `./data/openwa/.api-key`)*
4. Click **Save**.

---

## 2. Quick Start: Pairing WhatsApp via QR Code

1. Open the OpenWA Dashboard in your browser:  
   👉 **http://openwa.local** or **http://localhost:2785**
2. In the Dashboard:
   - Click **Create Session** and name it (e.g. `primary` or `default`).
   - Click **Start / Connect**.
   - A QR Code will appear in the dashboard.
3. Open WhatsApp on your phone:
   - Go to **Linked Devices** → **Link a Device**.
   - Scan the QR code displayed on screen.
4. Once authenticated, OpenWA establishes the multi-device connection, stores session tokens under `./data/openwa/sessions`, and syncs with PostgreSQL.

---

## 3. Primary Node Actions in Workflows

### 3.1 Sending Text Messages

Add the **OpenWA** node to your workflow:
- **Resource:** `Message`
- **Operation:** `Send Text`
- **Session:** Select your paired session (e.g., `default`)
- **Chat ID / Phone:** International format with country code (e.g., `1234567890@c.us` or `919876543210@c.us`)
- **Text:** Message body or expression (e.g., `Hello from n8n AutomationKit!`)

### 3.2 Sending Media (Images, Documents, Audio)

- **Resource:** `Message`
- **Operation:** `Send Media`
- **Session:** `default`
- **Chat ID:** `1234567890@c.us`
- **Media URL or Base64:** `http://files.local/my-report.pdf` or binary property name.

---

## 4. Real-Time Webhook Triggers

### 4.1 Automatic Webhook Lifecycle

When you drag the **OpenWA Trigger** node into an n8n workflow and click **Listen for Test Event** or **Activate Workflow**:
- n8n automatically registers the session webhook with OpenWA.
- When the workflow is deactivated, n8n automatically deregisters the webhook cleanly.
- Redis queues ensure zero message loss even under heavy incoming chat volume.

### 4.2 Supported Event Types

- `message.received` — Triggered when any contact sends a text or media message.
- `message.ack` — Message delivered/read receipts.
- `session.authenticated` / `session.ready` — Connection status changes.
- `session.qr` — When a session generates a new pairing QR code.

---

## 5. Direct REST API & cURL Verification

You can test OpenWA directly from your terminal or PowerShell:

### Health Check:
```bash
curl -f http://localhost:2785/api/health/ready
```

### List Active Sessions:
```bash
curl -X GET "http://localhost:2785/api/sessions" \
  -H "X-API-Key: ${OPENWA_API_KEY}"
```

### Send a Test Message via cURL:
```bash
curl -X POST "http://localhost:2785/api/sessions/default/messages/send-text" \
  -H "X-API-Key: ${OPENWA_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "chatId": "1234567890@c.us",
    "text": "Hello from OpenWA Gateway!"
  }'
```

---

## 6. Ready-to-Import n8n Workflow JSON

Copy the workflow JSON below and paste directly (`Ctrl+V`) into your n8n canvas:

```json
{
  "name": "OpenWA WhatsApp Echo Bot",
  "nodes": [
    {
      "parameters": {
        "sessionId": "default",
        "events": [
          "message.received"
        ]
      },
      "id": "openwa-trigger-1",
      "name": "WhatsApp Inbound Trigger",
      "type": "@rmyndharis/n8n-nodes-openwa.openWaTrigger",
      "typeVersion": 1,
      "position": [240, 300],
      "credentials": {
        "openWaApi": {
          "id": "openwa-cred-default",
          "name": "OpenWA Local Gateway"
        }
      }
    },
    {
      "parameters": {
        "sessionId": "default",
        "chatId": "={{ $json.data.from }}",
        "text": "=Echo from AutomationKit: You said \"{{ $json.data.body }}\""
      },
      "id": "openwa-reply-1",
      "name": "Reply to WhatsApp",
      "type": "@rmyndharis/n8n-nodes-openwa.openWa",
      "typeVersion": 1,
      "position": [480, 300],
      "credentials": {
        "openWaApi": {
          "id": "openwa-cred-default",
          "name": "OpenWA Local Gateway"
        }
      }
    }
  ],
  "connections": {
    "WhatsApp Inbound Trigger": {
      "main": [
        [
          {
            "node": "Reply to WhatsApp",
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

## 7. Common Troubleshooting

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **Connection Refused in n8n** | Using `localhost:2785` inside Docker | Use internal Docker host `http://openwa:2785` in n8n credentials. |
| **Invalid API Key (401)** | Missing or mismatched master key | Verify `${OPENWA_API_KEY}` in `.env` or check `./data/openwa/.api-key`. Must be >= 32 characters in production. |
| **QR Code Timeout** | WhatsApp Web handshake latency | Increase `WWEBJS_AUTH_TIMEOUT_MS=60000` or switch engine to `baileys`. |
| **Database Connection Error** | PostgreSQL container not healthy | Verify `postgres` is healthy: `docker compose ps postgres`. OpenWA automatically connects to the `openwa` database. |
| **Redis Queue Delayed** | BullMQ waiting on Redis Auth | OpenWA connects with `${REDIS_PASSWORD}` configured automatically. |
| **Destination address is not allowed** | OpenWA SSRF guard blocking internal Docker bridge IPs | Fixed in AutomationKit via `WEBHOOK_SSRF_PROTECT=false` and `SSRF_ALLOWED_HOSTS=n8n,caddy,localhost,host.docker.internal`. |

