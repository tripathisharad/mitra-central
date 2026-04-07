/* Mitra Central — WebSocket streaming front-end.
 *
 * All agents communicate via WebSocket with a JSON frame protocol:
 *   {type: "token"|"status"|"sql"|"table"|"chart"|"sources"|"followup"|"doc"|"error"|"done", data: ...}
 *
 * wsChat(wsPath, agentType) — Alpine component factory for main agents (Mitra, Visual, QAD-Zone)
 * apexWidget() — Alpine component for the floating Apex RAG chatbot
 */

/* ---- helpers ---- */

function escapeHtml(s) {
  if (s === null || s === undefined) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderMarkdown(text) {
  if (!text) return "";
  try {
    return marked.parse(text, { breaks: true });
  } catch (_) {
    return escapeHtml(text).replace(/\n/g, "<br>");
  }
}

function renderTable(columns, rows) {
  if (!columns || columns.length === 0 || !rows || rows.length === 0) {
    return '<div class="text-sm text-slate-500 italic">No rows returned.</div>';
  }
  const head = columns.map(c => `<th>${escapeHtml(c)}</th>`).join("");
  const body = rows.map(r => {
    const tds = columns.map(c => `<td>${escapeHtml(r[c])}</td>`).join("");
    return `<tr>${tds}</tr>`;
  }).join("");
  return `<div class="table-wrap"><table class="data-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderSql(sql) {
  if (!sql) return "";
  return `
    <details class="mt-3">
      <summary class="text-xs text-slate-500 cursor-pointer hover:text-slate-700 font-medium">View SQL</summary>
      <pre class="sql-block mt-2">${escapeHtml(sql)}</pre>
    </details>`;
}

function renderFollowups(list) {
  if (!list || list.length === 0) return "";
  const chips = list.map(q =>
    `<button class="chip" data-followup="${escapeHtml(q)}">
       <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
       ${escapeHtml(q)}
     </button>`).join("");
  return `<div class="mt-4 flex flex-wrap gap-2">${chips}</div>`;
}

function renderSources(sources) {
  if (!sources || sources.length === 0) return "";
  const items = sources.map(s => {
    const name = s.title || s.name || s.source || (typeof s === "string" ? s : JSON.stringify(s));
    return `<li class="text-xs text-slate-500">${escapeHtml(name)}</li>`;
  }).join("");
  return `<div class="mt-3"><div class="text-[10px] uppercase tracking-wider text-slate-400 mb-1">Sources</div><ul class="space-y-0.5">${items}</ul></div>`;
}

function renderDoc(doc) {
  if (!doc) return "";
  const title = doc.title || "Generated document";
  const url = doc.url || "";
  return `
    <div class="mt-4 flex items-center gap-3 bg-brand-50 border border-brand-200 rounded-xl px-4 py-3">
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-brand-600"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
      <div class="flex-1">
        <div class="text-sm font-semibold text-brand-800">${escapeHtml(title)}</div>
        <div class="text-xs text-brand-600">Word document ready</div>
      </div>
      ${url ? `<a href="${escapeHtml(url)}" download class="bg-brand-600 hover:bg-brand-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg transition">Download</a>` : ""}
    </div>`;
}

/* ---- Chart rendering ---- */

let chartCounter = 0;
const pendingCharts = [];

function renderChart(spec, columns, rows) {
  if (!spec) return renderTable(columns, rows);

  // KPI cards
  if (spec.type === "kpi" && spec.kpis) {
    const row0 = rows[0] || {};
    const cards = spec.kpis.map(k => `
      <div class="kpi-card">
        <div class="label">${escapeHtml(k.label)}</div>
        <div class="value">${escapeHtml(row0[k.column] ?? "-")}</div>
      </div>
    `).join("");
    return `<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">${cards}</div>`;
  }

  // Chart.js canvas
  const id = `chart_${++chartCounter}_${Date.now()}`;
  const labels = rows.map(r => r[spec.x]);
  const yCols = Array.isArray(spec.y) ? spec.y : [spec.y];
  const palette = ["#3a5cfa", "#8eadff", "#1e32b4", "#5f83ff", "#bcd0ff", "#253fe0"];
  const datasets = yCols.map((col, i) => ({
    label: col,
    data: rows.map(r => r[col]),
    backgroundColor: spec.type === "pie" || spec.type === "doughnut" ? palette : palette[i % palette.length],
    borderColor: palette[i % palette.length],
    borderWidth: 2,
    tension: 0.3,
    fill: spec.type === "line" ? false : true,
  }));

  pendingCharts.push({ id, type: spec.type || "bar", labels, datasets, title: spec.title });
  return `
    ${spec.title ? `<h3 class="font-semibold text-slate-900 mb-3">${escapeHtml(spec.title)}</h3>` : ""}
    <div class="relative" style="height:340px"><canvas id="${id}"></canvas></div>`;
}

