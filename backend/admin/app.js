const API = `${window.location.origin}/v1`;
/** Admin workflow — forward only */
const NEXT_STATUS = {
  submitted: 'received',
  received: 'underInvestigation',
  underReview: 'underInvestigation',
  underInvestigation: 'siteVisited',
  inProgress: 'siteVisited',
  siteVisited: 'awaitingAction',
  awaitingAction: 'resolved',
  resolved: 'closed',
};
const STATUS_LABELS = {
  submitted: 'Submitted',
  received: 'Received',
  underReview: 'Received',
  underInvestigation: 'Under Investigation',
  inProgress: 'Under Investigation',
  siteVisited: 'Site Visited',
  awaitingAction: 'Awaiting Action',
  resolved: 'Resolved',
  closed: 'Closed',
};
const ALLOWED_ROLES = [
  'super_admin', 'municipal_admin', 'agency_admin',
  'environmental_officer', 'emergency_officer', 'police_support', 'researcher',
];
const PLATFORM_OWNER = 'Tarkwa-Nsuaem Municipal Assembly';
let officersCache = [];

let token = localStorage.getItem('ecowatch_token');
let user = JSON.parse(localStorage.getItem('ecowatch_user') || 'null');
let categoryLabels = {};
let categoryMeta = {};
let map;
let mapLayer;
let mapTileLayer;
let reportsRefreshTimer;
let analyticsCharts = {};
let lastAnalyticsData = null;
const THEME_KEY = 'ecowatch_admin_theme';

const $ = (id) => document.getElementById(id);

function isDarkTheme() {
  return document.documentElement.dataset.theme === 'dark';
}

function themeToggleLabel() {
  return isDarkTheme() ? 'Light mode' : 'Dark mode';
}

function chartThemeOptions() {
  const dark = isDarkTheme();
  const grid = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
  const tick = dark ? '#a8b5a8' : '#666';
  return {
    color: dark ? '#e8f0e8' : '#1b2e1b',
    scales: {
      x: {
        ticks: { color: tick },
        grid: { color: grid },
      },
      y: {
        ticks: { color: tick, precision: 0 },
        grid: { color: grid },
        beginAtZero: true,
      },
    },
    plugins: {
      legend: {
        labels: { color: tick },
      },
    },
  };
}

function applyTheme(theme) {
  const next = theme === 'dark' ? 'dark' : 'light';
  document.documentElement.dataset.theme = next;
  localStorage.setItem(THEME_KEY, next);

  ['theme-toggle', 'theme-toggle-login'].forEach((id) => {
    const btn = $(id);
    if (btn) {
      btn.textContent = themeToggleLabel();
      btn.setAttribute('aria-label', themeToggleLabel());
    }
  });

  if (mapTileLayer && map) {
    map.removeLayer(mapTileLayer);
    mapTileLayer = createMapTileLayer();
    mapTileLayer.addTo(map);
  }

  if (lastAnalyticsData) {
    renderAnalyticsCharts(lastAnalyticsData);
  }
}

function initTheme() {
  const saved = localStorage.getItem(THEME_KEY);
  applyTheme(saved === 'light' ? 'light' : 'dark');
}

function toggleTheme() {
  applyTheme(isDarkTheme() ? 'light' : 'dark');
}

function createMapTileLayer() {
  if (isDarkTheme()) {
    return L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '© OpenStreetMap © CARTO',
      subdomains: 'abcd',
      maxZoom: 20,
    });
  }
  return L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap',
  });
}

initTheme();
$('theme-toggle')?.addEventListener('click', toggleTheme);
$('theme-toggle-login')?.addEventListener('click', toggleTheme);

function isSuperAdmin() { return user?.role === 'super_admin'; }
function isMunicipalAdmin() { return user?.role === 'municipal_admin'; }
function isAgencyAdmin() { return user?.role === 'agency_admin'; }
function isOfficer() { return user?.role === 'environmental_officer'; }
function isEmergencyOfficer() { return user?.role === 'emergency_officer'; }
function isPolice() { return user?.role === 'police_support'; }
function isResearcher() { return user?.role === 'researcher'; }
function isMunicipalScope() { return isSuperAdmin() || isMunicipalAdmin(); }
function isReadOnlyAnalyst() { return isResearcher(); }
function isAgencyWide() { return isAgencyAdmin(); }

function agencyDisplayName() {
  if (user?.agencyName) return user.agencyName;
  const meta = categoryMeta[user?.assignedCategory] || {};
  return meta.agency || meta.agencyShort || user?.displayName || 'Agency';
}

/** Field officers update investigation actions after assignment — not agency/municipal admins. */
function canUpdateReportStatus() {
  return isOfficer() || isEmergencyOfficer() || isPolice();
}

function canAddInvestigationNotes() {
  return canUpdateReportStatus();
}

function canAssignOfficers() {
  return isSuperAdmin() || isMunicipalAdmin() || isAgencyAdmin();
}

/** Agency leadership approves closure after officers complete investigation. */
function canCloseReports() {
  return isSuperAdmin() || isMunicipalAdmin() || isAgencyAdmin();
}

function canEscalate() {
  return isSuperAdmin() || isMunicipalAdmin() || isAgencyAdmin();
}

function canManageAnnouncements() {
  return isSuperAdmin() || isMunicipalAdmin();
}

function canManageUsers() {
  return isSuperAdmin() || isMunicipalAdmin() || isAgencyAdmin();
}

