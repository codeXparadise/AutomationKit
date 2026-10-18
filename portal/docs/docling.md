<div align="center">
  <img src="../assets/logos/docling.svg" width="64" height="64" alt="Docling Logo" />
  <h1>IBM Docling — Complete API & n8n Integration Guide</h1>
  <p><strong>High-Accuracy Document OCR & Multi-Format Parsing for GenAI</strong></p>
</div>

> **Docker Internal URL (Use in n8n):** `http://docling:5001`  
> **Host URL (Browser / Postman):** `http://localhost:5001`  
> **Interactive Swagger UI:** `http://localhost:5001/docs`  
> **OpenAPI Schema:** `http://localhost:5001/openapi.json`  
> **Authentication Header:** `X-API-Key: ${DOCLING_API_KEY}`  

> [!TIP]
> **Dynamic Environment Resolution:** All API keys and secrets in this documentation use `.env` placeholders (e.g. `${DOCLING_API_KEY}`). When viewed inside the AutomationKit Console or imported through n8n, these values are dynamically resolved from your local `.env`. When committing to GitHub, your secrets remain 100% protected.

IBM Docling is a high-accuracy document parsing and conversion engine purpose-built for GenAI, LLM RAG pipelines, and automated document understanding. It parses PDFs (including scanned documents), Microsoft Office documents (DOCX, PPTX, XLSX), HTML, and images into structured Markdown, JSON, HTML, YAML, or vector-ready chunks.

---

## Table of Contents