function flushPendingCharts() {
  while (pendingCharts.length) {
    const c = pendingCharts.shift();
    const el = document.getElementById(c.id);
    if (!el) continue;
    new Chart(el, {
      type: c.type,
      data: { labels: c.labels, datasets: c.datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: "bottom" } },
      },
    });
  }
}

/* ---- WebSocket URL builder ---- */

function buildWsUrl(path) {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}${path}`;
}

/* ---- Main chat component (Mitra, Visual, QAD-Zone) ---- */

function wsChat(wsPath, agentType) {
  return {
    input: "",
    loading: false,
    streaming: false,
    statusText: "",
    messages: [],
    currentText: "",
    currentHtml: "",
    currentSql: "",
    currentTable: null,
    currentChart: null,
    currentSources: null,
    currentFollowups: null,
    currentDoc: null,
    extraPayload: {},
    ws: null,

    init() {
      // Listen for follow-up chip clicks (event delegation)
      this.$el.addEventListener("click", (e) => {
        const chip = e.target.closest("[data-followup]");
        if (chip) this.send(chip.dataset.followup);
      });
    },

    send(preset) {
      const q = (preset || this.input || "").trim();
      if (!q || this.loading) return;
      this.input = "";
      this.messages.push({ role: "user", text: q });
      this.loading = true;
      this.streaming = false;
      this.statusText = "";
      this.currentText = "";
      this.currentHtml = "";
      this.currentSql = "";
      this.currentTable = null;
      this.currentChart = null;
      this.currentSources = null;
      this.currentFollowups = null;
      this.currentDoc = null;
      this.$nextTick(() => this.scrollBottom());

      const ws = new WebSocket(buildWsUrl(wsPath));
      this.ws = ws;

      ws.onopen = () => {
        const payload = { question: q, ...(this.extraPayload || {}) };
        ws.send(JSON.stringify(payload));
      };

      ws.onmessage = (evt) => {
        let frame;
        try { frame = JSON.parse(evt.data); } catch (_) { return; }
        this._handleFrame(frame);
      };

      ws.onerror = () => {
        this._finalize('<div class="text-red-600 text-sm">Connection error. Please try again.</div>');
      };

      ws.onclose = () => {
        if (this.loading) {
          this._finalize(this._buildFinalHtml());
        }
      };
    },

    _handleFrame(frame) {
      const { type, data } = frame;

      switch (type) {
        case "token":
          if (!this.streaming) this.streaming = true;
          this.currentText += data;
          this.currentHtml = renderMarkdown(this.currentText);
          this.$nextTick(() => this.scrollBottom());
          break;

        case "status":
          this.statusText = data;
          break;

        case "sql":
          this.currentSql = data;
          break;

        case "table":
          this.currentTable = data;
          break;

        case "chart":
          this.currentChart = data;
          break;

        case "sources":
          this.currentSources = data;
          break;

        case "followup":
          this.currentFollowups = data;
          break;

        case "doc":
          this.currentDoc = data;
          break;

        case "error":
          this._finalize(`<div class="text-red-600 text-sm">${escapeHtml(data)}</div>`);
          break;

        case "done":
          this._finalize(this._buildFinalHtml());
          break;
      }
    },

    _buildFinalHtml() {
      let html = "";

      // Streamed text
      if (this.currentText) {
        html += `<div class="prose-content">${renderMarkdown(this.currentText)}</div>`;
      }

      // Table or chart
      if (agentType === "visual" && this.currentChart) {
        html += renderChart(this.currentChart, this.currentTable?.columns, this.currentTable?.rows);
      } else if (this.currentTable) {
        const t = this.currentTable;
        if (t.row_count !== undefined) {
          html += `<div class="text-xs text-slate-500 mb-2">${t.row_count} row${t.row_count === 1 ? "" : "s"}</div>`;
        }
        html += renderTable(t.columns, t.rows);
      }

      // SQL
      html += renderSql(this.currentSql);

      // Doc download
      html += renderDoc(this.currentDoc);

      // Sources
      html += renderSources(this.currentSources);

      // Follow-ups
      html += renderFollowups(this.currentFollowups);

      return html || '<div class="text-slate-500 text-sm italic">No response received.</div>';
    },

    _finalize(html) {
      this.messages.push({ role: "assistant", html });
      this.loading = false;
      this.streaming = false;
      this.statusText = "";
      if (this.ws) { try { this.ws.close(); } catch (_) {} this.ws = null; }
      this.$nextTick(() => {
        this.scrollBottom();
        if (window.lucide) lucide.createIcons();
        flushPendingCharts();
      });
    },

    scrollBottom() {
      const el = this.$refs.msgs;
      if (el) el.scrollTop = el.scrollHeight;
    },
  };
}

/* ---- Apex floating widget (WebSocket) ---- */

function apexWidget() {
  return {
    open: false,
    needsDomain: true,
    selectedDomains: [],
    input: "",
    loading: false,
    streaming: false,
    messages: [],
    currentText: "",
    currentHtml: "",
    currentSources: null,
    currentFollowups: null,
    ws: null,

    async init() {
      try {
        const res = await fetch("/agents/apex/context", { credentials: "same-origin" });
        if (res.ok) {
          const data = await res.json();
          if (data.domains && data.domains.length) {
            this.needsDomain = false;
            this.selectedDomains = data.domains;
          }
        }
      } catch (_) { /* ignore */ }
    },

    toggle() {
      this.open = !this.open;
      if (this.open) this.$nextTick(() => window.lucide && lucide.createIcons());
    },

    confirmDomains() {
      if (this.selectedDomains.length === 0) return;
      this.needsDomain = false;
    },

    send() {
      const q = (this.input || "").trim();
      if (!q || this.loading) return;
      this.input = "";
      this.messages.push({ role: "user", text: q });
      this.loading = true;
      this.streaming = false;
      this.currentText = "";
      this.currentHtml = "";
      this.currentSources = null;
      this.currentFollowups = null;

      const ws = new WebSocket(buildWsUrl("/agents/apex/ws"));
      this.ws = ws;

      ws.onopen = () => {
        ws.send(JSON.stringify({ question: q, domains: this.selectedDomains }));
      };

      ws.onmessage = (evt) => {
        let frame;
        try { frame = JSON.parse(evt.data); } catch (_) { return; }

        switch (frame.type) {
          case "token":
            if (!this.streaming) this.streaming = true;
            this.currentText += frame.data;
            this.currentHtml = renderMarkdown(this.currentText);
            this.$nextTick(() => {
              const el = this.$refs.msgs;
              if (el) el.scrollTop = el.scrollHeight;
            });
            break;
          case "sources":
            this.currentSources = frame.data;
            break;
          case "followup":
            this.currentFollowups = frame.data;
            break;
          case "error":
            this._finish(`<span class="text-red-600">${escapeHtml(frame.data)}</span>`);
            break;
          case "done":
            this._finish(this._buildHtml());
            break;
        }
      };

      ws.onerror = () => {
        this._finish('<span class="text-red-600">Connection error.</span>');
      };

      ws.onclose = () => {
        if (this.loading) this._finish(this._buildHtml());
      };
    },

    _buildHtml() {
      let html = this.currentText ? renderMarkdown(this.currentText) : "";
      html += renderSources(this.currentSources);
      html += renderFollowups(this.currentFollowups);
      return html || "(no response)";
    },

    _finish(html) {
      this.messages.push({ role: "assistant", html });
      this.loading = false;
      this.streaming = false;
      if (this.ws) { try { this.ws.close(); } catch (_) {} this.ws = null; }
      this.$nextTick(() => {
        const el = this.$refs.msgs;
        if (el) el.scrollTop = el.scrollHeight;
      });
    },
  };
}

// Expose to Alpine
window.wsChat = wsChat;
window.apexWidget = apexWidget;