function canViewAudit() { return isSuperAdmin(); }
function canViewSettings() { return isSuperAdmin(); }
function canViewPerformance() { return !isResearcher() && !isOfficer() && !isEmergencyOfficer() && !isPolice(); }

function roleLabel() {
  const labels = {
    super_admin: 'Super Administrator',
    municipal_admin: 'Municipal Administrator',
    agency_admin: 'Agency Administrator',
    environmental_officer: 'Environmental Officer',
    emergency_officer: 'Emergency Response Officer',
    police_support: 'Police Support',
    researcher: 'Researcher',
  };
  return labels[user?.role] || user?.role || '';
}

function normalizeStatus(status) {
  if (status === 'underReview' || status === 'submitted') return 'received';
  if (status === 'inProgress') return 'underInvestigation';
  return status;
}

function authHeaders() {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

async function api(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: { ...authHeaders(), ...(options.headers || {}) },
  });
  if (res.status === 401) {
    logout();
    throw new Error('Session expired');
  }
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(data?.error || res.statusText);
  return data;
}

async function loadCategoryLabels() {
  const categories = await fetch(`${API}/public/categories`).then((r) => r.json());
  categoryLabels = Object.fromEntries(categories.map((c) => [c.key, c.label]));
  categoryMeta = Object.fromEntries(categories.map((c) => [c.key, c]));
}

function categoryLabel(key) {
  return categoryLabels[key] || key || '—';
}

/** Agencies responsible for an incident category (department mandate). */
function agenciesForCategory(categoryKey) {
  const meta = categoryMeta[categoryKey] || {};
  if (Array.isArray(meta.multiAgency) && meta.multiAgency.length) {
    return meta.multiAgency;
  }
  return meta.agencyKey ? [meta.agencyKey] : [];
}

/**
 * Officers in the department(s) that own this report.
 * Agency staff only see officers from their own agency.
 */
function officersForReport(report) {
  let agencyKeys = agenciesForCategory(report.category);
  if (report.needsPolice && !agencyKeys.includes('police')) {
    agencyKeys = [...agencyKeys, 'police'];
  }

  // Agency admin: only their department
  if (user?.assignedAgency && !isMunicipalScope()) {
    agencyKeys = agencyKeys.includes(user.assignedAgency)
      ? [user.assignedAgency]
      : [user.assignedAgency];
  }

  const assignableRoles = ['environmental_officer', 'emergency_officer', 'police_support'];
  return officersCache.filter(
    (o) => assignableRoles.includes(o.role) && agencyKeys.includes(o.assignedAgency),
  );
}

function show(view) {
  $('login-view').classList.toggle('hidden', view !== 'login');
  $('app-view').classList.toggle('hidden', view !== 'app');
}

function logout() {
  token = null;
  user = null;
  localStorage.removeItem('ecowatch_token');
  localStorage.removeItem('ecowatch_user');
  show('login');
}

function applyRoleUI() {
  const agencyScoped = isAgencyWide() || isOfficer() || isEmergencyOfficer() || isPolice();
  const municipal = isMunicipalScope();
  const readOnly = isReadOnlyAnalyst();

  document.querySelectorAll('[data-agency-hide]').forEach((el) => {
    el.classList.toggle('hidden', agencyScoped && !municipal);
  });

  $('export-btn')?.classList.toggle('hidden', isOfficer() || isEmergencyOfficer() || isPolice());

  $('app-header').classList.toggle('officer-header', agencyScoped || municipal);
  $('app-header').classList.toggle('municipal-header', municipal);

  const ownerNote = $('platform-owner-note');
  if (ownerNote) {
    ownerNote.textContent = `Owned by ${PLATFORM_OWNER} · Participating agencies manage incidents in their mandate`;
  }

  if (isSuperAdmin()) {
    $('header-title').textContent = `${PLATFORM_OWNER} — Super Administrator`;
    $('tab-btn-reports').textContent = 'All Incidents';
  } else if (isMunicipalAdmin()) {
    $('header-title').textContent = `${PLATFORM_OWNER} — Municipal Administrator`;
    $('tab-btn-reports').textContent = 'All Incidents';
  } else if (isOfficer()) {
    $('header-title').textContent = `${agencyDisplayName()} — Field Officer`;
    $('tab-btn-reports').textContent = 'My Cases';
  } else if (isEmergencyOfficer()) {
    $('header-title').textContent = `${agencyDisplayName()} — Emergency Response`;
    $('tab-btn-reports').textContent = 'Emergency Incidents';
  } else if (isPolice()) {
    $('header-title').textContent = 'Ghana Police Service — Support';
    $('tab-btn-reports').textContent = 'Criminal Support Cases';
  } else if (isAgencyAdmin()) {
    $('header-title').textContent = agencyDisplayName();
    $('tab-btn-reports').textContent = 'Agency Incidents';
  } else {
    $('header-title').textContent = 'EcoWatch Research Portal';
    $('tab-btn-reports').textContent = 'Anonymized Incidents';
  }

  $('map-legend').textContent = readOnly
    ? 'Anonymized research map (approximate locations only).'
    : municipal
      ? 'Municipality-wide map. Solid = current hotspots; dashed = predicted.'
      : `Incidents in your scope (${agencyDisplayName()}).`;

  document.querySelectorAll('.col-actions').forEach((el) => el.classList.toggle('hidden', readOnly));
  document.querySelectorAll('.col-token').forEach((el) => el.classList.toggle('hidden', readOnly));
  document.querySelectorAll('.col-evidence').forEach((el) => el.classList.toggle('hidden', readOnly));
  document.querySelectorAll('.col-description').forEach((el) => el.classList.toggle('hidden', readOnly));

  $('tab-btn-performance')?.classList.toggle('hidden', !canViewPerformance());
  $('tab-btn-announcements')?.classList.toggle('hidden', !canManageAnnouncements());
  $('tab-btn-users')?.classList.toggle('hidden', !canManageUsers());
  $('tab-btn-audit')?.classList.toggle('hidden', !canViewAudit());
  $('tab-btn-settings')?.classList.toggle('hidden', !canViewSettings());

  $('user-label').textContent = user
    ? ` — ${agencyScoped ? agencyDisplayName() : user.displayName} · ${roleLabel()}`
    : '';
}

