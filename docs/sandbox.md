<div align="center">
  <img src="../assets/logos/docker.svg" width="64" height="64" alt="n8n Sandbox Logo" />
  <h1>n8n Code Sandbox Runner & API Guide</h1>
  <p><strong>Isolated Docker-in-Docker Execution Engine for Python & JavaScript Nodes</strong></p>
</div>

> **Docker Internal URL (Use in n8n):** `http://sandbox-api:8080`  
> **Host URL (Browser / Postman):** `http://localhost:5681`  
> **Health Check Endpoint:** `http://localhost:5681/healthz`  
> **Authentication Header:** `X-API-Key: ${SANDBOX_API_KEYS}`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${SANDBOX_API_KEYS}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

The **n8n Sandbox Service** (`sandbox-api` and `sandbox-runner-1`) is an isolated Docker-in-Docker (DinD) execution environment designed to execute untrusted or heavy Python and JavaScript Code nodes securely without risking the stability of your primary n8n container.

---

## Table of Contents

- [1. Architecture Overview](#1-architecture-overview)
- [2. Quick Health Check & Status](#2-quick-health-check--status)
  - [2.1 Health Check (`GET /healthz`)](#21-health-check-get-healthz)
  - [2.2 Active Sandboxes (`GET /sandboxes`)](#22-active-sandboxes-get-sandboxes)
- [3. Running Code Inside n8n Code Nodes](#3-running-code-inside-n8n-code-nodes)
  - [3.1 Running Python in n8n](#31-running-python-in-n8n)
  - [3.2 Running Modern JavaScript in n8n](#32-running-modern-javascript-in-n8n)
- [4. Installing Custom Python & NPM Packages in the Runner](#4-installing-custom-python--npm-packages-in-the-runner)
- [5. Troubleshooting & Gotchas](#5-troubleshooting--gotchas)

---

## 1. Architecture Overview

In standard n8n installations, Code nodes run inside the primary Node.js process. When executing heavy operations (like parsing complex arrays or running CPU-intensive Python calculations), the main workflow queue can freeze.

With the **Automation Sandbox Suite**:
- `sandbox-api` acts as the gRPC / HTTP coordinator.
- `sandbox-runner-1` executes code tasks inside isolated, ephemeral container sandboxes via TLS-secured gRPC.
- If a user script runs into an infinite loop or consumes excessive memory, only the micro-sandbox is terminated—your n8n server remains 100% operational.

---

## 2. Quick Health Check & Status

### 2.1 Health Check (`GET /healthz`)

Verify the sandbox coordinator is online and healthy.

#### cURL Command
```bash
curl -X GET "http://localhost:5681/healthz" \
  -H "X-API-Key: ${SANDBOX_API_KEYS}"
```

#### From within n8n (Docker internal)
```bash
curl -X GET "http://sandbox-api:8080/healthz" \
  -H "X-API-Key: ${SANDBOX_API_KEYS}"
```

#### Expected Response
```json
{
  "status": "ok"
}
```

---

### 2.2 Active Sandboxes (`GET /sandboxes`)

Lists currently running sandbox container executions:

```bash
curl -X GET "http://sandbox-api:8080/sandboxes" \
  -H "X-API-Key: ${SANDBOX_API_KEYS}"
```

---

## 3. Running Code Inside n8n Code Nodes

When using the native **Code** node in n8n:

### 3.1 Running Python in n8n

1. Drag a **Code** node onto your canvas.
2. Set **Language:** `Python`.
3. Set **Mode:** `Run Once for All Items`.
4. Example Code Snippet:
   ```python
   # Transform items using Python standard libraries
   items = _input.all()
   results = []

   for item in items:
       json_data = item.json
       # Compute summary or hash
       cleaned_text = json_data.get('content', '').strip().lower()
       results.append({
           'json': {
               'original_id': json_data.get('id'),
               'word_count': len(cleaned_text.split()),
               'is_valid': len(cleaned_text) > 0
           }
       })

   return results
   ```

### 3.2 Running Modern JavaScript in n8n

1. Set **Language:** `JavaScript`.
2. Set **Mode:** `Run Once for All Items`.
3. Example Code Snippet:
   ```javascript
   // Filter and sort items efficiently
   const items = $input.all();

   const filtered = items
     .filter(item => item.json.score > 0.8)
     .sort((a, b) => b.json.score - a.json.score);

   return filtered;
   ```

---

## 4. Installing Custom Python & NPM Packages in the Runner

If your Python code requires external libraries (such as `pandas`, `requests`, `numpy`, or `scikit-learn`):

1. Access the runner container via terminal:
   ```bash
   docker exec -it sandbox-runner-1 sh
   ```
2. Or configure persistent package installations in `compose.yml` under `sandbox-runner-1` environment variables:
   ```yaml
   environment:
     - NODE_FUNCTION_ALLOW_EXTERNAL=axios,lodash,moment
     - PYTHON_EXTERNAL_PACKAGES=pandas,numpy,requests
   ```

---

## 5. Troubleshooting & Gotchas

1. **`Cannot find module 'xyz'` in Code node:**  
   By default, n8n restricts loading arbitrary npm packages unless declared in `NODE_FUNCTION_ALLOW_EXTERNAL` inside [`.env`](file:///c:/Users/Vishal/Desktop/Automation/.env).
2. **TLS Certificate Expiration:**  
   The `sandbox-certs` init container automatically generates mutual TLS certs in the `sandbox-tls` volume upon first start. If certificates become desynchronized, restart the stack with `docker compose restart sandbox-certs sandbox-api sandbox-runner-1`.
