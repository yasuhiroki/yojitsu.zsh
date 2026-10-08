// templates/app.js - Chart.js rendering and UI logic for yojitsu dashboard

document.addEventListener('DOMContentLoaded', () => {
  initDashboard();
});

function loadBenchmarkData() {
  if (window.BENCHMARK_DATA && Array.isArray(window.BENCHMARK_DATA)) {
    return window.BENCHMARK_DATA;
  }
  const scriptTag = document.getElementById('benchmark-data');
  if (scriptTag && scriptTag.textContent.trim()) {
    try {
      const parsed = JSON.parse(scriptTag.textContent.trim());
      return Array.isArray(parsed) ? parsed : [parsed];
    } catch (e) {
      console.error('Failed to parse #benchmark-data JSON:', e);
    }
  }
  return [];
}

function initDashboard() {
  const data = loadBenchmarkData();
  if (!data || data.length === 0) {
    console.warn('No benchmark data loaded.');
    return;
  }

  renderCharts(data);
  renderTable(data);
}

function renderCharts(results) {
  const labels = results.map(r => {
    const parts = [r.benchmark?.title || r.benchmark?.id || 'Untitled'];
    const extras = [];
    if (r.metadata?.agent) extras.push(r.metadata.agent);
    if (r.benchmark?.model) extras.push(r.benchmark.model);
    if (r.benchmark?.effort) extras.push(`effort:${r.benchmark.effort}`);
    if (extras.length > 0) {
      return `${parts[0]} (${extras.join(', ')})`;
    }
    return parts[0];
  });

  const thoughtTokens = results.map(r => r.tokens?.output?.breakdown?.thought_tokens ?? r.tokens?.breakdown?.thought_tokens ?? 0);
  const responseTokens = results.map(r => r.tokens?.output?.breakdown?.response_tokens ?? r.tokens?.breakdown?.response_tokens ?? 0);
  const cmdTokens = results.map(r => r.tokens?.input?.breakdown?.cmd_tokens ?? r.tokens?.breakdown?.cmd_tokens ?? 0);
  const baseCtxTokens = results.map(r => r.tokens?.input?.breakdown?.base_context_tokens ?? r.tokens?.breakdown?.base_context_tokens ?? 0);
  const promptTokens = results.map(r => r.tokens?.input?.breakdown?.prompt_tokens ?? r.tokens?.breakdown?.prompt_tokens ?? 0);
  const times = results.map(r => r.benchmark?.elapsed_sec || 0);

  // 1. Stacked Token Breakdown Chart
  const ctxToken = document.getElementById('tokenBreakdownChart');
  if (ctxToken) {
    new Chart(ctxToken, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Thinking (CoT)',
            data: thoughtTokens,
            backgroundColor: '#a855f7',
            stack: 'Stack 0',
            borderRadius: 4
          },
          {
            label: 'Response',
            data: responseTokens,
            backgroundColor: '#ec4899',
            stack: 'Stack 0',
            borderRadius: 4
          },
          {
            label: 'Command Output',
            data: cmdTokens,
            backgroundColor: '#3b82f6',
            stack: 'Stack 0',
            borderRadius: 4
          },
          {
            label: 'Base Context',
            data: baseCtxTokens,
            backgroundColor: '#1e40af',
            stack: 'Stack 0',
            borderRadius: 4
          },
          {
            label: 'Prompt',
            data: promptTokens,
            backgroundColor: '#38bdf8',
            stack: 'Stack 0',
            borderRadius: 4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'top', labels: { color: '#cbd5e1', font: { size: 12 } } },
          tooltip: { mode: 'index', intersect: false }
        },
        scales: {
          x: { stacked: true, grid: { color: '#1f2937' }, ticks: { color: '#94a3b8' } },
          y: { stacked: true, beginAtZero: true, grid: { color: '#1f2937' }, ticks: { color: '#94a3b8' } }
        }
      }
    });
  }

  // 2. Top Command Output Tokens Chart
  const topCmds = [];
  results.forEach(r => {
    const runId = r.benchmark?.id || 'P';
    (r.tools || []).forEach(t => {
      const shortCmd = (t.command || '').substring(0, 40);
      const stepTok = t.tokens?.input_tokens ?? t.consumed_tokens ?? 0;
      if (shortCmd && stepTok > 0) {
        topCmds.push({
          label: `[${runId}] ${shortCmd}`,
          tokens: stepTok
        });
      }
    });
  });
  topCmds.sort((a, b) => b.tokens - a.tokens);
  const top10 = topCmds.slice(0, 10);

  const ctxCmd = document.getElementById('cmdTokenChart');
  if (ctxCmd) {
    new Chart(ctxCmd, {
      type: 'bar',
      data: {
        labels: top10.map(c => c.label),
        datasets: [{
          label: 'Context Tokens',
          data: top10.map(c => c.tokens),
          backgroundColor: '#3b82f6',
          borderRadius: 4
        }]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { beginAtZero: true, grid: { color: '#1f2937' }, ticks: { color: '#94a3b8' } },
          y: { grid: { display: false }, ticks: { color: '#cbd5e1', font: { size: 11 } } }
        }
      }
    });
  }

  // 3. Execution Time Chart
  const ctxTime = document.getElementById('timeChart');
  if (ctxTime) {
    new Chart(ctxTime, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Elapsed Time (s)',
          data: times,
          backgroundColor: '#38bdf8',
          borderRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          y: { beginAtZero: true, grid: { color: '#1f2937' }, ticks: { color: '#94a3b8' } },
          x: { grid: { display: false }, ticks: { display: false } }
        }
      }
    });
  }
}