async function enterDashboard() {
  await loadCategoryLabels();
  applyRoleUI();
  show('app');
  activateTab('reports');
  await loadReports();
}

const passwordInput = $('password');
const passwordToggle = $('password-toggle');
if (passwordToggle && passwordInput) {
  passwordToggle.addEventListener('click', () => {
    const reveal = passwordInput.type === 'password';
    passwordInput.type = reveal ? 'text' : 'password';
    passwordToggle.textContent = reveal ? 'Hide' : 'Show';
    passwordToggle.setAttribute('aria-label', reveal ? 'Hide password' : 'Show password');
  });
}

$('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('login-error').classList.add('hidden');
  try {
    const res = await fetch(`${API}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: $('email').value.trim(),
        password: $('password').value,
      }),
    });
    const text = await res.text();
    let data = {};
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      throw new Error('Invalid server response. Check that PostgreSQL is running.');
    }
    if (!res.ok) throw new Error(data.error || 'Login failed');

    if (!ALLOWED_ROLES.includes(data.user.role)) {
      throw new Error('Official admin credentials required');
    }

    token = data.token;
    user = data.user;
    localStorage.setItem('ecowatch_token', token);
    localStorage.setItem('ecowatch_user', JSON.stringify(user));
    await enterDashboard();
  } catch (err) {
    const message =
      err.message === 'Failed to fetch'
        ? 'Cannot reach API. Open http://localhost:3000/admin and run: cd backend && npm run dev'
        : err.message;
    $('login-error').textContent = message;
    $('login-error').classList.remove('hidden');
  }
});

$('logout-btn').addEventListener('click', logout);

$('export-btn').addEventListener('click', async () => {
  try {
    const res = await fetch(`${API}/analytics/export`, { headers: authHeaders() });
    if (!res.ok) throw new Error('Export failed');
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'ecowatch_reports.csv';
    a.click();
    URL.revokeObjectURL(url);
  } catch (err) {
    alert(err.message);
  }
});

function activateTab(tab) {
  if (reportsRefreshTimer) {
    clearInterval(reportsRefreshTimer);
    reportsRefreshTimer = null;
  }
  document.querySelectorAll('.tab').forEach((b) => {
    if (b.classList.contains('hidden')) return;
    b.classList.toggle('active', b.dataset.tab === tab);
  });
  document.querySelectorAll('.tab-panel').forEach((p) => p.classList.add('hidden'));
  const panel = $(`tab-${tab}`);
  if (panel) panel.classList.remove('hidden');
  if (tab === 'reports') {
    // Poll often so agency admins see officer status updates live
    const intervalMs = canAssignOfficers() && !canUpdateReportStatus() ? 8000 : 20000;
    reportsRefreshTimer = setInterval(() => loadReports().catch(console.error), intervalMs);
  }
}

// Refresh reports when returning to the tab/window (officer may have updated status)
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && !$('tab-reports')?.classList.contains('hidden')) {
    loadReports().catch(console.error);
  }
});
window.addEventListener('focus', () => {
  if (!$('tab-reports')?.classList.contains('hidden')) {
    loadReports().catch(console.error);
  }
});

document.querySelectorAll('.tab').forEach((btn) => {
  btn.addEventListener('click', async () => {
    if (btn.classList.contains('hidden')) return;
    activateTab(btn.dataset.tab);
    const tab = btn.dataset.tab;
    if (tab === 'map') await loadMap();
    if (tab === 'analytics') await loadAnalytics();
    if (tab === 'reports') await loadReports();
    if (tab === 'performance') await loadPerformance();
    if (tab === 'announcements') await loadAnnouncementsAdmin();
    if (tab === 'users') await loadUsersAdmin();
    if (tab === 'audit') await loadAuditLogs();
    if (tab === 'settings') await loadSettings();
    if (tab === 'notifications') await loadNotifications();
  });
});

$('refresh-analytics').addEventListener('click', loadAnalytics);
$('period-select').addEventListener('change', loadAnalytics);

function mediaUrl(url) {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${window.location.origin}${url.startsWith('/') ? url : `/${url}`}`;
}

function statusLabel(status) {
  return STATUS_LABELS[status] || status;
}

function statusBadgeClass(status) {
  const s = normalizeStatus(status);
  if (s === 'closed' || s === 'resolved') return 'badge-low';
  if (s === 'received') return 'badge-medium';
  return 'badge-high';
}

function renderStatusCell(report) {
  const status = normalizeStatus(report.status);
  return `<span class="badge ${statusBadgeClass(status)}">${statusLabel(status)}</span>`;
}

function renderReportActions(report) {
  if (isResearcher()) return '<span class="meta">Anonymized</span>';

  const status = normalizeStatus(report.status);
  const next = NEXT_STATUS[status];
  const parts = [];
  const isReceived = status === 'received';
  const isAssigned = Boolean(report.assignedOfficerId);

  // Agency / municipal leadership: assign only while Received; status reflects officer updates live.
  if (canAssignOfficers() && !canUpdateReportStatus()) {
    // Always show current status (updates when officer advances the case)
    parts.push(`<span class="badge ${statusBadgeClass(status)}">${statusLabel(status)}</span>`);

    if (isReceived) {
      const deptOfficers = officersForReport(report);
      const opts = deptOfficers
        .map((o) => `<option value="${o.id}" ${report.assignedOfficerId === o.id ? 'selected' : ''}>${escapeHtml(o.displayName)}</option>`)
        .join('');
      if (!deptOfficers.length) {
        parts.push('<span class="meta">No officers in this department</span>');
      } else {
        parts.push(`<select class="assign-select" data-id="${report.id}">
          <option value="">${isAssigned ? 'Reassign officer…' : 'Assign officer…'}</option>${opts}
        </select>`);
      }
      if (isAssigned) {
        parts.push(`<span class="meta">Assigned: ${escapeHtml(report.assignedOfficerName || 'officer')}</span>`);
      }
    } else if (status === 'resolved' && canCloseReports()) {
      parts.push(`<select class="status-select" data-id="${report.id}" data-next="closed">
        <option value="resolved" selected>Resolved by officer</option>
        <option value="closed">→ Close case</option>
      </select>`);
      if (report.assignedOfficerName) {
        parts.push(`<span class="meta">${escapeHtml(report.assignedOfficerName)}</span>`);
      }
    } else if (status === 'closed') {
      if (report.assignedOfficerName) {
        parts.push(`<span class="meta">${escapeHtml(report.assignedOfficerName)}</span>`);
      }
    } else {
      // Live investigation progress from officer updates
      parts.push(`<span class="meta">Officer: ${escapeHtml(report.assignedOfficerName || '—')}</span>`);
    }

    if (canEscalate() && !report.escalated && status !== 'closed') {
      parts.push(`<button type="button" class="secondary escalate-btn" data-id="${report.id}">Escalate</button>`);
    } else if (report.escalated) {
      parts.push('<span class="badge badge-high">Escalated</span>');
    }

    return parts.join(' ') || '<span class="meta">—</span>';
  }

  // Field officers: update status only after assignment (their list is assigned cases only).
  if (canUpdateReportStatus()) {
    if (!isAssigned) {
      parts.push('<span class="meta">Not assigned to you</span>');
    } else if (next && next !== 'closed') {
      parts.push(`<select class="status-select" data-id="${report.id}" data-next="${next}">
        <option value="${status}" selected>${statusLabel(status)}</option>
        <option value="${next}">→ ${statusLabel(next)}</option>
      </select>`);
    } else if (next === 'closed' || status === 'resolved') {
      parts.push('<span class="meta">Awaiting agency closure</span>');
    } else {
      parts.push('<span class="meta">Closed</span>');
    }

    if (canAddInvestigationNotes() && isAssigned && status !== 'closed') {
      parts.push(`<button type="button" class="secondary notes-btn" data-id="${report.id}" data-notes="${escapeHtml(report.investigationNotes || '')}">Notes</button>`);
      parts.push(`<label class="meta inv-photo-label">Photo<input type="file" class="inv-media" data-id="${report.id}" accept="image/*,video/*" hidden /></label>`);
    }

    if (report.reporterPhone && isAssigned) {
      parts.push(`<a class="meta" href="tel:${escapeHtml(report.reporterPhone)}">Call</a>`);
    }
  }

  return parts.join(' ') || '<span class="meta">—</span>';
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderDescriptionCell(report) {
  const text = (report.description || '').trim();
  if (!text) return '<span class="meta">—</span>';

  const preview = text.length > 200 ? `${text.slice(0, 200)}…` : text;
  return `<div class="description-block"><p class="description-text" title="${escapeHtml(text)}">${escapeHtml(preview)}</p></div>`;
}

function renderMediaCell(report) {
  const items = (report.media || []).filter((m) => {
    const type = m.type || '';
    const mime = m.mimeType || '';
    return type !== 'audio' && !mime.startsWith('audio');
  });
  if (!items.length) return '<span class="meta">No photo/video</span>';
  return items.map((m) => {
    const url = mediaUrl(m.remoteUrl || m.storageUrl);
    if ((m.type === 'video') || (m.mimeType || '').startsWith('video')) {
      return `<a class="media-link" href="${url}" target="_blank" rel="noopener">▶ Video</a>`;
    }
    return `<a href="${url}" target="_blank" rel="noopener"><img class="media-thumb" src="${url}" alt="Evidence" loading="lazy" /></a>`;
  }).join(' ');
}

async function loadOfficers() {
  if (!canAssignOfficers()) {
    officersCache = [];
    return;
  }
  try {
    // Agency users are scoped server-side; municipal/super load all then filter per report.
    officersCache = await api('/admin/officers');
  } catch {
    officersCache = [];
  }
}

async function loadReports() {
  if (canAssignOfficers()) await loadOfficers();
  const reports = await api('/reports');
  const active = reports.filter((r) => !['resolved', 'closed'].includes(normalizeStatus(r.status))).length;
  const critical = reports.filter((r) => r.severity === 'critical').length;
  const municipal = isMunicipalScope();
  const researcher = isResearcher();
  const escalated = reports.filter((r) => r.escalated).length;

  const statsLabel = isOfficer()
    ? 'My Cases'
    : isAgencyWide() || isEmergencyOfficer() || isPolice()
      ? `${agencyDisplayName()} Reports`
      : municipal
        ? 'All Incidents'
        : researcher
          ? 'Anonymized Incidents'
          : 'Reports';
  $('stats').innerHTML = `
    <div class="stat-card"><strong>${reports.length}</strong>${statsLabel}</div>
    <div class="stat-card"><strong>${active}</strong>Active</div>
    <div class="stat-card"><strong>${critical}</strong>Critical</div>
    <div class="stat-card"><strong>${escalated}</strong>Escalated</div>
  `;

  const colspan = researcher ? 6 : 10;
  $('reports-body').innerHTML = reports.length
    ? reports.map((r) => `
    <tr>
      <td class="col-token${researcher ? ' hidden' : ''}"><code>${r.trackingToken || '—'}</code></td>
      <td class="col-category">${categoryLabel(r.category)}</td>
      <td>${renderStatusCell({ ...r, status: normalizeStatus(r.status) })}</td>
      <td>${r.severity}${r.severityScore != null && !researcher ? ` (${r.severityScore})` : ''}</td>
      <td>${r.source}</td>
      <td>${r.communityName || '—'}</td>
      <td class="desc-cell col-description${researcher ? ' hidden' : ''}">${renderDescriptionCell(r)}</td>
      <td class="media-cell col-evidence${researcher ? ' hidden' : ''}">${renderMediaCell(r)}</td>
      <td>${new Date(r.createdAt).toLocaleString()}</td>
      <td class="col-actions action-cell${researcher ? ' hidden' : ''}">${renderReportActions(r)}</td>
    </tr>
  `).join('')
    : `<tr><td colspan="${colspan}">No reports in your scope yet.</td></tr>`;

  if (canUpdateReportStatus() || canCloseReports()) {
    document.querySelectorAll('.status-select').forEach((sel) => {
      sel.addEventListener('change', async () => {
        if (!sel.value || sel.value !== sel.dataset.next) {
          sel.value = sel.dataset.next ? sel.options[0].value : sel.value;
          return;
        }
        try {
          await api(`/reports/${sel.dataset.id}/status`, {
            method: 'PATCH',
            body: JSON.stringify({
              status: sel.value,
              message: `Updated by ${roleLabel()}`,
            }),
          });
          await loadReports();
        } catch (err) {
          alert(err.message);
          await loadReports();
        }
      });
    });
  }

  if (canAddInvestigationNotes()) {
    document.querySelectorAll('.notes-btn').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const notes = prompt('Investigation notes', btn.dataset.notes || '');
        if (notes === null) return;
        try {
          await api(`/reports/${btn.dataset.id}/notes`, {
            method: 'PATCH',
            body: JSON.stringify({ notes }),
          });
          await loadReports();
        } catch (err) {
          alert(err.message);
        }
      });
    });

    document.querySelectorAll('.inv-photo-label').forEach((label) => {
      label.addEventListener('click', () => label.querySelector('input')?.click());
    });
    document.querySelectorAll('.inv-media').forEach((input) => {
      input.addEventListener('change', async () => {
        if (!input.files?.length) return;
        const body = new FormData();
        body.append('media', input.files[0]);
        try {
          const res = await fetch(`${API}/reports/${input.dataset.id}/investigation-media`, {
            method: 'POST',
            headers: { Authorization: `Bearer ${token}` },
            body,
          });
          const data = await res.json().catch(() => ({}));
          if (!res.ok) throw new Error(data.error || res.statusText);
          await loadReports();
        } catch (err) {
          alert(err.message);
        }
      });
    });
  }

  document.querySelectorAll('.assign-select').forEach((sel) => {
    sel.addEventListener('change', async () => {
      if (!sel.value) return;
      try {
        await api(`/reports/${sel.dataset.id}/assign`, {
          method: 'PATCH',
          body: JSON.stringify({ officerId: sel.value }),
        });
        await loadReports();
      } catch (err) {
        alert(err.message);
        await loadReports();
      }
    });
  });

  document.querySelectorAll('.escalate-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      if (!confirm('Escalate this incident to municipal administration?')) return;
      try {
        await api(`/reports/${btn.dataset.id}/escalate`, {
          method: 'POST',
          body: JSON.stringify({ message: 'Escalated from portal' }),
        });
        await loadReports();
      } catch (err) {
        alert(err.message);
      }
    });
  });
}

