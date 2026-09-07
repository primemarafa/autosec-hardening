// ==============================================================================
// AutoSec Dashboard — Application principale
// ==============================================================================

const AppState = {
    currentReport: null,
    currentView: 'overview',
    statusFilter: 'all',
    severityFilter: 'all',
    history: [],
    darkMode: false
};

// --- Initialisation ---
function init() {
    // Dark mode
    const savedDark = localStorage.getItem('autosec-darkmode');
    if (savedDark !== null) {
        AppState.darkMode = savedDark === 'true';
    } else {
        AppState.darkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    applyDarkMode();

    // Charger l'historique
    const savedHistory = localStorage.getItem('autosec-history');
    if (savedHistory) {
        try { AppState.history = JSON.parse(savedHistory); } catch (e) { console.error('Erreur historique', e); }
    }

    setupEventListeners();
    lucide.createIcons();
}

// --- Dark Mode ---
function applyDarkMode() {
    if (AppState.darkMode) {
        document.documentElement.classList.add('dark');
    } else {
        document.documentElement.classList.remove('dark');
    }
    localStorage.setItem('autosec-darkmode', AppState.darkMode);

    if (AppState.currentReport) {
        updateCharts(AppState.currentReport, AppState.history, AppState.darkMode);
    }
}

function toggleDarkMode() {
    AppState.darkMode = !AppState.darkMode;
    applyDarkMode();
}

// --- Event Listeners ---
function setupEventListeners() {
    // Dark mode toggle
    document.getElementById('darkModeToggle').addEventListener('click', toggleDarkMode);

    // File inputs (sidebar + empty state)
    document.getElementById('fileInput').addEventListener('change', handleFileSelect);
    document.getElementById('fileInputMain').addEventListener('change', handleFileSelect);

    // Drag & Drop sur la zone principale
    const dropZone = document.getElementById('dropZone');
    if (dropZone) {
        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(ev => {
            dropZone.addEventListener(ev, preventDefaults, false);
        });
        dropZone.addEventListener('dragenter', () => dropZone.classList.add('drop-active'));
        dropZone.addEventListener('dragover', () => dropZone.classList.add('drop-active'));
        dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drop-active'));
        dropZone.addEventListener('drop', handleFileDrop);
    }

    // Drag & Drop global (body)
    document.body.addEventListener('dragover', preventDefaults);
    document.body.addEventListener('drop', (e) => {
        preventDefaults(e);
        const file = e.dataTransfer.files[0];
        if (file) processFile(file);
    });

    // Navigation sidebar
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', () => setView(btn.getAttribute('data-view')));
    });

    // Filtres de statut
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            AppState.statusFilter = btn.getAttribute('data-filter-status');
            renderCheckCards();
        });
    });

    // Effacer l'historique
    document.getElementById('clearHistoryBtn').addEventListener('click', clearHistory);

    // Menu mobile
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebarOverlay');
    if (menuToggle) {
        menuToggle.addEventListener('click', () => {
            sidebar.classList.toggle('hidden');
            sidebar.classList.toggle('fixed');
            sidebar.classList.toggle('left-0');
            sidebar.classList.toggle('top-0');
            sidebar.classList.toggle('h-full');
            sidebar.classList.toggle('z-50');
            sidebar.classList.toggle('bg-white');
            sidebar.classList.toggle('dark:bg-slate-900');
            sidebar.classList.toggle('p-4');
            sidebar.classList.toggle('pt-16');
            overlay.classList.toggle('hidden');
        });
    }
    if (overlay) {
        overlay.addEventListener('click', () => {
            sidebar.classList.add('hidden');
            overlay.classList.add('hidden');
        });
    }
}

function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

// --- Gestion des fichiers ---
function handleFileSelect(e) {
    const files = e.target.files;
    if (files.length > 0) {
        // Charger tous les fichiers sélectionnés (pour l'historique)
        Array.from(files).forEach(f => processFile(f));
    }
}

function handleFileDrop(e) {
    preventDefaults(e);
    const dropZone = document.getElementById('dropZone');
    if (dropZone) dropZone.classList.remove('drop-active');

    const files = e.dataTransfer.files;
    if (files.length > 0) {
        Array.from(files).forEach(f => processFile(f));
    }
}