function renderTable(results) {
  const tbody = document.getElementById('benchmarkTableBody');
  if (!tbody) return;

  tbody.innerHTML = '';

  results.forEach((r, idx) => {
    const rowId = `row_${idx}`;
    const bm = r.benchmark || {};
    const tokens = r.tokens || {};
    const inTokens = tokens.input || {};
    const inBk = inTokens.breakdown || tokens.breakdown || {};
    const outTokens = tokens.output || {};
    const outBk = outTokens.breakdown || tokens.breakdown || {};
    const tools = r.tools || [];
    const meta = r.metadata || {};

    const cmdTok = inBk.cmd_tokens || 0;
    const baseTok = inBk.base_context_tokens || 0;
    const thTok = outBk.thought_tokens || 0;
    const respTok = outBk.response_tokens || 0;
    const totalIn = inTokens.input_tokens ?? tokens.input_tokens ?? 0;
    const totalOut = outTokens.output_tokens ?? tokens.output_tokens ?? 0;
    const cacheTok = inTokens.cache_read_tokens ?? tokens.cache_read_tokens ?? 0;

    let cmdRows = '';
    if (tools.length > 0) {
      cmdRows = tools.map((t, cIdx) => {
        const tTok = t.tokens || {};
        const stepIn = tTok.input_tokens ?? t.input_tokens ?? t.consumed_tokens ?? 0;
        const stepOut = tTok.output_tokens ?? t.output_tokens ?? 0;
        const stepCache = tTok.cache_read_tokens ?? t.cache_read_tokens ?? 0;
        return `
        <tr>
          <td><code>#${cIdx + 1}</code></td>
          <td><strong style="color: #38bdf8;">${escapeHtml(t.command || t.tool || '')}</strong></td>
          <td><span style="color: #60a5fa; font-weight: 600;">${stepIn.toLocaleString()}</span></td>
          <td><span style="color: #f472b6; font-weight: 600;">${stepOut.toLocaleString()}</span></td>
          <td><span style="color: #c084fc; font-weight: 600;">${stepCache.toLocaleString()}</span></td>
          <td><pre>${escapeHtml(t.output_preview || '')}</pre></td>
        </tr>
      `;
      }).join('');
    }

    const cmdTableHtml = tools.length > 0 ? `
      <table class="cmd-table">
        <thead>
          <tr>
            <th style="width: 48px;">Step</th>
            <th style="width: 30%;">Command / Tool</th>
            <th style="width: 12%;">In Tokens</th>
            <th style="width: 10%;">Out Tokens</th>
            <th style="width: 12%;">Cache Read</th>
            <th style="width: 36%;">Preview</th>
          </tr>
        </thead>
        <tbody>${cmdRows}</tbody>
      </table>
    ` : '<div style="color: #64748b; font-size: 12px; margin-top: 6px;">No tool commands executed</div>';

    const thinkingHtml = r.thinking ? `
      <div style="margin-top: 12px;">
        <strong style="color: #c084fc; font-size: 12px;">Thinking Process (CoT):</strong>
        <pre class="content-block">${escapeHtml(r.thinking)}</pre>
      </div>
    ` : '';

    const trParent = document.createElement('tr');
    trParent.id = `parent-${rowId}`;
    trParent.className = 'parent-row';
    trParent.onclick = () => toggleRow(rowId);

    trParent.innerHTML = `
      <td style="text-align: center;"><span id="icon-${rowId}" class="toggle-icon">+</span></td>
      <td><strong>${escapeHtml(bm.title || bm.id || 'Untitled')}</strong><br><small style="color: #64748b;">${escapeHtml(bm.id || '')} (${escapeHtml(meta.agent || 'unknown')})</small></td>
      <td><code class="tag">${escapeHtml(bm.effort || 'default')}</code></td>
      <td>${bm.elapsed_sec || 0} s</td>
      <td><strong style="color: #38bdf8; font-size: 14px;">${(tokens.total_tokens || 0).toLocaleString()}</strong></td>
      <td>
        ${totalIn.toLocaleString()}${cacheTok > 0 ? ` <small style="color: #a78bfa;">(cache:${cacheTok.toLocaleString()})</small>` : ''}<br>
        <small style="color: #60a5fa;">Cmd:${cmdTok.toLocaleString()}</small> <small style="color: #64748b;">Base:${baseTok.toLocaleString()}</small>
      </td>
      <td>
        ${totalOut.toLocaleString()}<br>
        <small style="color: #c084fc;">Think:${thTok.toLocaleString()}</small> <small style="color: #f472b6;">Resp:${respTok.toLocaleString()}</small>
      </td>
      <td><span class="pill pill-tool">${tools.length} cmds</span></td>
    `;

    const trDetail = document.createElement('tr');
    trDetail.id = `detail-${rowId}`;
    trDetail.className = 'detail-row';
    trDetail.innerHTML = `
      <td colspan="8" class="detail-container">
        <div style="display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap;">
          ${cacheTok > 0 ? `<span class="pill" style="background: rgba(167, 139, 250, 0.15); color: #c084fc; border: 1px solid rgba(167, 139, 250, 0.3);">Cache Read: ${cacheTok.toLocaleString()} tokens</span>` : ''}
          <span class="pill pill-cmd">Command Output: ~${cmdTok.toLocaleString()} tokens</span>
          <span class="pill pill-thought">Thinking: ${thTok.toLocaleString()} tokens</span>
          <span class="pill pill-resp">Response: ${respTok.toLocaleString()} tokens</span>
        </div>
        <div style="margin-bottom: 12px;">
          <strong style="color: #94a3b8; font-size: 12px;">Submitted Prompt:</strong>
          <pre class="content-block" style="max-height: 80px;">${escapeHtml(bm.prompt || '')}</pre>
        </div>
        <div style="margin-bottom: 12px;">
          <strong style="color: #38bdf8; font-size: 12px;">Executed Commands & Token Consumption:</strong>
          ${cmdTableHtml}
        </div>
        ${thinkingHtml}
        <div style="margin-top: 12px;">
          <strong style="color: #34d399; font-size: 12px;">Agent Final Response:</strong>
          <pre class="content-block">${escapeHtml(r.response || '')}</pre>
        </div>
      </td>
    `;

    tbody.appendChild(trParent);
    tbody.appendChild(trDetail);
  });
}