async function loadNotifications() {
  const el = $('notifications-body');
  if (!el) return;
  const items = await api('/admin/me/notifications');
  el.innerHTML = items.length
    ? items.map((n) => `
      <tr class="${n.isRead ? '' : 'unread-row'}">
        <td>${n.isEmergency ? '<span class="badge badge-critical">Emergency</span> ' : ''}${escapeHtml(n.title)}</td>
        <td>${escapeHtml(n.body)}</td>
        <td>${new Date(n.createdAt).toLocaleString()}</td>
        <td>${n.isRead ? 'Read' : `<button class="secondary mark-read-btn" data-id="${n.id}">Mark read</button>`}</td>
      </tr>`).join('')
    : '<tr><td colspan="4">No notifications.</td></tr>';

  document.querySelectorAll('.mark-read-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await api(`/admin/me/notifications/${btn.dataset.id}/read`, { method: 'POST', body: '{}' });
      await loadNotifications();
    });
  });
}

async function loadPerformance() {
  const el = $('performance-body');
  if (!el) return;
  const data = await api('/admin/performance');
  const cats = (data.byCategory || []).map((r) => `
    <tr>
      <td>${categoryLabel(r.category)}</td>
      <td>${r.total}</td>
      <td>${r.resolved}</td>
      <td>${r.escalated}</td>
      <td>${r.avgResponseHours ?? '—'} h</td>
      <td>${r.avgResolutionHours ?? '—'} h</td>
    </tr>`).join('');
  const officers = (data.officers || []).map((o) => `
    <tr>
      <td>${escapeHtml(o.displayName)}</td>
      <td>${o.assignedAgency || '—'}</td>
      <td>${o.assigned}</td>
      <td>${o.closed}</td>
    </tr>`).join('');
  el.innerHTML = `
    <h3>Response by category</h3>
    <table><thead><tr><th>Category</th><th>Total</th><th>Resolved</th><th>Escalated</th><th>Avg response</th><th>Avg resolution</th></tr></thead>
    <tbody>${cats || '<tr><td colspan="6">No data</td></tr>'}</tbody></table>
    <h3>Officer workload</h3>
    <table><thead><tr><th>Officer</th><th>Agency</th><th>Assigned</th><th>Closed</th></tr></thead>
    <tbody>${officers || '<tr><td colspan="4">No officers</td></tr>'}</tbody></table>`;
}

