/* Mitra Central — front-end logic.
 *
 * Each agent gets its own Alpine component factory so rendering can diverge
 * without any of them stepping on each other. All of them share the same
 * `postAsk` helper and the same {role, text|html} message format.
 */

async function postAsk(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    credentials: "same-origin",
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.json();
}

function escapeHtml(s) {
  if (s === null || s === undefined) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderTable(columns, rows) {
  if (!columns || columns.length === 0 || !rows || rows.length === 0) {
    return `<div class="text-sm text-slate-500 italic">No rows returned.</div>`;
  }
  const head = columns.map(c => `<th>${escapeHtml(c)}</th>`).join("");
  const body = rows.map(r => {
    const tds = columns.map(c => `<td>${escapeHtml(r[c])}</td>`).join("");
    return `<tr>${tds}</tr>`;
  }).join("");
  return `<div class="table-wrap"><table class="data-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderFollowups(list, sendExpr = "send") {
  if (!list || list.length === 0) return "";
  const chips = list.map(q =>
    `<button class="chip" onclick="window.__mitraSend && window.__mitraSend(${JSON.stringify(q)})">
       <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
       ${escapeHtml(q)}
     </button>`).join("");
  return `<div class="mt-4 flex flex-wrap gap-2">${chips}</div>`;
}

function renderSql(sql, reasoning) {
  if (!sql) return "";
  const reasoningBlock = reasoning
    ? `<details class="mt-3"><summary class="text-xs text-slate-500 cursor-pointer hover:text-slate-700">Reasoning</summary>
         <div class="mt-2 text-sm text-slate-600 whitespace-pre-wrap">${escapeHtml(reasoning)}</div>
       </details>`
    : "";
  return `
    <details class="mt-3">
      <summary class="text-xs text-slate-500 cursor-pointer hover:text-slate-700 font-medium">View SQL</summary>
      <pre class="sql-block mt-2">${escapeHtml(sql)}</pre>
    </details>
    ${reasoningBlock}
  `;
}

/* ---------- Base chat factory ---------- */
function baseChat(url, renderer) {
  return {
    url,
    input: "",
    loading: false,
    messages: [],

    init() {
      // expose a global hook so follow-up chips (rendered as HTML) can call send()
      window.__mitraSend = (q) => this.send(q);
    },

    async send(preset) {
      const q = (preset || this.input || "").trim();
      if (!q || this.loading) return;
      this.input = "";
      this.messages.push({ role: "user", text: q });
      this.loading = true;
      this.$nextTick(() => this.scrollBottom());
      try {
        const data = await postAsk(this.url, { question: q });
        const html = renderer(data);
        this.messages.push({ role: "assistant", html, data });
      } catch (e) {
        this.messages.push({
          role: "assistant",
          html: `<div class="text-red-600 text-sm">Error: ${escapeHtml(e.message)}</div>`,
        });
      } finally {
        this.loading = false;
        this.$nextTick(() => {
          this.scrollBottom();
          if (window.lucide) lucide.createIcons();
          this.afterRender && this.afterRender();
        });
      }
    },

    scrollBottom() {
      const el = this.$refs.msgs;
      if (el) el.scrollTop = el.scrollHeight;
    },
  };
}

/* ---------- Mitra — text-to-SQL ---------- */
function mitraChat(url) {
  const render = (d) => {
    if (d.error) {
      return `<div class="text-red-600 text-sm">${escapeHtml(d.error)}</div>${renderSql(d.sql, d.reasoning)}`;
    }
    const answer = d.answer
      ? `<div class="text-slate-800 mb-3 whitespace-pre-wrap">${escapeHtml(d.answer)}</div>`
      : "";
    const meta = `<div class="text-xs text-slate-500 mb-2">${d.row_count} row${d.row_count === 1 ? "" : "s"}</div>`;
    const table = renderTable(d.columns, d.rows);
    return `${answer}${meta}${table}${renderSql(d.sql, d.reasoning)}${renderFollowups(d.followup_questions)}`;
  };
  return baseChat(url, render);
}

/* ---------- Visual Intelligence — charts ---------- */
function visualChat(url) {
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

    // Chart.js
    const id = `chart_${++chartCounter}_${Date.now()}`;
    const labels = rows.map(r => r[spec.x]);
    const yCols = Array.isArray(spec.y) ? spec.y : [spec.y];
    const palette = ["#3a5cfa", "#8eadff", "#1e32b4", "#5f83ff", "#bcd0ff", "#253fe0"];
    const datasets = yCols.map((col, i) => ({
      label: col,
      data: rows.map(r => r[col]),
      backgroundColor: spec.type === "pie" || spec.type === "doughnut"
        ? palette
        : palette[i % palette.length],
      borderColor: palette[i % palette.length],
      borderWidth: 2,
      tension: 0.3,
      fill: spec.type === "line" ? false : true,
    }));

    pendingCharts.push({ id, type: spec.type || "bar", labels, datasets, title: spec.title });
    return `
      ${spec.title ? `<h3 class="font-semibold text-slate-900 mb-3">${escapeHtml(spec.title)}</h3>` : ""}
      <div class="relative" style="height:340px"><canvas id="${id}"></canvas></div>
    `;
  }

  const render = (d) => {
    if (d.error) return `<div class="text-red-600 text-sm">${escapeHtml(d.error)}</div>${renderSql(d.sql, d.reasoning)}`;
    const chart = renderChart(d.chart, d.columns, d.rows);
    return `${chart}${renderSql(d.sql, d.reasoning)}${renderFollowups(d.followup_questions)}`;
  };

  const chat = baseChat(url, render);
  chat.afterRender = function () {
    while (pendingCharts.length) {
      const c = pendingCharts.shift();
      const el = document.getElementById(c.id);
      if (!el) continue;
      // eslint-disable-next-line no-new, no-undef
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
  };
  return chat;
}

/* ---------- QAD-Zone — RAG + doc generation ---------- */
function qadzoneChat(url) {
  const render = (d) => {
    if (d.error) return `<div class="text-red-600 text-sm">${escapeHtml(d.error)}</div>`;
    let out = "";
    if (d.answer) {
      out += `<div class="text-slate-800 whitespace-pre-wrap">${escapeHtml(d.answer)}</div>`;
    }
    if (d.document) {
      out += `
        <div class="mt-4 border border-slate-200 rounded-xl overflow-hidden">
          <div class="bg-slate-50 px-4 py-2 flex items-center justify-between">
            <div class="font-semibold text-slate-800 text-sm">${escapeHtml(d.document.title || "Generated document")}</div>
            <span class="text-[10px] uppercase tracking-wider text-slate-500">${escapeHtml(d.document.format || "text")}</span>
          </div>
          <pre class="p-4 text-xs whitespace-pre-wrap text-slate-700 max-h-96 overflow-auto">${escapeHtml(d.document.content || "")}</pre>
        </div>
      `;
    }
    if (d.sources && d.sources.length) {
      const items = d.sources.map(s => `<li class="text-xs text-slate-500">${escapeHtml(s.title || s.name || s)}</li>`).join("");
      out += `<div class="mt-3"><div class="text-[10px] uppercase tracking-wider text-slate-400 mb-1">Sources</div><ul class="space-y-0.5">${items}</ul></div>`;
    }
    out += renderFollowups(d.followup_questions);
    return out;
  };
  return baseChat(url, render);
}

/* ---------- Apex floating widget ---------- */
function apexWidget() {
  return {
    open: false,
    needsDomain: true,
    selectedDomains: [],
    input: "",
    loading: false,
    messages: [],

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

    async send() {
      const q = (this.input || "").trim();
      if (!q || this.loading) return;
      this.input = "";
      this.messages.push({ role: "user", text: q });
      this.loading = true;
      try {
        const data = await postAsk("/agents/apex/ask", {
          question: q,
          domains: this.selectedDomains,
        });
        this.messages.push({
          role: "assistant",
          text: data.error ? `Error: ${data.error}` : (data.answer || "(no answer)"),
        });
      } catch (e) {
        this.messages.push({ role: "assistant", text: `Error: ${e.message}` });
      } finally {
        this.loading = false;
        this.$nextTick(() => {
          const el = this.$refs.msgs;
          if (el) el.scrollTop = el.scrollHeight;
        });
      }
    },
  };
}

// Expose to Alpine globally.
window.mitraChat = mitraChat;
window.visualChat = visualChat;
window.qadzoneChat = qadzoneChat;
window.apexWidget = apexWidget;