function toggleRow(id) {
  const parentRow = document.getElementById('parent-' + id);
  const detailRow = document.getElementById('detail-' + id);
  const icon = document.getElementById('icon-' + id);
  if (!detailRow || !parentRow || !icon) return;

  if (detailRow.classList.contains('open')) {
    detailRow.classList.remove('open');
    parentRow.classList.remove('expanded');
    icon.innerText = '+';
  } else {
    detailRow.classList.add('open');
    parentRow.classList.add('expanded');
    icon.innerText = '-';
  }
}

function toggleAllRows(expand) {
  const detailRows = document.querySelectorAll('tr.detail-row');
  const parentRows = document.querySelectorAll('tr.parent-row');
  const icons = document.querySelectorAll('.toggle-icon');

  detailRows.forEach(row => {
    if (expand) row.classList.add('open');
    else row.classList.remove('open');
  });
  parentRows.forEach(row => {
    if (expand) row.classList.add('expanded');
    else row.classList.remove('expanded');
  });
  icons.forEach(icon => {
    icon.innerText = expand ? '-' : '+';
  });
}

function switchView(viewName, btnEl) {
  const views = ['overview', 'details'];
  views.forEach(v => {
    const el = document.getElementById('view-' + v);
    if (el) {
      if (viewName === 'all' || v === viewName) {
        el.style.display = 'block';
      } else {
        el.style.display = 'none';
      }
    }
  });

  const buttons = document.querySelectorAll('.tab-btn');
  buttons.forEach(btn => btn.classList.remove('active'));
  if (btnEl) btnEl.classList.add('active');
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