async function loadAnnouncementsAdmin() {
  const el = $('announcements-admin-body');
  if (!el) return;
  const items = await api('/admin/announcements');
  el.innerHTML = items.map((a) => `
    <tr>
      <td>${escapeHtml(a.title)}</td>
      <td>${escapeHtml(a.body)}</td>
      <td>${new Date(a.publishedAt).toLocaleString()}</td>
      <td><button class="secondary del-ann-btn" data-id="${a.id}">Delete</button></td>
    </tr>`).join('') || '<tr><td colspan="4">No announcements</td></tr>';

  document.querySelectorAll('.del-ann-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await api(`/admin/announcements/${btn.dataset.id}`, { method: 'DELETE' });
      await loadAnnouncementsAdmin();
    });
  });
}

async function loadUsersAdmin() {
  const el = $('users-admin-body');
  if (!el) return;
  const [users, agencies] = await Promise.all([
    api('/admin/users'),
    api('/admin/agencies'),
  ]);
  $('agencies-admin-body').innerHTML = (agencies.agencies || []).map((a) => `
    <tr>
      <td>${escapeHtml(a.name)}</td>
      <td>${(a.categories || []).map(categoryLabel).join(', ') || 'Support'}</td>
      <td>${a.staff?.admins || 0} admin / ${a.staff?.officers || 0} officers</td>
      <td><code>${a.portalEmail}</code></td>
    </tr>`).join('');

  el.innerHTML = users.map((u) => `
    <tr>
      <td>${escapeHtml(u.displayName)}</td>
      <td>${escapeHtml(u.email)}</td>
      <td>${escapeHtml(u.roleLabel || u.role)}</td>
      <td>${u.assignedAgency || '—'}</td>
      <td>${u.isActive ? 'Active' : 'Inactive'}</td>
    </tr>`).join('');

  // Agency admins register officers into their own department automatically.
  const agencyInput = $('user-agency');
  const roleSelect = $('user-role');
  const agencyLabel = agencyInput?.closest('label');
  if (isAgencyAdmin()) {
    if (agencyInput) {
      agencyInput.value = user.assignedAgency || '';
      agencyInput.readOnly = true;
    }
    if (agencyLabel) {
      agencyLabel.querySelector('span')?.remove();
      const hint = document.createElement('span');
      hint.className = 'meta';
      hint.textContent = ` (locked to ${user.assignedAgency || 'your department'})`;
      agencyLabel.appendChild(hint);
    }
    if (roleSelect) {
      [...roleSelect.options].forEach((opt) => {
        opt.hidden = !['environmental_officer', 'emergency_officer', 'police_support'].includes(opt.value);
      });
      roleSelect.value = 'environmental_officer';
    }
  } else if (agencyInput) {
    agencyInput.readOnly = false;
  }
}

