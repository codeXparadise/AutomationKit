<div align="center">
  <img src="../assets/logos/supabase.svg" width="64" height="64" alt="Supabase Logo" />
  <h1>Supabase — n8n Integration & API Guide</h1>
  <p><strong>PostgREST Database CRUD, S3 Object Storage & User Auth via Kong Gateway</strong></p>
</div>

> **Docker Internal Kong API URL (Use in n8n):** `http://kong:8000` (or `http://supabase-kong:8000`)  
> **Direct PostgreSQL DB (Use in n8n):** `db:5432` (or `supabase-db:5432`)  
> **Host Kong API Gateway:** `http://localhost:54321`  
> **Supabase Studio Dashboard:** `http://localhost:54323` (or `http://supabase.local`)  
> **Host Direct PostgreSQL:** `localhost:54322`  
> **Authentication Headers:** `apikey: ${SUPABASE_ANON_KEY}` and `Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${SUPABASE_SERVICE_ROLE_KEY}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

Supabase provides an open-source Firebase alternative featuring auto-generated PostgREST APIs, PostgreSQL with row-level security (RLS), S3-compatible object storage, and built-in user authentication.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
  - [1.1 PostgREST API Header Auth (Recommended for REST)](#11-postgrest-api-header-auth-recommended-for-rest)
  - [1.2 Native PostgreSQL Node Credentials (Direct DB Access)](#12-native-postgresql-node-credentials-direct-db-access)
- [2. PostgREST Database API Endpoints](#2-postgrest-database-api-endpoints)
  - [2.1 Querying Records (`GET /rest/v1/{table}`)](#21-querying-records-get-restv1table)
  - [2.2 Inserting Records (`POST /rest/v1/{table}`)](#22-inserting-records-post-restv1table)
  - [2.3 Updating Records (`PATCH /rest/v1/{table}`)](#23-updating-records-patch-restv1table)
  - [2.4 Deleting Records (`DELETE /rest/v1/{table}`)](#24-deleting-records-delete-restv1table)
- [3. Storage API (Buckets & File Uploads)](#3-storage-api-buckets--file-uploads)
  - [3.1 Create Storage Bucket (`POST /storage/v1/bucket`)](#31-create-storage-bucket-post-storagev1bucket)
  - [3.2 Upload File Binary (`POST /storage/v1/object/{bucket}/{filename}`)](#32-upload-file-binary-post-storagev1objectbucketfilename)
  - [3.3 Download or Get Public URL (`GET /storage/v1/object/public/{bucket}/{filename}`)](#33-download-or-get-public-url-get-storagev1objectpublicbucketfilename)
- [4. Auth & User Management API](#4-auth--user-management-api)
  - [4.1 Create User Admin (`POST /auth/v1/admin/users`)](#41-create-user-admin-post-authv1adminusers)
  - [4.2 List Users (`GET /auth/v1/admin/users`)](#42-list-users-get-authv1adminusers)
- [5. Direct PostgreSQL Access via Native n8n Node](#5-direct-postgresql-access-via-native-n8n-node)
- [6. Ready-to-Import n8n Workflow JSON](#6-ready-to-import-n8n-workflow-json)
- [7. PostgREST Filtering Syntax Reference](#7-postgrest-filtering-syntax-reference)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

### 1.1 PostgREST API Header Auth (Recommended for REST)

To query Supabase tables through Kong API Gateway:

1. In n8n, click **Credentials** → **Add Credential**.
2. Select **Header Auth**.
3. Fill in:
   - **Credential Name:** `Supabase Service Role` (for full backend admin privileges)
   - **Name:** `apikey`
   - **Value:** `${SUPABASE_SERVICE_ROLE_KEY}`
4. Click **Save**.

> [!TIP]
> Supabase PostgREST requires both the `apikey` header and `Authorization: Bearer <KEY>`. You can either add a second header in the node or use `Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}` as your Header Auth value.

### 1.2 Native PostgreSQL Node Credentials (Direct DB Access)

You can also use n8n's native **PostgreSQL** node to connect directly to the Supabase database:
- **Host:** `db` (or `supabase-db`)
- **Port:** `5432`
- **Database:** `postgres`
- **User:** `postgres`
- **Password:** `${SUPABASE_DB_PASSWORD}`
- **SSL:** `disable`

---

## 2. PostgREST Database API Endpoints

All database tables are automatically mapped to REST endpoints at `http://kong:8000/rest/v1/{table_name}`.

### 2.1 Querying Records (`GET /rest/v1/{table}`)

#### cURL Command
```bash
curl -X GET "http://kong:8000/rest/v1/customers?select=id,name,email&status=eq.active" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### n8n HTTP Request Configuration
- **Method:** `GET`
- **URL:** `http://kong:8000/rest/v1/customers`
- **Authentication:** `Header Auth` (or send headers below)
- **Send Query Parameters:** `true`
  - `select`: `*`
  - `limit`: `20`

---

