# Changelog

All notable changes to the **AutomationKit** project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-10-19 — Stable v1 Release 🚀

### 🌟 Overview
Initial production-grade stable release of **AutomationKit** — the turn-key, self-hosted local AI orchestration, workflow automation, and microservices cloud platform. Packages 24+ coordinated containers orchestrated via Docker Compose v2 behind an intelligent zero-trust Caddy gateway.

---

### 🚀 Added Features & Capabilities

#### 1. Core Workflow & AI Microservices
* **n8n Workflow Engine (`v2.43.7`)**: Integrated with dedicated external task-runners (`n8n-runners`), Redis execution broker, and PostgreSQL state database.
* **Isolated DinD AI Code Sandbox**: Docker-in-Docker ephemeral execution runner (`sandbox-runner-1`) managed by a dedicated mTLS control plane API (`sandbox-api:8080`), enabling safe execution of arbitrary user-submitted Python and JavaScript code.
* **Supabase Local Cloud Cluster (10 Microservices)**:
  * `supabase-studio`: Next-gen database management and table editor console (`:54323`).
  * `supabase-kong`: API Gateway orchestrating PostgREST and Auth routing (`:8000`).
  * `supabase-db`: PostgreSQL 17 relational database engine (`:5432`).
  * `supabase-auth`: GoTrue identity and session management daemon.
  * `supabase-rest`: PostgREST instant RESTful API generator.
  * `realtime-dev.supabase-realtime`: WebSockets pub/sub engine for database change events.
  * `supabase-storage`: S3-compatible file and object storage engine.
  * `supabase-meta`: Schema metadata and SQL inspection engine.
  * `supabase-edge-functions`: Deno/Edge runtime execution engine.
  * `supabase-imgproxy`: Dynamic media transformation and resizing proxy.
* **Local Inference & Embeddings**:
  * **Ollama**: Local LLM neural inference server (`:11434`) supporting Llama 3, Mistral, and Qwen.
  * **IBM Docling Serve**: Enterprise document parser, OCR, table extraction, and multi-format converter (`:5001`).
  * **Qdrant Vector Database (`v1.19.2`)**: High-performance semantic vector database and REST console (`:6333`).
  * **Neo4j Graph Database (`5-community`)**: Graph database engine with interactive Cypher browser (`:7474`) and Bolt protocol (`bolt://:7687`).
* **Web Scraping & Search**:
  * **Crawl4AI**: Playwright-backed async web crawler with structured LLM entity extraction and Markdown generation (`:11235`).
  * **SearXNG**: Privacy-preserving metasearch engine and JSON search aggregator (`:8080`).
* **Caching & Storage**:
  * **Redis 7 & Redis Insight**: In-memory caching, message queues, and visual GUI (`:5540`).
  * **PostgreSQL 16**: High-throughput relational storage for n8n workflow states (`:5432`).

#### 2. Master Control Center & Web Portal (`http://localhost`)
* **Real-Time Live Telemetry System**:
  * Dynamic deflection sparkline line charts for both CPU Load and System RAM.
  * Real-time color-coded health badges: Green (`HEALTHY` / `OPTIMAL`), Amber (`MODERATE`), Red (`HIGH LOAD`).
  * Cluster container status meter displaying active container counts.
* **Dual Live Linux Streaming Terminals**:
  * **n8n Runner Environment**: Dedicated interactive terminal for executing Python (`pip`, `uv`), Node.js, and runner diagnostics.
  * **Ollama Terminal**: Unrestricted developer CLI for pulling, inspecting, and managing local LLM models (`ollama run`, `ollama list`).
* **Primary Tools vs Grouped Services Views**:
  * **Tools View**: Card-style interactive UI launchpad with direct dashboard links, status pills, and collapsible subservice drawers.
  * **Services View**: Container hierarchy grouped by stack role with live per-container CPU/RAM metrics and start/stop switches.
  * **In-Place Buffering Spinner**: Smooth CSS spinner completely replaces the toggle knob during state transitions, eliminating UI overlay glitches.
* **Adaptive Dark & Light Mode**:
  * Modern OLED dark mode and sleek light mode with instant theme switching.
  * Dynamic Ollama logo adaptation (white llama in dark mode, black llama in light mode).

#### 3. Knowledge Hub & Interactive API Docs (`http://localhost/docs.html`)
* **Dynamic `.env` Injection Engine**:
  * Documentation automatically fetches active environment values (`/api/env`) and injects them live into copyable cURL snippets while keeping source markdown files protected.
* **One-Click n8n Credential Generator**:
  * Step-by-step instructions and ready-to-test cURL commands with one-click copy buttons for every tool.