async function loadAuditLogs() {
  const el = $('audit-body');
  if (!el) return;
  const rows = await api('/admin/audit-logs');
  el.innerHTML = rows.map((r) => `
    <tr>
      <td>${new Date(r.createdAt).toLocaleString()}</td>
      <td>${escapeHtml(r.actorEmail || '—')}</td>
      <td>${escapeHtml(r.actorRole || '—')}</td>
      <td>${escapeHtml(r.action)}</td>
      <td>${escapeHtml(r.entityType || '')} ${escapeHtml(r.entityId || '')}</td>
    </tr>`).join('') || '<tr><td colspan="5">No audit entries</td></tr>';
}

async function loadSettings() {
  const el = $('settings-body');
  if (!el) return;
  const settings = await api('/admin/settings');
  el.innerHTML = `
    <label>Emergency severity threshold
      <select id="setting-threshold">
        ${['medium', 'high', 'critical'].map((s) =>
    `<option value="${s}" ${settings.emergency_severity_threshold === s || settings.emergency_severity_threshold === `"${s}"` ? 'selected' : ''}>${s}</option>`).join('')}
      </select>
    </label>
    <label>Routing enabled
      <select id="setting-routing">
        <option value="true" ${String(settings.routing_enabled).includes('true') ? 'selected' : ''}>Yes</option>
        <option value="false" ${String(settings.routing_enabled).includes('false') ? 'selected' : ''}>No</option>
      </select>
    </label>
    <label>Backup retention (days)
      <input id="setting-backup" type="number" value="${String(settings.backup_retention_days || 30).replace(/"/g, '')}" />
    </label>
    <button id="save-settings" type="button">Save settings</button>
    <p class="meta">Audit logs cannot be deleted. Super Administrator only.</p>`;

  $('save-settings')?.addEventListener('click', async () => {
    await api('/admin/settings', {
      method: 'PUT',
      body: JSON.stringify({
        emergency_severity_threshold: $('setting-threshold').value,
        routing_enabled: $('setting-routing').value === 'true',
        backup_retention_days: Number($('setting-backup').value) || 30,
      }),
    });
    alert('Settings saved');
  });
}

