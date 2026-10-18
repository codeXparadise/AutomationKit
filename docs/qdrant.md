<div align="center">
  <img src="../assets/logos/qdrant.svg" width="64" height="64" alt="Qdrant Logo" />
  <h1>Qdrant Vector Database — n8n Integration & API Guide</h1>
  <p><strong>High-Performance Vector Similarity Search Engine & Semantic RAG Store</strong></p>
</div>

> **Docker Internal URL (Use in n8n):** `http://qdrant:6333`  
> **Host URL (Browser / Postman):** `http://localhost:6333`  
> **Built-in Web Dashboard:** `http://localhost:6333/dashboard`  
> **Interactive Swagger UI:** `http://localhost:6333/docs`  
> **Authentication Header:** `api-key: admin:${QDRANT_PASSWORD}`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${QDRANT_PASSWORD}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

Qdrant is a high-performance vector search engine designed for extended AI retrieval, embeddings search, RAG pipelines, and semantic similarity matching. It provides both a native n8n Vector Store integration and a comprehensive REST API.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
  - [1.1 Native Qdrant Vector Store Credential](#11-native-qdrant-vector-store-credential)
  - [1.2 Generic Header Auth for HTTP Request Nodes](#12-generic-header-auth-for-http-request-nodes)
- [2. Health & Cluster Status](#2-health--cluster-status)
  - [2.1 Ready Status (`GET /readyz`)](#21-ready-status-get-readyz)
  - [2.2 Telemetry & Version (`GET /telemetry`)](#22-telemetry--version-get-telemetry)
- [3. Collection Management](#3-collection-management)
  - [3.1 List All Collections (`GET /collections`)](#31-list-all-collections-get-collections)
  - [3.2 Create a New Collection (`PUT /collections/{collection_name}`)](#32-create-a-new-collection-put-collectionscollection_name)
  - [3.3 Get Collection Details (`GET /collections/{collection_name}`)](#33-get-collection-details-get-collectionscollection_name)
  - [3.4 Delete a Collection (`DELETE /collections/{collection_name}`)](#34-delete-a-collection-delete-collectionscollection_name)
- [4. Vector Points Operations](#4-vector-points-operations)
  - [4.1 Upsert Points with Vector & Metadata (`PUT /collections/{name}/points`)](#41-upsert-points-with-vector--metadata-put-collectionsnamepoints)
  - [4.2 Semantic Vector Search (`POST /collections/{name}/points/search`)](#42-semantic-vector-search-post-collectionsnamepointssearch)
  - [4.3 Retrieve Points by ID (`POST /collections/{name}/points`)](#43-retrieve-points-by-id-post-collectionsnamepoints)
  - [4.4 Delete Points (`POST /collections/{name}/points/delete`)](#44-delete-points-post-collectionsnamepointsdelete)
- [5. Using the Native n8n Qdrant Vector Store Node](#5-using-the-native-n8n-qdrant-vector-store-node)
- [6. Ready-to-Import n8n Workflow JSON](#6-ready-to-import-n8n-workflow-json)
- [7. Best Practices for RAG & Distance Metrics](#7-best-practices-for-rag--distance-metrics)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

### 1.1 Native Qdrant Vector Store Credential

To connect to Qdrant via n8n's native **Qdrant Vector Store** node:

1. In n8n, click **Credentials** → **Add Credential**.
2. Search for **Qdrant API**.
3. Configure:
   - **Qdrant URL:** `http://qdrant:6333`
   - **API Key:** `admin:${QDRANT_PASSWORD}`
4. Click **Save**.

### 1.2 Generic Header Auth for HTTP Request Nodes

If you are using raw HTTP Request nodes for direct REST calls:
1. In n8n, click **Credentials** → **Add Credential**.
2. Select **Header Auth**.
3. Configure:
   - **Credential Name:** `Qdrant Header Auth`
   - **Name:** `api-key`
   - **Value:** `admin:${QDRANT_PASSWORD}`
4. Click **Save**.

---

## 2. Health & Cluster Status

### 2.1 Ready Status (`GET /readyz`)

#### cURL Command
```bash
curl -X GET "http://qdrant:6333/readyz"
```

#### Response
```
all systems ok
```

---

## 3. Collection Management

### 3.1 List All Collections (`GET /collections`)

#### cURL Command
```bash
curl -X GET "http://qdrant:6333/collections" \
  -H "api-key: admin:${QDRANT_PASSWORD}"
```

#### n8n HTTP Request Configuration
- **Method:** `GET`
- **URL:** `http://qdrant:6333/collections`
- **Authentication:** `Header Auth`

#### Response
```json
{
  "result": {
    "collections": [
      { "name": "knowledge_base" },
      { "name": "customer_support" }
    ]
  },
  "status": "ok",
  "time": 0.001
}
```

---

### 3.2 Create a New Collection (`PUT /collections/{collection_name}`)

When creating a collection, define the embedding dimension (e.g. `768` for `nomic-embed-text` or `1536` for `text-embedding-3-small`) and distance metric (`Cosine`, `Dot`, or `Euclid`).

#### cURL Command
```bash
curl -X PUT "http://qdrant:6333/collections/knowledge_base" \
  -H "api-key: admin:${QDRANT_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    }
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `PUT`
- **URL:** `http://qdrant:6333/collections/knowledge_base`
- **Authentication:** `Header Auth`
- **Send Body:** `true`
- **Body Content Type:** `JSON`
- **JSON Body:**
  ```json
  {
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    }
  }
  ```

---

### 3.3 Get Collection Details (`GET /collections/{collection_name}`)

#### cURL Command
```bash
curl -X GET "http://qdrant:6333/collections/knowledge_base" \
  -H "api-key: admin:${QDRANT_PASSWORD}"
```

---

### 3.4 Delete a Collection (`DELETE /collections/{collection_name}`)

#### cURL Command
```bash
curl -X DELETE "http://qdrant:6333/collections/knowledge_base" \
  -H "api-key: admin:${QDRANT_PASSWORD}"
```

---

## 4. Vector Points Operations

### 4.1 Upsert Points with Vector & Metadata (`PUT /collections/{name}/points`)

Inserts or updates vector records with associated structured JSON payloads. Adding `?wait=true` forces the database to write to disk before returning.

#### cURL Command
```bash
curl -X PUT "http://qdrant:6333/collections/knowledge_base/points?wait=true" \
  -H "api-key: admin:${QDRANT_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.0245, -0.0194, 0.0821, -0.0381],
        "payload": {
          "title": "Docker Setup",
          "content": "Compose sets up all containers on the Automation network.",
          "category": "infrastructure"
        }
      }
    ]
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `PUT`
- **URL:** `http://qdrant:6333/collections/knowledge_base/points?wait=true`
- **Authentication:** `Header Auth`
- **JSON Body:**
  ```json
  {
    "points": [
      {
        "id": "={{ $json.id }}",
        "vector": "={{ $json.vector }}",
        "payload": {
          "text": "={{ $json.text }}",
          "source": "={{ $json.source }}"
        }
      }
    ]
  }
  ```

---

### 4.2 Semantic Vector Search (`POST /collections/{name}/points/search`)

Find the top-K most similar points to a query vector, with optional metadata filtering.

#### cURL Command
```bash
curl -X POST "http://qdrant:6333/collections/knowledge_base/points/search" \
  -H "api-key: admin:${QDRANT_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.0245, -0.0194, 0.0821, -0.0381],
    "limit": 3,
    "with_payload": true,
    "filter": {
      "must": [
        {
          "key": "category",
          "match": {
            "value": "infrastructure"
          }
        }
      ]
    }
  }'
```

#### Response Structure
```json
{
  "result": [
    {
      "id": 1,
      "version": 1,
      "score": 0.9842,
      "payload": {
        "title": "Docker Setup",
        "content": "Compose sets up all containers on the Automation network."
      }
    }
  ],
  "status": "ok"
}
```

---

### 4.3 Retrieve Points by ID (`POST /collections/{name}/points`)

#### cURL Command
```bash
curl -X POST "http://qdrant:6333/collections/knowledge_base/points" \
  -H "api-key: admin:${QDRANT_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1, 2],
    "with_payload": true,
    "with_vector": false
  }'
```

---

### 4.4 Delete Points (`POST /collections/{name}/points/delete`)

#### cURL Command
```bash
curl -X POST "http://qdrant:6333/collections/knowledge_base/points/delete" \
  -H "api-key: admin:${QDRANT_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [1]
  }'
```

---

## 5. Using the Native n8n Qdrant Vector Store Node

In n8n RAG workflows:

1. Add the **Qdrant Vector Store** node to your workflow.
2. Connect an **Embeddings** sub-node (e.g. **Embeddings Ollama** pointing to `http://ollama:11434` with model `nomic-embed-text`).
3. Select your saved **Qdrant API** credential (`http://qdrant:6333`).
4. Set the **Collection Name** to `knowledge_base`.
5. Under **Operation**, choose **Get Many (Search)** or **Insert Documents**.

---

## 6. Ready-to-Import n8n Workflow JSON

Copy this JSON and paste (`Ctrl + V`) directly into n8n to test searching Qdrant with custom vectors:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "coll_name",
              "name": "collection",
              "value": "test_collection",
              "type": "string"
            }
          ]
        }
      },
      "id": "init-qdrant-step",
      "name": "Set Test Collection",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "GET",
        "url": "http://qdrant:6333/collections",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "options": {}
      },
      "id": "list-collections",
      "name": "List Qdrant Collections",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Set Test Collection": {
      "main": [
        [
          {
            "node": "List Qdrant Collections",
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

## 7. Best Practices for RAG & Distance Metrics

- **Cosine Distance:** Best choice when using normalized vectors (like Ollama's `nomic-embed-text` or OpenAI `text-embedding-3`).
- **Dot Product:** Fastest calculation, suitable only if vectors are pre-normalized to unit length.
- **Euclidean (L2):** Use for spatial or coordinate distance.
- **Vector Dimension Matching:** Ensure your collection vector size matches your embedding model output (`768` for `nomic-embed-text`, `1536` for OpenAI, `1024` for `bge-m3`).