### 2.2 Inserting Records (`POST /rest/v1/{table}`)

> [!NOTE]
> Include the header `Prefer: return=representation` if you want PostgREST to return the newly inserted record (with its auto-generated `id`).

#### cURL Command
```bash
curl -X POST "http://kong:8000/rest/v1/customers" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "name": "Acme Corp",
    "email": "contact@acme.com",
    "status": "active"
  }'
```

#### n8n HTTP Request Configuration
- **Method:** `POST`
- **URL:** `http://kong:8000/rest/v1/customers`
- **Send Headers:** `true`
  - `Prefer`: `return=representation`
- **Send Body:** `true`
- **Body Content Type:** `JSON`
- **JSON Body:**
  ```json
  {
    "name": "={{ $json.name }}",
    "email": "={{ $json.email }}"
  }
  ```

---

### 2.3 Updating Records (`PATCH /rest/v1/{table}`)

#### cURL Command
```bash
curl -X PATCH "http://kong:8000/rest/v1/customers?id=eq.42" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "status": "upgraded"
  }'
```

---

### 2.4 Deleting Records (`DELETE /rest/v1/{table}`)

#### cURL Command
```bash
curl -X DELETE "http://kong:8000/rest/v1/customers?id=eq.42" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 3. Storage API (Buckets & File Uploads)

### 3.1 Create Storage Bucket (`POST /storage/v1/bucket`)

#### cURL Command
```bash
curl -X POST "http://kong:8000/storage/v1/bucket" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "id": "invoices",
    "name": "invoices",
    "public": true
  }'
```

---

### 3.2 Upload File Binary (`POST /storage/v1/object/{bucket}/{filename}`)

Upload binary attachments (e.g. from Docling or Crawl4AI screenshot) directly to Supabase storage.

#### cURL Command
```bash
curl -X POST "http://kong:8000/storage/v1/object/invoices/report.pdf" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/pdf" \
  --data-binary "@report.pdf"
```

#### n8n HTTP Request Configuration
- **Method:** `POST`
- **URL:** `http://kong:8000/storage/v1/object/invoices/{{ $json.filename }}`
- **Send Body:** `true`
- **Body Content Type:** `Binary Data`
- **Input Data Field Name:** `data`

---

### 3.3 Download or Get Public URL (`GET /storage/v1/object/public/{bucket}/{filename}`)

Direct URL to view or download a file:
```
http://kong:8000/storage/v1/object/public/invoices/report.pdf
```

---

## 4. Auth & User Management API

### 4.1 Create User Admin (`POST /auth/v1/admin/users`)

Creates a new user without sending an email confirmation:

#### cURL Command
```bash
curl -X POST "http://kong:8000/auth/v1/admin/users" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePassword123!",
    "email_confirm": true,
    "user_metadata": { "role": "editor" }
  }'
```

---

## 5. Direct PostgreSQL Access via Native n8n Node

When performing bulk updates or complex joins, use n8n's native **Postgres** node:

```
[ Trigger ] --> [ Postgres Node: "SELECT * FROM public.customers WHERE created_at > NOW() - INTERVAL '1 day'" ]
```

Credentials:
- **Host:** `db`
- **Port:** `5432`
- **User:** `postgres`
- **Password:** `${POSTGRES_PASSWORD}`
- **Database:** `postgres`

---

## 6. Ready-to-Import n8n Workflow JSON

Copy this JSON and press `Ctrl + V` inside n8n to import a ready-to-test Supabase PostgREST query:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "target_table",
              "name": "table",
              "value": "customers",
              "type": "string"
            }
          ]
        }
      },
      "id": "set-supabase-table",
      "name": "Set Table Name",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "GET",
        "url": "http://kong:8000/rest/v1/customers",
        "sendHeaders": true,
        "headerParameters": {
          "parameters": [
            {
              "name": "apikey",
              "value": "${SUPABASE_ANON_KEY}"
            },
            {
              "name": "Authorization",
              "value": "Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
            }
          ]
        },
        "options": {}
      },
      "id": "supabase-query",
      "name": "Supabase Query Table",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Set Table Name": {
      "main": [
        [
          {
            "node": "Supabase Query Table",
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

## 7. PostgREST Filtering Syntax Reference

| Operator | Meaning | Example URL Query |
| :--- | :--- | :--- |
| `eq` | Equals | `?status=eq.active` |
| `neq` | Not equals | `?status=neq.deleted` |
| `gt` / `gte` | Greater than / or equal | `?price=gte.100` |
| `lt` / `lte` | Less than / or equal | `?age=lt.30` |
| `like` / `ilike` | Like / Case-insensitive like | `?name=ilike.*john*` |
| `in` | One of list | `?status=in.(active,pending)` |
| `is` | Is null or boolean | `?deleted_at=is.null` |
| `order` | Order by column | `?order=created_at.desc` |
| `limit` / `offset` | Pagination | `?limit=10&offset=20` |