const HOTSPOT_PRIORITY_COLORS = {
  critical: '#b71c1c',
  high: '#e65100',
  medium: '#f9a825',
  low: '#f57f17',
};

const PREDICTED_HOTSPOT_COLOR = '#6a1b9a';

function hotspotPriorityColor(priority) {
  return HOTSPOT_PRIORITY_COLORS[priority] || HOTSPOT_PRIORITY_COLORS.medium;
}

async function loadMap() {
  if (!map) {
    map = L.map('map').setView([5.3018, -1.9931], 12);
    mapTileLayer = createMapTileLayer();
    mapTileLayer.addTo(map);
    mapLayer = L.layerGroup().addTo(map);
  }
  mapLayer.clearLayers();

  const reports = await api('/maps/reports');
  reports.forEach((r) => {
    L.marker([r.latitude, r.longitude])
      .bindPopup(`<b>${categoryLabel(r.category)}</b><br>${r.status}<br>${r.severity}`)
      .addTo(mapLayer);
  });

  const hotspots = await api('/maps/hotspots');
  hotspots.forEach((h) => {
    const color = hotspotPriorityColor(h.priority);
    L.circle([h.latitude, h.longitude], {
      radius: h.radiusMeters || 1000,
      color,
      weight: 2,
      fillColor: color,
      fillOpacity: 0.2,
    })
      .bindPopup(`<b>Current hotspot</b> (${h.priority})<br>${h.reportCount} reports<br>${categoryLabel(h.dominantCategory)}`)
      .addTo(mapLayer);
  });

  let predictedCount = 0;
  try {
    const pred = await api('/analytics/predictions');
    predictedCount = (pred.predictedHotspots || []).length;
    (pred.predictedHotspots || []).forEach((p) => {
      const tint = hotspotPriorityColor(p.priority);
      L.circle([p.latitude, p.longitude], {
        radius: p.radiusMeters || 1000,
        color: PREDICTED_HOTSPOT_COLOR,
        weight: 2,
        dashArray: '8 5',
        fillColor: tint,
        fillOpacity: 0.12,
      })
        .bindPopup(`<b>Predicted hotspot</b><br>${p.priority} risk<br>${p.reportCount30d ?? 0} reports in last 30 days`)
        .addTo(mapLayer);
    });
  } catch (_) {
    /* predictions optional */
  }

  const legend = $('map-legend');
  const base = legend.textContent.split(' — ')[0];
  legend.textContent = hotspots.length
    ? `${base} — ${hotspots.length} current hotspot(s), ${predictedCount} predicted. Solid = current; dashed purple = ML forecast.`
    : `${base} — No current hotspots${predictedCount ? `; ${predictedCount} predicted` : ''}. Dashed purple = ML forecast.`;

  setTimeout(() => map.invalidateSize(), 100);
}

const CHART_COLORS = [
  '#2e7d32', '#1565c0', '#6a1b9a', '#c62828', '#ef6c00',
  '#00838f', '#5d4037', '#455a64',
];

function destroyAnalyticsCharts() {
  Object.values(analyticsCharts).forEach((chart) => chart.destroy());
  analyticsCharts = {};
}

function chartOrEmpty(canvasId, config, hasData) {
  const canvas = $(canvasId);
  const wrap = canvas.parentElement;
  wrap.querySelector('.chart-empty')?.remove();
  if (!hasData) {
    if (analyticsCharts[canvasId]) {
      analyticsCharts[canvasId].destroy();
      delete analyticsCharts[canvasId];
    }
    const empty = document.createElement('p');
    empty.className = 'chart-empty';
    empty.textContent = 'No data for this period';
    wrap.appendChild(empty);
    return;
  }
  if (analyticsCharts[canvasId]) analyticsCharts[canvasId].destroy();
  analyticsCharts[canvasId] = new Chart(canvas, config);
}