- [1. Quick n8n Credentials Setup (Easiest Method)](#1-quick-n8n-credentials-setup-easiest-method)
- [2. Supported Formats Reference (Swagger / OpenAPI Spec)](#2-supported-formats-reference-swagger--openapi-spec)
  - [2.1 Output Formats (`to_formats`) Enum](#21-output-formats-to_formats-enum)
  - [2.2 Input Formats (`from_formats`) Enum](#22-input-formats-from_formats-enum)
- [3. Full Conversion Options Matrix (`ConvertDocumentsOptions`)](#3-full-conversion-options-matrix-convertdocumentsoptions)
- [4. Converting Documents via Public or S3 URL](#4-converting-documents-via-public-or-s3-url)
  - [4.1 Single Format Conversion (Markdown for LLMs)](#41-single-format-conversion-markdown-for-llms)
  - [4.2 Multi-Format Conversion (`["md", "json", "html"]`)](#42-multi-format-conversion-md-json-html)
  - [4.3 Advanced OCR & Table Extraction Options](#43-advanced-ocr--table-extraction-options)
  - [4.4 AI Vision Picture & Chart Description (VLM Presets)](#44-ai-vision-picture--chart-description-vlm-presets)
- [5. Converting Binary Files from n8n (Multipart Upload)](#5-converting-binary-files-from-n8n-multipart-upload)
  - [5.1 Upload Single File Binary (`POST /v1/convert/file`)](#51-upload-single-file-binary-post-v1convertfile)
  - [5.2 Multipart with Multiple Output Formats](#52-multipart-with-multiple-output-formats)
- [6. Vector Chunking Endpoints (RAG & Qdrant Preparation)](#6-vector-chunking-endpoints-rag--qdrant-preparation)
  - [6.1 Hybrid Chunking (`POST /v1/chunk/hybrid/source`)](#61-hybrid-chunking-post-v1chunkhybridsource)
  - [6.2 Hierarchical Chunking (`POST /v1/chunk/hierarchical/source`)](#62-hierarchical-chunking-post-v1chunkhierarchicalsource)
- [7. Asynchronous Batch Processing for Large Documents](#7-asynchronous-batch-processing-for-large-documents)
  - [7.1 Submit Async Conversion (`POST /v1/convert/source/async`)](#71-submit-async-conversion-post-v1convertsourceasync)
  - [7.2 Poll Task Status (`GET /v1/status/poll/{task_id}`)](#72-poll-task-status-get-v1statuspolltask_id)
  - [7.3 Fetch Completed Result (`GET /v1/result/{task_id}`)](#73-fetch-completed-result-get-v1resulttask_id)
- [8. Health & System Diagnostics](#8-health--system-diagnostics)
  - [8.1 Health Status (`GET /health`)](#81-health-status-get-health)
  - [8.2 Engine Capabilities (`GET /v1/capabilities`)](#82-engine-capabilities-get-v1capabilities)
  - [8.3 Memory & Cache Management](#83-memory--cache-management)
- [9. Complete Ready-to-Import n8n Workflow JSON (Multi-Format)](#9-complete-ready-to-import-n8n-workflow-json-multi-format)
- [10. Troubleshooting & Common Pitfalls](#10-troubleshooting--common-pitfalls)

---

## 1. Quick n8n Credentials Setup (Easiest Method)

To set up credentials once in n8n and reuse them across all Docling nodes:

1. In n8n, navigate to **Credentials** in the left sidebar and click **Add Credential**.
2. Search for and select **Header Auth**.
3. Fill in:
   - **Credential Name:** `Docling Auth`
   - **Name:** `X-API-Key`
   - **Value:** `${DOCLING_API_KEY}`
4. Click **Save**.

Now, inside your n8n **HTTP Request** node:
- **Authentication:** `Predefined Credential Type`
- **Credential Type:** `Header Auth`
- **Credential for Header Auth:** `Docling Auth`

---

## 2. Supported Formats Reference (Swagger / OpenAPI Spec)

### 2.1 Output Formats (`to_formats`) Enum

In any conversion request, you can supply one or **multiple output formats simultaneously** inside the `"to_formats"` array.

| Output Format String | Name / Specification | Best Use Case in n8n Workflows |
| :--- | :--- | :--- |
| `"md"` | **Markdown** *(Default)* | Clean text with headings, bold text, and markdown tables. Optimized for Ollama, OpenAI, and LLM context windows. |
| `"json"` | **Docling Native JSON** | Complete document AST (Abstract Syntax Tree), layout bounding boxes, table row/column cells, hierarchy levels, and font metadata. |
| `"html"` | **Clean HTML5** | Semantic HTML structure (`<table>`, `<h1>`-`<h6>`, `<p>`) for displaying documents on web dashboards or webhooks. |
| `"html_split_page"` | **Paginated HTML** | HTML segmented page-by-page, allowing page-level lazy loading in frontends. |
| `"text"` | **Plain Text** | Raw string text without formatting or symbols, suitable for basic keyword matching or regex filtering. |
| `"yaml"` | **YAML Representation** | Hierarchical YAML structure for human-readable configuration pipelines. |
| `"doctags"` | **Docling Tags** | Internal tagged representation used by vision-language models and Docling parsers. |
| `"chunks"` | **Pre-Chunked Text** | Pre-segmented semantic chunks ready for vector embeddings without calling a secondary chunking node. |
| `"latex"` | **LaTeX Document** | Mathematical document syntax for academic papers, equations, and technical publishing. |
| `"vtt"` | **Video Text Tracks** | Subtitle track format for timed transcripts. |
| `"doclang"` | **XML DocLang** | XML-based enterprise document exchange representation. |
| `"dclx"` | **Compressed Document** | High-density binary-safe serialization for storage in databases. |

---

### 2.2 Input Formats (`from_formats`) Enum

Docling automatically detects file types, but you can explicitly filter or restrict accepted inputs via `"from_formats"`:

| Input Format | Description |
| :--- | :--- |
| `pdf` | Standard digital PDFs and scanned image PDFs (with OCR). |
| `docx`, `doc`, `rtf`, `odt` | Microsoft Word and OpenDocument text formats. |
| `pptx`, `ppt`, `odp` | Microsoft PowerPoint and OpenDocument presentations. |
| `xlsx`, `xls`, `ods`, `csv` | Microsoft Excel, OpenDocument spreadsheets, and comma-separated tables. |
| `html`, `mhtml` | Raw HTML documents and saved web archives. |
| `image` | Scanned receipts, invoices, PNG, JPEG, TIFF, WEBP, BMP. |
| `asciidoc`, `md` | AsciiDoc and raw Markdown files. |
| `epub`, `boxnote` | Digital eBook EPUB files and Box Notes. |
| `iwork_pages`, `iwork_keynote`, `iwork_numbers` | Apple iWork suite documents. |
| `xml_uspto`, `xml_jats`, `xml_xbrl`, `xml_doclang` | Patent filings, academic journal XML, financial XBRL reports. |
| `latex`, `vtt`, `email` | Raw TeX documents, subtitles, and standard `.eml` email files. |

---

## 3. Full Conversion Options Matrix (`ConvertDocumentsOptions`)

These parameters can be passed under the `"options"` key in your JSON body:

| Option Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `to_formats` | `array[string]` | `["md"]` | List of target formats to generate (e.g. `["md", "json", "html"]`). |
| `from_formats` | `array[string]` | `null` (all) | Allowed input formats. Restricts parsing to specific extensions. |
| `do_ocr` | `boolean` | `true` | Enable deep OCR engine for scanned images or non-text PDFs. |
| `ocr_engine` | `string` | `"easyocr"` | Choice of OCR engine: `"easyocr"`, `"tesseract"`, `"rapidocr"`, `"mac_ocr"`. |
| `ocr_lang` | `array[string]` | `["en"]` | Language codes for OCR recognition (e.g. `["en", "hi", "de", "fr"]`). |
| `do_table_structure` | `boolean` | `true` | Enable TableFormer neural network for reconstructing merged table cells and headers. |
| `table_structure_preset` | `string` | `"default"` | Presets: `"default"`, `"tableformer_v1_accurate"`, `"tableformer_v1_fast"`, `"tableformer_v2"`. |
| `images_scale` | `number` | `2.0` | Scaling multiplier for image preprocessing (higher = sharper OCR, more RAM). |
| `generate_picture_images`| `boolean` | `false` | When `true`, extracts embedded pictures and charts as image artifacts. |
| `include_page_images` | `boolean` | `false` | When `true`, renders full-page image snapshots of every page. |
| `picture_description_preset`| `string`| `null` | Vision LLM preset to automatically describe images/charts: `"smolvlm"`, `"granite_vision"`. |
| `max_num_pages` | `integer` | `null` | Limit processing to first N pages (prevents memory spikes on 500-page manuals). |
| `max_file_size` | `integer` | `null` | Maximum file size in bytes to process. |
| `abort_on_error` | `boolean` | `false` | If `false`, returns partial results if a single page fails. |

---

## 4. Converting Documents via Public or S3 URL

### 4.1 Single Format Conversion (Markdown for LLMs)

#### cURL Command
```bash
curl -X POST "http://docling:5001/v1/convert/source" \
  -H "X-API-Key: ${DOCLING_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [
      {
        "type": "url",
        "url": "https://arxiv.org/pdf/2408.09869.pdf"
      }
    ],
    "options": {
      "to_formats": ["md"]
    }
  }'
```

#### n8n Expression to Access Markdown
```javascript
{{ $json.results[0].markdown }}
```

---

### 4.2 Multi-Format Conversion (`["md", "json", "html"]`)

You can generate multiple outputs in a **single pass**. Docling processes the document once through the OCR and layout pipeline, then exports all requested formats simultaneously.

#### cURL Command
```bash
curl -X POST "http://docling:5001/v1/convert/source" \
  -H "X-API-Key: ${DOCLING_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [
      {
        "type": "url",
        "url": "https://arxiv.org/pdf/2408.09869.pdf"
      }
    ],
    "options": {
      "to_formats": ["md", "json", "html", "text"]
    }
  }'
```

#### Multi-Format Response Structure
When multiple formats are requested, Docling returns all of them populated in the `results[0]` object:

```json
{
  "results": [
    {
      "source": "https://arxiv.org/pdf/2408.09869.pdf",
      "status": "success",
      "markdown": "# Docling Technical Report\n\n## Abstract\nDocument processing...",
      "html": "<html><body><h1>Docling Technical Report</h1><p>Document processing...</p></body></html>",
      "text": "Docling Technical Report Abstract Document processing...",
      "json": {
        "schema_name": "docling_core.models.DoclingDocument",
        "version": "1.0.0",
        "body": {
          "children": [
            {
              "text": "Docling Technical Report",
              "label": "title",
              "prov": [{ "page_no": 1, "bbox": [54.0, 72.0, 500.0, 100.0] }]
            }
          ]
        },
        "tables": []
      },
      "timings": {
        "read": 0.15,
        "convert": 3.12
      }
    }
  ]
}
```

#### How to Reference Each Format in n8n Nodes
- **Markdown Text:** `{{ $json.results[0].markdown }}`
- **Rendered HTML:** `{{ $json.results[0].html }}`
- **Plain Text:** `{{ $json.results[0].text }}`
- **Parsed Table Count:** `{{ $json.results[0].json.tables.length }}`
- **First Table Cells:** `{{ $json.results[0].json.tables[0].data }}`

---

### 4.3 Advanced OCR & Table Extraction Options

For scanned financial statements, complex spreadsheets, or multi-lingual documents:

#### JSON Body Payload
```json
{
  "sources": [
    {
      "type": "url",
      "url": "https://example.com/scanned-invoice.pdf"
    }
  ],
  "options": {
    "to_formats": ["md", "json"],
    "do_ocr": true,
    "ocr_engine": "easyocr",
    "ocr_lang": ["en", "hi"],
    "do_table_structure": true,
    "table_structure_preset": "tableformer_v2",
    "images_scale": 2.0,
    "max_num_pages": 10
  }
}
```

---

### 4.4 AI Vision Picture & Chart Description (VLM Presets)

Docling can execute local Vision-Language Models (`smolvlm`, `granite_vision`) to automatically transcribe infographics, charts, and diagrams into detailed Markdown text descriptions:

#### JSON Body Payload
```json
{
  "sources": [
    {
      "type": "url",
      "url": "https://example.com/quarterly-report-with-charts.pdf"
    }
  ],
  "options": {
    "to_formats": ["md"],
    "generate_picture_images": true,
    "picture_description_preset": "smolvlm"
  }
}
```

---

## 5. Converting Binary Files from n8n (Multipart Upload)

When receiving attachments from email triggers (IMAP/Gmail), Telegram, Google Drive, or Webhook uploads.

### 5.1 Upload Single File Binary (`POST /v1/convert/file`)

#### cURL Command
```bash
curl -X POST "http://docling:5001/v1/convert/file" \
  -H "X-API-Key: ${DOCLING_API_KEY}" \
  -F "file=@document.pdf" \
  -F "to_formats=md"
```

#### n8n HTTP Request Node Configuration
- **Method:** `POST`
- **URL:** `http://docling:5001/v1/convert/file`
- **Authentication:** `Header Auth`
- **Send Body:** `true`
- **Body Content Type:** `Form-Data (Multipart)`
- **Specify Body:** `Using Fields Below`
- **Form Data Parameters:**
  - Field 1:
    - **Name:** `file`
    - **Parameter Type:** `Form Data (Binary)`
    - **Input Data Field Name:** `data` (or your binary property name)
  - Field 2:
    - **Name:** `to_formats`
    - **Parameter Type:** `Form Data (Text)`
    - **Value:** `md`

---

### 5.2 Multipart with Multiple Output Formats

To request multiple formats in multipart uploads, provide comma-separated values or repeated parameters:

#### cURL Command
```bash
curl -X POST "http://docling:5001/v1/convert/file" \
  -H "X-API-Key: ${DOCLING_API_KEY}" \
  -F "file=@invoice.pdf" \
  -F "to_formats=md" \
  -F "to_formats=json" \
  -F "to_formats=html" \
  -F "do_ocr=true"
```

---

## 6. Vector Chunking Endpoints (RAG & Qdrant Preparation)

Instead of using basic character-splitter nodes in n8n, use Docling's layout-aware chunkers. They preserve parent headers, table schemas, and lists as unified vector chunks.

### 6.1 Hybrid Chunking (`POST /v1/chunk/hybrid/source`)

#### cURL Command
```bash
curl -X POST "http://docling:5001/v1/chunk/hybrid/source" \
  -H "X-API-Key: ${DOCLING_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [
      {
        "type": "url",
        "url": "https://arxiv.org/pdf/2408.09869.pdf"
      }
    ],
    "chunking_options": {
      "max_tokens": 512,
      "merge_peers": true
    }
  }'
```

#### Chunk Response Structure
```json
{
  "results": [
    {
      "source": "https://arxiv.org/pdf/2408.09869.pdf",
      "chunks": [
        {
          "text": "Docling Technical Report. Authors: Christoph Auer...",
          "meta": {
            "page": 1,
            "headings": ["Docling Technical Report", "Abstract"],
            "token_count": 142
          }
        }
      ]
    }
  ]
}
```

---

### 6.2 Hierarchical Chunking (`POST /v1/chunk/hierarchical/source`)

Maintains strict parent-child section relationships (H1 > H2 > H3), ideal for recursive retrieval in vector databases like **Qdrant**.

#### JSON Body Payload
```json
{
  "sources": [{ "type": "url", "url": "https://example.com/policy-handbook.pdf" }],
  "chunking_options": {
    "include_metadata": true
  }
}
```

---

## 7. Asynchronous Batch Processing for Large Documents

For large documents (> 25 pages), synchronous calls might trigger HTTP gateway timeouts. Follow the 3-step async pattern:

```
[ POST /v1/convert/source/async ]  -->  Returns task_id
             |
[ Loop: GET /v1/status/poll/{task_id} ]  -->  Poll until status == 'SUCCESS'
             |
[ GET /v1/result/{task_id} ]  -->  Fetch complete multi-format result
```

### 7.1 Submit Async Conversion (`POST /v1/convert/source/async`)

```bash
curl -X POST "http://docling:5001/v1/convert/source/async" \
  -H "X-API-Key: ${DOCLING_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{ "type": "url", "url": "https://example.com/giant-manual.pdf" }],
    "options": { "to_formats": ["md", "json"] }
  }'
```

#### Response
```json
{
  "task_id": "9a12c8e3-0d34-4bc1-9e67-d8c56fa91b02"
}
```

### 7.2 Poll Task Status (`GET /v1/status/poll/{task_id}`)

```bash
curl -X GET "http://docling:5001/v1/status/poll/9a12c8e3-0d34-4bc1-9e67-d8c56fa91b02" \
  -H "X-API-Key: ${DOCLING_API_KEY}"
```

### 7.3 Fetch Completed Result (`GET /v1/result/{task_id}`)

```bash
curl -X GET "http://docling:5001/v1/result/9a12c8e3-0d34-4bc1-9e67-d8c56fa91b02" \
  -H "X-API-Key: ${DOCLING_API_KEY}"
```

---

## 8. Health & System Diagnostics

### 8.1 Health Status (`GET /health`)

```bash
curl -X GET "http://docling:5001/health" \
  -H "X-API-Key: ${DOCLING_API_KEY}"
```

### 8.2 Engine Capabilities (`GET /v1/capabilities`)

Inspect enabled OCR engines, available VLM presets, and maximum concurrency limits.

```bash
curl -X GET "http://docling:5001/v1/capabilities" \
  -H "X-API-Key: ${DOCLING_API_KEY}"
```

### 8.3 Memory & Cache Management

Clear loaded models or in-memory conversion task results:
- `POST http://docling:5001/v1/clear/results` — Frees RAM from completed async jobs.
- `POST http://docling:5001/v1/clear/converters` — Unloads OCR weights from memory.
- `GET http://docling:5001/v1/memory/stats` — Inspect memory consumption.

---

## 9. Complete Ready-to-Import n8n Workflow JSON (Multi-Format)

Copy this JSON, go to n8n, and press `Ctrl + V` to import a multi-format workflow that extracts **Markdown for LLM reasoning**, **HTML for web preview**, and **JSON for database table storage**:

```json
{
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "pdf_target_url",
              "name": "document_url",
              "value": "https://arxiv.org/pdf/2408.09869.pdf",
              "type": "string"
            }
          ]
        }
      },
      "id": "doc-input-step",
      "name": "Input PDF Target",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [240, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://docling:5001/v1/convert/source",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": true,
        "contentType": "json",
        "body": "={\n  \"sources\": [\n    {\n      \"type\": \"url\",\n      \"url\": \"{{ $json.document_url }}\"\n    }\n  ],\n  \"options\": {\n    \"to_formats\": [\"md\", \"json\", \"html\"],\n    \"do_ocr\": true,\n    \"do_table_structure\": true\n  }\n}",
        "options": {
          "timeout": 120000
        }
      },
      "id": "docling-multiformat-convert",
      "name": "Docling Multi-Format Convert",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [460, 300]
    },
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "out_md",
              "name": "markdown_for_llm",
              "value": "={{ $json.results[0].markdown }}",
              "type": "string"
            },
            {
              "id": "out_html",
              "name": "html_for_web",
              "value": "={{ $json.results[0].html }}",
              "type": "string"
            },
            {
              "id": "out_tables",
              "name": "tables_json",
              "value": "={{ $json.results[0].json.tables }}",
              "type": "array"
            }
          ]
        }
      },
      "id": "split-format-outputs",
      "name": "Separate Format Outputs",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [680, 300]
    }
  ],
  "connections": {
    "Input PDF Target": {
      "main": [
        [
          {
            "node": "Docling Multi-Format Convert",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Docling Multi-Format Convert": {
      "main": [
        [
          {
            "node": "Separate Format Outputs",
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

## 10. Troubleshooting & Common Pitfalls

1. **`to_formats` vs `to_format`:**  
   Always use the plural `"to_formats"` with an array (e.g. `["md"]` or `["md", "json"]`). Passing a plain string or singular `to_format` will return a `422 Unprocessable Entity` validation error.
2. **Missing OCR Language Packs:**  
   If parsing non-English documents (e.g. Hindi, German, Japanese), explicitly pass `"ocr_lang": ["hi", "en"]` inside `"options"`.
3. **Heavy Table Extraction CPU Spikes:**  
   `"do_table_structure": true` runs TableFormer, which accurately predicts table cell spans. If processing high-volume simple text invoices, set `"table_structure_preset": "tableformer_v1_fast"` to increase throughput by 3x.
4. **Timeouts on Large Files:**  
   Always increase node **Timeout** to `120000` (2 minutes) in the n8n HTTP Request node **Options** panel when dealing with files over 10 pages.
