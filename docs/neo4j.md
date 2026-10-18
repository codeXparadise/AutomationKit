<div align="center">
  <img src="../assets/logos/neo4j.svg" width="64" height="64" alt="Neo4j Logo" />
  <h1>Neo4j Graph Database — n8n Integration & API Guide</h1>
  <p><strong>Enterprise Graph Knowledge Base, Cypher Querying & GraphRAG for LLMs</strong></p>
</div>

> **Docker Internal HTTP API (Use in n8n):** `http://neo4j:7474`  
> **Docker Internal Bolt URL (Native Nodes):** `bolt://neo4j:7687`  
> **Neo4j Browser UI (Host):** `http://localhost:7474`  
> **Authentication:** Basic Auth (`neo4j` / `${NEO4J_PASSWORD}`)  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${NEO4J_PASSWORD}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

Neo4j is an enterprise-grade graph database built for connected data, knowledge graphs, fraud detection, recommendation engines, and GraphRAG (combining vector search with entity relationship graphs for LLM workflows).

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
  - [1.1 Basic Auth for HTTP Request Nodes (Recommended)](#11-basic-auth-for-http-request-nodes-recommended)
  - [1.2 Native Neo4j Bolt Connection](#12-native-neo4j-bolt-connection)
- [2. Cypher HTTP Transactional API](#2-cypher-http-transactional-api)
  - [2.1 Commit Cypher Statement (`POST /db/neo4j/tx/commit`)](#21-commit-cypher-statement-post-dbneo4jtxcommit)
  - [2.2 Creating Graph Nodes & Properties](#22-creating-graph-nodes--properties)
  - [2.3 Creating Relationships Between Entities](#23-creating-relationships-between-entities)
  - [2.4 Querying Graph Paths & Patterns](#24-querying-graph-paths--patterns)
- [3. GraphRAG & Entity Memory for AI Agents](#3-graphrag--entity-memory-for-ai-agents)
- [4. Ready-to-Import n8n Workflow JSON](#4-ready-to-import-n8n-workflow-json)
- [5. Cypher Cheatsheet for n8n Workflows](#5-cypher-cheatsheet-for-n8n-workflows)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

### 1.1 Basic Auth for HTTP Request Nodes (Recommended)

The simplest and most reliable way to execute Cypher queries in n8n is using the HTTP Request node with Basic Auth:

1. In n8n, click **Credentials** → **Add Credential**.
2. Select **Basic Auth**.
3. Configure:
   - **Credential Name:** `Neo4j Basic Auth`
   - **User:** `neo4j`
   - **Password:** `${NEO4J_PASSWORD}`
4. Click **Save**.

### 1.2 Native Neo4j Bolt Connection

If using community or native Neo4j nodes:
- **Host / URL:** `bolt://neo4j:7687`
- **User:** `neo4j`
- **Password:** `${NEO4J_PASSWORD}`

---

## 2. Cypher HTTP Transactional API

All Cypher queries can be executed in a single atomic transaction by calling `/db/neo4j/tx/commit`.

### 2.1 Commit Cypher Statement (`POST /db/neo4j/tx/commit`)

#### cURL Command
```bash
curl -X POST "http://neo4j:7474/db/neo4j/tx/commit" \
  -u "neo4j:${NEO4J_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "statements": [
      {
        "statement": "RETURN 1 AS test"
      }
    ]
  }'
```

#### Expected Response
```json
{
  "results": [
    {
      "columns": ["test"],
      "data": [
        { "row": [1], "meta": [null] }
      ]
    }
  ],
  "errors": []
}
```

---

### 2.2 Creating Graph Nodes & Properties

Create or update entities with parameters to prevent Cypher injection.

#### cURL Command
```bash
curl -X POST "http://neo4j:7474/db/neo4j/tx/commit" \
  -u "neo4j:${NEO4J_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "statements": [
      {
        "statement": "MERGE (u:User {email: $email}) ON CREATE SET u.name = $name, u.created_at = datetime() RETURN u",
        "parameters": {
          "email": "alex@company.com",
          "name": "Alex Smith"
        }
      }
    ]
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `POST`
- **URL:** `http://neo4j:7474/db/neo4j/tx/commit`
- **Authentication:** `Predefined Credential Type` → `Basic Auth` → `Neo4j Basic Auth`
- **Send Body:** `true`
- **Body Content Type:** `JSON`
- **JSON Body:**
  ```json
  {
    "statements": [
      {
        "statement": "MERGE (u:User {email: $email}) ON CREATE SET u.name = $name RETURN u",
        "parameters": {
          "email": "={{ $json.email }}",
          "name": "={{ $json.name }}"
        }
      }
    ]
  }
  ```

---

### 2.3 Creating Relationships Between Entities

Connect two nodes with a directed relationship (e.g. `User -> WORKS_AT -> Company`):

#### cURL Command
```bash
curl -X POST "http://neo4j:7474/db/neo4j/tx/commit" \
  -u "neo4j:${NEO4J_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "statements": [
      {
        "statement": "MATCH (u:User {email: $email}), (c:Company {name: $company}) MERGE (u)-[r:WORKS_AT {role: $role}]->(c) RETURN r",
        "parameters": {
          "email": "alex@company.com",
          "company": "AutomationKit Inc",
          "role": "Lead Architect"
        }
      }
    ]
  }'
```

---

### 2.4 Querying Graph Paths & Patterns

Retrieve related entities up to 2 hops away:

#### cURL Command
```bash
curl -X POST "http://neo4j:7474/db/neo4j/tx/commit" \
  -u "neo4j:${NEO4J_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "statements": [
      {
        "statement": "MATCH (u:User)-[r:WORKS_AT]->(c:Company) RETURN u.name AS user, r.role AS role, c.name AS company LIMIT 25"
      }
    ]
  }'
```

---

## 3. GraphRAG & Entity Memory for AI Agents

Combining Neo4j with **Ollama** and **Qdrant** produces GraphRAG workflows:
1. **Extract Entities:** LLM extracts entities (people, products, dates) and relationships from a text document parsed by **Docling**.
2. **Store Graph:** Insert entities into Neo4j via Cypher transactions.
3. **Query Context:** When a user asks a question, query Neo4j for connected nodes (`MATCH (n {name: $topic})-[r]-(neighbor) RETURN neighbor`) and feed the graph context into the LLM prompt.

---

## 4. Ready-to-Import n8n Workflow JSON

Copy this JSON and paste (`Ctrl + V`) into n8n to execute Cypher queries via HTTP:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "node_email",
              "name": "user_email",
              "value": "dev@automation.local",
              "type": "string"
            },
            {
              "id": "node_name",
              "name": "user_name",
              "value": "Automation Developer",
              "type": "string"
            }
          ]
        }
      },
      "id": "set-user-graph-node",
      "name": "Set Node Properties",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://neo4j:7474/db/neo4j/tx/commit",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpBasicAuth",
        "sendBody": true,
        "contentType": "json",
        "body": "={\n  \"statements\": [\n    {\n      \"statement\": \"MERGE (u:Person {email: $email}) ON CREATE SET u.name = $name RETURN u.name, u.email\",\n      \"parameters\": {\n        \"email\": \"{{ $json.user_email }}\",\n        \"name\": \"{{ $json.user_name }}\"\n      }\n    }\n  ]\n}",
        "options": {}
      },
      "id": "neo4j-commit-cypher",
      "name": "Neo4j Commit Cypher",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Set Node Properties": {
      "main": [
        [
          {
            "node": "Neo4j Commit Cypher",
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

## 5. Cypher Cheatsheet for n8n Workflows

| Operation | Cypher Snippet |
| :--- | :--- |
| **Create Unique Node** | `MERGE (n:Label {unique_prop: $val}) ON CREATE SET n.prop = $prop` |
| **Delete Node & Relations** | `MATCH (n:Label {id: $id}) DETACH DELETE n` |
| **Find Connected Nodes** | `MATCH (a:Person {name: $name})-[r]->(b) RETURN type(r), b` |
| **Find Shortest Path** | `MATCH p = shortestPath((a:User)-[*]-(b:User)) RETURN p` |
| **Count Nodes** | `MATCH (n:Label) RETURN count(n) AS total` |
