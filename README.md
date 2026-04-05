# Mitra Central

A modular, multi-agent AI chatbot platform for QAD ERP.

## Agents

| Agent | Role | Data source |
|---|---|---|
| **Mitra** | Natural-language → SQL on live QAD data | Progress DB via ODBC |
| **Apex** | Floating RAG assistant for user guides | n8n RAG pipeline (PDFs) |
| **Visual Intelligence** | KPI and chart generation from aggregated SQL | Progress DB via ODBC |
| **QAD-Zone** | Custom QAD code & document generation (RAG) | n8n RAG pipeline |

Each agent has its **own n8n webhook** and is a fully self-contained module under `app/agents/`. Adding a new agent = drop a new folder and register it in `app/agents/registry.py`. Nothing else changes.

## Stack

- **Backend**: FastAPI (Python)
- **Frontend**: Jinja2 + Tailwind (CDN) + Alpine.js + Chart.js
- **DB**: pyodbc → Progress ODBC driver
- **Session/Cache**: Redis
- **AI orchestration**: n8n (all LLM logic lives there)

## Quick start

```bash
cp .env.example .env
# edit .env with your n8n webhook URLs, ODBC DSN, Redis URL

pip install -r requirements.txt
./run.sh
```

Open <http://localhost:8000> and log in with `admin` / `mfgpro`.

## Project structure

```
app/
├── main.py                # FastAPI entry point
├── core/                  # config, redis client, security, session
├── db/                    # ODBC connection manager
├── auth/                  # login (hardcoded in Phase 1)
├── agents/                # ← each agent is a self-contained module
│   ├── registry.py
│   ├── base.py
│   ├── mitra/             # text-to-SQL on live QAD
│   ├── apex/              # floating RAG widget
│   ├── visual_intelligence/
│   └── qad_zone/
├── templates/             # Jinja2 templates
└── static/                # css, js
```

## Adding a new agent

1. Create `app/agents/my_agent/` with `routes.py`, `service.py`, `schemas.py`
2. Register it in `app/agents/registry.py`
3. Add its webhook URL to `.env`
4. Add a template under `app/templates/agents/`

Done. Sidebar picks it up automatically from the registry.