* **Compact Split-Screen Reading View**:
  * Two-column reading layout pairing request cURL snippets on the left with expected response structures on the right.
  * Removed redundant in-body Tables of Contents to maximize reader window space.
* **Adjustable & Collapsible Document Structure Sidebar**:
  * Drag-to-resize outline sidebar with one-click collapse/expand toggle.
  * Independent sidebar mouse-wheel scrolling with real-time scrollspy topic highlighting.
* **Individual In-Depth Integration Guides**:
  * Comprehensive markdown guides covering endpoints, authentication, payload schemas, and n8n node integration for all 10 tools (`docling.md`, `crawl4ai.md`, `ollama.md`, `qdrant.md`, `searxng.md`, `supabase.md`, `neo4j.md`, `redis.md`, `postgres.md`, `sandbox.md`).

#### 4. Developer Experience & Unified CLI
* **Single Master Control Script (`automation.bat`)**:
  * Consolidates all lifecycle actions into one unified script with both an interactive menu and direct CLI subcommands (`start`, `stop`, `restart`, `open`, `docs`, `hosts`, `status`, `logs`, `pull`, `reset-n8n`).
  * Removed redundant loose scripts (`start.bat`, `setup-hosts.bat`, `open-hub.bat`) for a clean, clutter-free repository root.
* **Smart DNS Routing & Gateway**:
  * Transparent Caddy reverse proxy serving local `.local` domains with automatic `.localhost` zero-config browser fallback.
  * Automatic Bearer token authentication injection for API UIs (e.g. Crawl4AI Swagger/ReDoc).

---

### 🎨 Visual & Branding Updates
* Replaced all monochrome and third-party badge URLs with authentic, high-resolution official colored SVGs:
  * **Supabase**: Multi-facet emerald green lightning bolt (`#3ECF8E` / `#249361`).
  * **Qdrant**: 3D isometric vector cube with shaded crimson, coral, and ruby facets (`#dc244c`, `#9e0d38`, `#ff516b`).
  * **Redis**: Official 3-layer stacked 3D database blocks (`#912626`, `#C6302B`, `#621B1C`, `#9A2928`, `#FFF`).
  * **Docling**: Official colorful IBM Docling duck mascot illustration.
  * **Crawl4AI**: Cyber radar scanner ring with neon magenta, purple, and electric cyan core (`#8B5CF6`, `#FF2EC4`, `#0BC5EA`).
  * **Neo4j**: Connected graph network with blue arch (`#018BFF`), orange node (`#FF7E40`), and green node (`#45C55F`).
  * **SearXNG**: Royal blue search glass (`#3050ff`) with cyan inner reflection lens (`#00D2FF`).
  * **PostgreSQL**: Official Slonik blue elephant emblem (`#336791`, `#1b3954`, `#FFFFFF`).
  * **n8n**: Vibrant rose-red tracks (`#EA4B71`) with coral orange nodes (`#FF6D5A`).
  * **Docker / Sandbox**: Official Docker blue container whale (`#2496ED`).
  * **Caddy**: Official Caddy green shield emblem (`#22B573`, `#FFFFFF`).
* Added custom 5px thin scrollbar matching the stack's coral-orange accent (`#ff6d5a`).

---

### 🔒 Security & Credential Hardening
* Completely sanitized all documentation and batch scripts by replacing hardcoded passwords and API keys with standard `.env` placeholders (`${POSTGRES_PASSWORD}`, `${CRAWL4AI_API_TOKEN}`, `${QDRANT_PASSWORD}`, `${DOCLING_API_KEY}`, `${SANDBOX_API_KEYS}`).
* Zero plain-text credentials stored in source control.

---

### 📋 Version Matrix

| Service | Version Tag |
| :--- | :--- |
| **AutomationKit Core** | `v1.0.0` (Stable) |
| **n8n Workflow Automation** | `v2.43.7` |
| **Supabase Studio** | `2026.10.12-sha-3699278` |
| **Supabase PostgreSQL** | `17.6.1.136` |
| **Kong API Gateway** | `3.9.3` |
| **GoTrue Auth** | `v2.197.0` |
| **PostgREST** | `v14.18` |
| **Realtime Engine** | `v2.143.3` |
| **Storage API** | `v1.81.0` |
| **Docling Parser** | `Latest` (quay.io) |
| **Crawl4AI** | `Latest` |
| **Ollama** | `Latest` |
| **Qdrant Vector DB** | `v1.19.2` |
| **Neo4j Community** | `5-community` |
| **Redis & Insight** | `7-alpine` / `Latest` |
| **PostgreSQL Primary** | `16-alpine` |
| **n8n DinD Sandbox Service**| `v1.9.0` |
| **Caddy Gateway** | `2-alpine` |