function renderAnalyticsCharts(data) {
  destroyAnalyticsCharts();
  lastAnalyticsData = data;

  const theme = chartThemeOptions();
  const trend = data.dailyTrend || [];
  chartOrEmpty('chart-trend', {
    type: 'line',
    data: {
      labels: trend.map((d) => d.date),
      datasets: [{
        label: 'Reports',
        data: trend.map((d) => d.count),
        borderColor: '#66bb6a',
        backgroundColor: isDarkTheme() ? 'rgba(102, 187, 106, 0.18)' : 'rgba(46, 125, 50, 0.12)',
        fill: true,
        tension: 0.3,
        pointRadius: 4,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      color: theme.color,
      scales: theme.scales,
    },
  }, trend.length > 0);

  const categories = Object.entries(data.categoryBreakdown || {});
  chartOrEmpty('chart-category-bar', {
    type: 'bar',
    data: {
      labels: categories.map(([k]) => categoryLabel(k)),
      datasets: [{
        label: 'Reports',
        data: categories.map(([, v]) => v),
        backgroundColor: CHART_COLORS,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: theme.scales,
      plugins: { legend: { display: false } },
    },
  }, categories.length > 0);

  const severities = Object.entries(data.severityBreakdown || {});
  chartOrEmpty('chart-severity-pie', {
    type: 'pie',
    data: {
      labels: severities.map(([k]) => k),
      datasets: [{
        data: severities.map(([, v]) => v),
        backgroundColor: ['#4caf50', '#ffc107', '#ff9800', '#f44336'],
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: theme.plugins.legend },
    },
  }, severities.length > 0);

  const sources = Object.entries(data.sourceBreakdown || {});
  chartOrEmpty('chart-source-pie', {
    type: 'pie',
    data: {
      labels: sources.map(([k]) => (k === 'ussd' ? 'USSD' : 'Mobile App')),
      datasets: [{
        data: sources.map(([, v]) => v),
        backgroundColor: ['#1565c0', '#2e7d32'],
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: theme.plugins.legend },
    },
  }, sources.length > 0);

  const growth = data.hotspotGrowth || [];
  chartOrEmpty('chart-hotspot-growth', {
    type: 'line',
    data: {
      labels: growth.map((d) => d.date),
      datasets: [
        {
          label: 'Hotspot clusters',
          data: growth.map((d) => d.hotspotCount),
          borderColor: '#ef6c00',
          backgroundColor: 'rgba(239, 108, 0, 0.12)',
          fill: false,
          tension: 0.3,
        },
        {
          label: 'Reports in hotspots',
          data: growth.map((d) => d.totalReportsInHotspots),
          borderColor: '#6a1b9a',
          backgroundColor: 'rgba(106, 27, 154, 0.1)',
          fill: true,
          tension: 0.3,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      color: theme.color,
      scales: theme.scales,
      plugins: { legend: theme.plugins.legend },
    },
  }, growth.length > 0);
}

function renderPredictionSection(data) {
  const preds = data.predictedHotspots || [];
  const trend = data.predictedTrend || {};

  $('predicted-trend').innerHTML = trend.predictedReportsNextWeek != null
    ? `<p><strong>Forecast:</strong> ~${trend.predictedReportsNextWeek} reports expected next week. Rising categories: ${(trend.risingCategories || []).map(categoryLabel).join(', ') || '—'}</p>`
    : '<p class="meta">No trend forecast yet.</p>';

  $('predictions-body').innerHTML = preds.length
    ? preds.map((p) => `
      <tr>
        <td>${p.latitude?.toFixed(4)}, ${p.longitude?.toFixed(4)}</td>
        <td><span class="badge badge-${p.priority}">${p.priority}</span></td>
        <td>${p.reportCount30d ?? '—'}</td>
      </tr>
    `).join('')
    : '<tr><td colspan="3">No high-risk areas predicted for the next 7 days.</td></tr>';
}

async function loadAnalytics() {
  const period = $('period-select').value;
  const data = await api(`/analytics?period=${period}`);

  const cats = Object.entries(data.categoryBreakdown || {})
    .map(([k, v]) => `<div class="stat-card"><strong>${v}</strong>${categoryLabel(k)}</div>`)
    .join('');

  $('analytics-summary').innerHTML = `
    <div class="stat-card"><strong>${data.totalReports}</strong>Total (${period})</div>
    <div class="stat-card"><strong>${data.resolvedReports}</strong>Resolved</div>
    <div class="stat-card"><strong>${(data.hotspots || []).length}</strong>Current hotspots</div>
    <div class="stat-card"><strong>${(data.predictedHotspots || []).length}</strong>Predicted (7d)</div>
    ${!isAgencyAdmin() ? cats : ''}
  `;

  renderAnalyticsCharts(data);
  renderPredictionSection(data);
}

$('announcement-form')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  try {
    await api('/admin/announcements', {
      method: 'POST',
      body: JSON.stringify({
        title: $('ann-title').value,
        body: $('ann-body').value,
        isPublic: true,
      }),
    });
    $('ann-title').value = '';
    $('ann-body').value = '';
    await loadAnnouncementsAdmin();
  } catch (err) {
    alert(err.message);
  }
});

$('user-form')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  try {
    const agencyKey = isAgencyAdmin()
      ? (user.assignedAgency || null)
      : ($('user-agency').value.trim() || null);
    await api('/admin/users', {
      method: 'POST',
      body: JSON.stringify({
        displayName: $('user-name').value,
        email: $('user-email').value,
        password: $('user-password').value,
        role: $('user-role').value,
        assignedAgency: agencyKey,
      }),
    });
    alert('User registered. They must log in with that email/password, then open My Cases to update assigned incidents.');
    e.target.reset();
    await loadUsersAdmin();
  } catch (err) {
    alert(err.message);
  }
});

if (token && user && ALLOWED_ROLES.includes(user.role)) {
  enterDashboard().catch(logout);
} else {
  if (token) logout();
  show('login');
  checkBackendHealth();
}

async function checkBackendHealth() {
  const errEl = $('login-error');
  if (!errEl) return;
  try {
    const res = await fetch(`${window.location.origin}/health`);
    const data = await res.json();
    if (data.database === 'unavailable') {
      errEl.textContent =
        'Database offline. Start Docker Desktop, then: cd backend && docker compose up -d postgres && npm run db:seed';
      errEl.classList.remove('hidden');
    }
  } catch {
    errEl.textContent =
      'API offline. Run: cd backend && npm run dev — then open http://localhost:3000/admin';
    errEl.classList.remove('hidden');
  }
}
