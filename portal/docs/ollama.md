<div align="center">
  <img src="../assets/logos/ollama.svg" width="64" height="64" alt="Ollama Logo" />
  <h1>Ollama — n8n Integration & API Guide</h1>
  <p><strong>Private Local LLM Inference & Embedding Engine</strong></p>
</div>

> **Docker Internal URL (Use in n8n):** `http://ollama:11434`  
> **Host URL (Browser / Postman):** `http://localhost:11434`  
> **Authentication:** None (No API key required on internal network)  

Ollama allows you to run state-of-the-art open-source LLMs locally (e.g. `llama3.2`, `mistral`, `deepseek-r1`, `qwen2.5`, `phi3`) and embedding models (`nomic-embed-text`, `bge-m3`) with complete privacy, zero API costs, and low latency.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
  - [1.1 Native Ollama Node Credentials (Recommended)](#11-native-ollama-node-credentials-recommended)
  - [1.2 Using Generic HTTP Request Nodes](#12-using-generic-http-request-nodes)
- [2. Model Management Endpoints](#2-model-management-endpoints)
  - [2.1 List Installed Models (`GET /api/tags`)](#21-list-installed-models-get-apitags)
  - [2.2 Download / Pull a New Model (`POST /api/pull`)](#22-download--pull-a-new-model-post-apipull)
  - [2.3 Inspect Model Details (`POST /api/show`)](#23-inspect-model-details-post-apishow)
  - [2.4 Delete Model (`DELETE /api/delete`)](#24-delete-model-delete-apidelete)
- [3. LLM Inference Endpoints](#3-llm-inference-endpoints)
  - [3.1 Chat Completion with History (`POST /api/chat`)](#31-chat-completion-with-history-post-apichat)
  - [3.2 Single Text Generation (`POST /api/generate`)](#32-single-text-generation-post-apigenerate)
  - [3.3 Generating Vector Embeddings (`POST /api/embeddings`)](#33-generating-vector-embeddings-post-apiembeddings)
- [4. Integrating Ollama with n8n Advanced AI Agents](#4-integrating-ollama-with-n8n-advanced-ai-agents)
- [5. Ready-to-Import n8n Workflow JSON](#5-ready-to-import-n8n-workflow-json)
- [6. Performance & GPU Optimization Tips](#6-performance--gpu-optimization-tips)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

### 1.1 Native Ollama Node Credentials (Recommended)

n8n has built-in native support for Ollama!

1. In n8n, navigate to **Credentials** in the left sidebar and click **Add Credential**.
2. Search for **Ollama**.
3. In **Base URL**, enter:
   ```
   http://ollama:11434
   ```
4. Click **Save**.

Now you can attach the **Ollama Chat Model** or **Embeddings Ollama** sub-nodes directly to the **AI Agent**, **Basic LLM Chain**, or **Qdrant Vector Store** nodes.

### 1.2 Using Generic HTTP Request Nodes

If you prefer calling raw endpoints without the AI Agent nodes:
- Set **Authentication** to `None`.
- Send requests directly to `http://ollama:11434/api/...`.

---

## 2. Model Management Endpoints

### 2.1 List Installed Models (`GET /api/tags`)

Fetches all models currently downloaded and available on your system.

#### cURL Command
```bash
curl -X GET "http://ollama:11434/api/tags"
```

#### n8n HTTP Request Configuration
- **Method:** `GET`
- **URL:** `http://ollama:11434/api/tags`
- **Authentication:** `None`

#### Expected Response
```json
{
  "models": [
    {
      "name": "llama3.2:latest",
      "model": "llama3.2:latest",
      "size": 2019393189,
      "digest": "a80c4f17acd5...",
      "details": {
        "format": "gguf",
        "family": "llama",
        "parameter_size": "3B",
        "quantization_level": "Q4_K_M"
      }
    }
  ]
}
```

---

### 2.2 Download / Pull a New Model (`POST /api/pull`)

You can trigger model downloads directly from an n8n workflow or script:

#### cURL Command
```bash
curl -X POST "http://ollama:11434/api/pull" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "llama3.2",
    "stream": false
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `POST`
- **URL:** `http://ollama:11434/api/pull`
- **Send Body:** `true`
- **Body Content Type:** `JSON`
- **Specify Body:** `Using JSON`
- **JSON Body:**
  ```json
  {
    "name": "nomic-embed-text",
    "stream": false
  }
  ```
- **Options → Timeout:** `300000` (5 minutes for initial download)

---

### 2.3 Inspect Model Details (`POST /api/show`)

#### cURL Command
```bash
curl -X POST "http://ollama:11434/api/show" \
  -H "Content-Type: application/json" \
  -d '{ "name": "llama3.2" }'
```

---

### 2.4 Delete Model (`DELETE /api/delete`)

#### cURL Command
```bash
curl -X DELETE "http://ollama:11434/api/delete" \
  -H "Content-Type: application/json" \
  -d '{ "name": "unused-model:latest" }'
```

---

## 3. LLM Inference Endpoints

### 3.1 Chat Completion with History (`POST /api/chat`)

Standard multi-turn conversation format. Always set `"stream": false` for n8n to receive the complete JSON response synchronously.

#### cURL Command
```bash
curl -X POST "http://ollama:11434/api/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "messages": [
      { "role": "system", "content": "You are a concise enterprise workflow assistant." },
      { "role": "user", "content": "Explain webhooks in 2 bullet points." }
    ],
    "stream": false,
    "options": {
      "temperature": 0.2
    }
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `POST`
- **URL:** `http://ollama:11434/api/chat`
- **Authentication:** `None`
- **Send Body:** `true`
- **Body Content Type:** `JSON`
- **JSON Body:**
  ```json
  {
    "model": "llama3.2",
    "messages": [
      {
        "role": "user",
        "content": "={{ $json.prompt }}"
      }
    ],
    "stream": false
  }
  ```

#### Response Structure
```json
{
  "model": "llama3.2",
  "created_at": "2026-10-18T18:00:00Z",
  "message": {
    "role": "assistant",
    "content": "1. Webhooks are automated HTTP POST notifications triggered by specific events.\n2. They push data in real time without continuous polling."
  },
  "done": true,
  "total_duration": 1823901242
}
```

---

### 3.2 Single Text Generation (`POST /api/generate`)

Useful for prompt completion or classification tasks.

#### cURL Command
```bash
curl -X POST "http://ollama:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "prompt": "Classify the sentiment of this review as POSITIVE or NEGATIVE: Great product!",
    "stream": false
  }'
```

---

### 3.3 Generating Vector Embeddings (`POST /api/embeddings`)

Converts any text string into high-dimensional vector embeddings for indexing in **Qdrant**.

#### cURL Command
```bash
curl -X POST "http://ollama:11434/api/embeddings" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "prompt": "Docker containers provide lightweight virtualization."
  }'
```

#### Response Structure
```json
{
  "embedding": [
    0.02451, -0.01948, 0.08214, -0.03819, 0.01124
  ]
}
```

---

## 4. Integrating Ollama with n8n Advanced AI Agents

To use Ollama inside n8n's visual AI builder:

```
[ Manual / Webhook Trigger ]
            |
      [ AI Agent ]  <--- Connects to: [ Ollama Chat Model ] (Base URL: http://ollama:11434)
            |       <--- Connects to: [ Window Buffer Memory ]
            |       <--- Connects to: [ Custom Tool / SearXNG ]
            v
   [ Formatted Output ]
```

1. Add the **AI Agent** node.
2. In the **Model** port, connect an **Ollama Chat Model** node.
3. Select your Ollama credential (pointing to `http://ollama:11434`).
4. Type in your model name (e.g. `llama3.2`).

---

## 5. Ready-to-Import n8n Workflow JSON

Copy the workflow below and paste (`Ctrl + V`) into n8n:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "prompt_input",
              "name": "prompt",
              "value": "Write 3 benefits of self-hosting automation tools.",
              "type": "string"
            }
          ]
        }
      },
      "id": "input-prompt",
      "name": "Set Prompt",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://ollama:11434/api/chat",
        "sendBody": true,
        "contentType": "json",
        "body": "={\n  \"model\": \"llama3.2\",\n  \"messages\": [\n    {\n      \"role\": \"user\",\n      \"content\": \"{{ $json.prompt }}\"\n    }\n  ],\n  \"stream\": false\n}",
        "options": {
          "timeout": 120000
        }
      },
      "id": "ollama-chat",
      "name": "Ollama Local Chat",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Set Prompt": {
      "main": [
        [
          {
            "node": "Ollama Local Chat",
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

## 6. Performance & GPU Optimization Tips

1. **Always Set `"stream": false`:**  
   By default, Ollama streams chunked tokens. In n8n HTTP Request nodes, streaming causes JSON parsing failures. Always specify `"stream": false`.
2. **First Run Cold Start:**  
   When a model is called for the first time after container boot, it loads into memory (taking 3-10 seconds). Subsequent requests respond instantly.
3. **Recommended Lightweight Models:**  
   - General reasoning: `llama3.2:3b` or `phi3:mini`
   - High accuracy coding/tools: `qwen2.5-coder:7b`
   - Embedding: `nomic-embed-text`