function processFile(file) {
    if (!file.name.endsWith('.json')) {
        showToast('Veuillez sélectionner un fichier JSON valide.', 'error');
        return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
        try {
            const json = JSON.parse(e.target.result);
            loadReport(json);
            showToast(`Rapport chargé : ${json.hostname || 'inconnu'}`, 'success');
        } catch (err) {
            console.error('Erreur JSON', err);
            showToast('Erreur lors de la lecture du fichier JSON.', 'error');
        }
    };
    reader.readAsText(file);
}

// --- Chargement d'un rapport ---
function loadReport(jsonData) {
    // Validation basique du schéma
    if (!jsonData.score && jsonData.score !== 0) {
        showToast('Format de rapport invalide (champ "score" manquant).', 'error');
        return;
    }
    if (!jsonData.checks || !Array.isArray(jsonData.checks)) {
        showToast('Format de rapport invalide (champ "checks" manquant).', 'error');
        return;
    }

    AppState.currentReport = jsonData;
    addToHistory(jsonData);

    document.getElementById('emptyState').classList.add('hidden');
    document.getElementById('dashboardContent').classList.remove('hidden');

    setView('overview');
}

// --- Historique ---
function addToHistory(report) {
    const entry = {
        timestamp: report.timestamp,
        hostname: report.hostname,
        os: report.os,
        score: report.score,
        passed: report.passed,
        total: report.total
    };

    // Éviter les doublons
    if (!AppState.history.find(h => h.timestamp === entry.timestamp && h.hostname === entry.hostname)) {
        AppState.history.push(entry);
        AppState.history.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
        localStorage.setItem('autosec-history', JSON.stringify(AppState.history));
    }
}

function clearHistory() {
    AppState.history = [];
    localStorage.removeItem('autosec-history');
    if (AppState.currentReport) {
        addToHistory(AppState.currentReport);
    }
    updateCharts(AppState.currentReport, AppState.history, AppState.darkMode);
    showToast('Historique effacé.', 'success');
}

// --- Navigation ---
function setView(view) {
    AppState.currentView = view;

    // Mettre à jour la nav active
    document.querySelectorAll('.nav-btn').forEach(btn => {
        const isActive = btn.getAttribute('data-view') === view;
        btn.classList.toggle('active', isActive);
        btn.classList.toggle('bg-slate-100', isActive);
        btn.classList.toggle('dark:bg-slate-800', isActive);
        btn.classList.toggle('text-slate-900', isActive);
        btn.classList.toggle('dark:text-white', isActive);
        btn.classList.toggle('text-slate-600', !isActive);
        btn.classList.toggle('dark:text-slate-400', !isActive);
        btn.classList.toggle('hover:bg-slate-100', !isActive);
        btn.classList.toggle('dark:hover:bg-slate-800', !isActive);
    });

    renderOverview();
}

// --- Rendu ---
function renderOverview() {
    if (!AppState.currentReport) return;
    const r = AppState.currentReport;

    // Info bar
    const osBadge = document.getElementById('reportOsBadge');
    const isLinux = r.os === 'linux';
    const isDocker = r.os === 'docker';
    let badgeClass = 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/60 dark:text-indigo-300';
    let iconName = 'monitor';
    let osLabel = 'Windows';
    if (isLinux) {
        badgeClass = 'bg-amber-100 text-amber-700 dark:bg-amber-900/60 dark:text-amber-300';
        iconName = 'terminal';
        osLabel = 'Linux';
    } else if (isDocker) {
        badgeClass = 'bg-sky-100 text-sky-700 dark:bg-sky-900/60 dark:text-sky-300';
        iconName = 'box';
        osLabel = 'Docker';
    }
    osBadge.className = `inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${badgeClass}`;
    osBadge.innerHTML = `<i data-lucide="${iconName}" class="w-3 h-3"></i> ${osLabel}`;
    document.getElementById('reportHostname').textContent = r.hostname;
    document.getElementById('reportTimestamp').textContent = formatDate(r.timestamp);
    document.getElementById('reportOsDetails').textContent = r.os_details || '';

    // Stats cards
    const scoreColor = getScoreColor(r.score);
    document.getElementById('statScore').textContent = r.score + '%';
    document.getElementById('statScore').className = 'text-3xl font-bold';
    document.getElementById('statScore').style.color = scoreColor.main;
    document.getElementById('statPassed').textContent = r.passed;
    document.getElementById('statFailed').textContent = r.failed;
    document.getElementById('statTotal').textContent = r.total;

    // Score label
    const scoreLabel = document.getElementById('scoreLabel');
    scoreLabel.textContent = `Niveau de sécurité : ${scoreColor.label}`;
    scoreLabel.style.color = scoreColor.main;

    // Charts
    updateCharts(r, AppState.history, AppState.darkMode);

    // Checks
    renderCheckCards();

    // History visibility
    const historyEmpty = document.getElementById('historyEmpty');
    const historyCanvas = document.getElementById('historyCanvas');
    if (AppState.history.length <= 1) {
        historyEmpty.classList.remove('hidden');
        historyCanvas.classList.add('hidden');
    } else {
        historyEmpty.classList.add('hidden');
        historyCanvas.classList.remove('hidden');
    }

    lucide.createIcons();
}

