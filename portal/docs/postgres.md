<div align="center">
  <img src="../assets/logos/postgres.svg" width="64" height="64" alt="PostgreSQL Logo" />
  <h1>PostgreSQL Database — n8n Integration Guide</h1>
  <p><strong>Primary Relational Database Engine for Workflow State & Custom Data ETL</strong></p>
</div>

> **Docker Internal Host (Use in n8n):** `postgres`  
> **Docker Internal Port:** `5432`  
> **Host Connection (Localhost):** `localhost:5432`  
> **Default Database:** `n8n_database`  
> **User:** `admin`  
> **Password:** `${POSTGRES_PASSWORD}`  
> **SSL:** `Disabled`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${POSTGRES_PASSWORD}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

The primary PostgreSQL container serves as both the operational database engine for n8n itself and a high-performance relational database for your custom workflow data, transaction logs, and CRM/ERP data synchronization.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
- [2. Primary Postgres vs. Supabase Postgres](#2-primary-postgres-vs-supabase-postgres)
- [3. Common Operations in the n8n Postgres Node](#3-common-operations-in-the-n8n-postgres-node)
  - [3.1 Executing Custom SQL Queries](#31-executing-custom-sql-queries)
  - [3.2 Inserting Records with Parameter Binding](#32-inserting-records-with-parameter-binding)
  - [3.3 Batch Upserting (`ON CONFLICT DO UPDATE`)](#33-batch-upserting-on-conflict-do-update)
  - [3.4 Returning JSON & Aggregations](#34-returning-json--aggregations)
- [4. Creating Custom Tables for Workflows](#4-creating-custom-tables-for-workflows)
- [5. Ready-to-Import n8n Workflow JSON](#5-ready-to-import-n8n-workflow-json)
- [6. Performance & Security Best Practices](#6-performance--security-best-practices)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

To connect n8n to the primary PostgreSQL container:

1. In n8n, navigate to **Credentials** in the left sidebar and click **Add Credential**.
2. Search for and select **Postgres**.
3. Enter the following parameters:
   - **Credential Name:** `Primary Postgres Stack`
   - **Host:** `postgres`
   - **Database:** `n8n_database`
   - **User:** `admin`
   - **Password:** `${POSTGRES_PASSWORD}`
   - **Port:** `5432`
   - **SSL:** `allow` or `disable`
4. Click **Save**.

---

## 2. Primary Postgres vs. Supabase Postgres

The automation stack includes two distinct PostgreSQL databases tailored for different use cases:

| Feature | Primary Postgres (`postgres:5432`) | Supabase Postgres (`db:5432`) |
| :--- | :--- | :--- |
| **Primary Role** | Core n8n state & high-speed SQL pipeline | Supabase Suite, PostgREST & Auth |
| **User / Password** | `${POSTGRES_USER:-admin}` / `${POSTGRES_PASSWORD}` | `postgres` / `${POSTGRES_PASSWORD}` |
| **REST API** | None (Direct SQL only) | Auto-generated via Kong (`http://kong:8000/rest/v1/`) |
| **Web GUI** | Adminer / DBeaver / TablePlus | Supabase Studio (`http://localhost:54323`) |
| **Best For** | Internal n8n queues, high-throughput ETL | Customer-facing apps, mobile clients, Auth |

---

## 3. Common Operations in the n8n Postgres Node

### 3.1 Executing Custom SQL Queries

Execute parameterized queries safely using `$1, $2, ...` to prevent SQL injection vulnerabilities:

#### Node Configuration
- **Operation:** `Execute Query`
- **Query:**
  ```sql
  SELECT id, email, created_at
  FROM leads
  WHERE status = $1
  ORDER BY created_at DESC
  LIMIT 50;
  ```
- **Query Parameters:** `active`

---

### 3.2 Inserting Records with Parameter Binding

#### Node Configuration
- **Operation:** `Execute Query`
- **Query:**
  ```sql
  INSERT INTO orders (customer_name, amount, currency, created_at)
  VALUES ($1, $2, $3, NOW())
  RETURNING id, customer_name, amount;
  ```
- **Query Parameters:**
  `{{ $json.customer_name }}, {{ $json.amount }}, {{ $json.currency }}`

---

### 3.3 Batch Upserting (`ON CONFLICT DO UPDATE`)

Insert records if they do not exist, or update them if a unique constraint (e.g. `email`) is violated:

```sql
INSERT INTO subscribers (email, full_name, plan, updated_at)
VALUES ($1, $2, $3, NOW())
ON CONFLICT (email)
DO UPDATE SET
  full_name = EXCLUDED.full_name,
  plan = EXCLUDED.plan,
  updated_at = NOW()
RETURNING *;
```

---

### 3.4 Returning JSON & Aggregations

PostgreSQL has built-in JSON aggregation functions that format output directly for downstream n8n nodes:

```sql
SELECT 
  category,
  COUNT(*) AS total_items,
  json_agg(json_build_object('name', name, 'price', price)) AS products
FROM catalog
GROUP BY category;
```

---

## 4. Creating Custom Tables for Workflows

You can execute DDL (Data Definition Language) commands directly in an n8n workflow or via your SQL client (e.g. DBeaver at `localhost:5432`):

```sql
CREATE TABLE IF NOT EXISTS scraped_articles (
    id SERIAL PRIMARY KEY,
    url TEXT UNIQUE NOT NULL,
    title TEXT,
    markdown_content TEXT,
    tags TEXT[],
    crawled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scraped_articles_url ON scraped_articles(url);
```

---

## 5. Ready-to-Import n8n Workflow JSON

Copy this JSON and paste (`Ctrl + V`) into n8n to test a PostgreSQL SELECT query:

```json
{
  "nodes": [
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT NOW() AS server_time, version() AS pg_version;"
      },
      "id": "pg-test-query",
      "name": "Postgres Health & Version",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.5,
      "position": [460, 300]
    }
  ]
}
```

---

## 6. Performance & Security Best Practices

1. **Always Use Query Parameters:**  
   Never concatenate strings like `'WHERE email = \"' + $json.email + '\"'`. Always use `$1` and the query parameters field.
2. **Index Filtering Columns:**  
   If your n8n workflow filters by `status`, `external_id`, or `created_at`, ensure you create a B-Tree index on those columns in PostgreSQL.
3. **Handle Connection Timeouts:**  
   PostgreSQL in Docker handles thousands of operations per second. However, for long analytical batch queries, ensure you set appropriate query timeouts in the node options.