function renderCheckCards() {
    const container = document.getElementById('checksContainer');
    container.innerHTML = '';

    if (!AppState.currentReport) return;

    let checks = [...AppState.currentReport.checks];

    // Filtrer par vue OS
    // (un rapport est mono-OS, mais on garde le filtre pour les vues linux/windows)

    // Filtrer par statut
    if (AppState.statusFilter !== 'all') {
        checks = checks.filter(c => c.status === AppState.statusFilter);
    }

    if (checks.length === 0) {
        container.innerHTML = '<p class="text-center text-sm text-slate-400 dark:text-slate-500 py-6">Aucun contrôle ne correspond aux filtres sélectionnés.</p>';
        return;
    }

    checks.forEach(check => {
        const isPass = check.status === 'pass';

        const card = document.createElement('div');
        card.className = 'check-card rounded-lg p-4 flex flex-col gap-2 bg-white dark:bg-slate-900/80';

        let remediationHtml = '';
        if (!isPass && check.remediation) {
            remediationHtml = `
                <div class="mt-1">
                    <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-1">Remédiation :</p>
                    <div class="terminal-block">${escapeHtml(check.remediation)}</div>
                </div>`;
        }

        card.innerHTML = `
            <div class="flex items-start justify-between gap-2">
                <div class="flex items-start gap-3 min-w-0">
                    <i data-lucide="${isPass ? 'check-circle-2' : 'alert-triangle'}" class="w-5 h-5 mt-0.5 flex-shrink-0 ${isPass ? 'text-emerald-500' : 'text-rose-500'}"></i>
                    <div class="min-w-0">
                        <h4 class="text-sm font-semibold text-slate-800 dark:text-slate-100 leading-snug">${escapeHtml(check.description)}</h4>
                        <p class="text-xs text-slate-400 dark:text-slate-500 mt-0.5">${escapeHtml(check.id)} · ${escapeHtml(check.category || '')}</p>
                    </div>
                </div>
                <div class="flex gap-1.5 flex-shrink-0">
                    <span class="badge-${check.severity} px-2 py-0.5 text-[10px] font-semibold rounded-full uppercase">${check.severity}</span>
                    <span class="${isPass ? 'badge-pass' : 'badge-fail'} px-2 py-0.5 text-[10px] font-semibold rounded-full">${isPass ? 'CONFORME' : 'VULNÉRABLE'}</span>
                </div>
            </div>
            ${remediationHtml}`;

        container.appendChild(card);
    });

    lucide.createIcons();
}

// --- Utilitaires ---
function formatDate(isoString) {
    if (!isoString) return '';
    const d = new Date(isoString);
    return d.toLocaleString('fr-FR', {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function showToast(message, type = 'info') {
    const toastEl = document.getElementById('toast');
    const inner = toastEl.querySelector('.toast');

    let bg = 'bg-slate-800 text-white';
    if (type === 'success') bg = 'bg-emerald-600 text-white';
    if (type === 'error') bg = 'bg-rose-600 text-white';

    inner.className = `toast px-4 py-2.5 rounded-full text-sm font-medium shadow-lg ${bg}`;
    inner.textContent = message;
    toastEl.classList.remove('hidden');

    setTimeout(() => {
        toastEl.classList.add('hidden');
    }, 3000);
}

// --- Initialisation au chargement ---
document.addEventListener('DOMContentLoaded', init);
