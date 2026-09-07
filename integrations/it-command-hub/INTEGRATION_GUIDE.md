# 🔗 Guide d'Intégration : AutoSec-Hardening ✕ IT-Command-Hub

Ce guide décrit comment interfacer **AutoSec-Hardener** avec **IT Support Command Hub** pour créer une suite unifiée d'administration système, diagnostic et cybersécurité opérationnelle.

---

## 🏗️ 1. Architecture de l'Intégration

```
┌────────────────────────────────────────────────────────────────────────┐
│                   IT SUPPORT COMMAND HUB (Web UI)                      │
│                                                                        │
│   [ 💻 Support & Diag ]     [ 🛡️ AutoSec Hardening ]     [ 🌙 Mode ]  │
│   ──────────────────────────────────────────────────────────────────   │
│   Cartes d'actions 1-clic :                                            │
│   • 🔍 Lancer Audit (Score /100)                                       │
│   • 🛡️ Appliquer Durcissement (Backup auto)                             │
│   • ↩️ Rollback Immédiat                                              │
│   • 📊 Comparaison Avant/Après (PDF)                                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Requêtes HTTP (localhost:8484)
                                    │ Header: X-Companion-Token
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                 AGENT COMPAGNON C# (CompanionServer.exe)                │
│                 • Port : 127.0.0.1:8484                                │
│                 • Élévation UAC automatique (Verb = "runas")           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Exécution PowerShell / WSL
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        AUTODEFENSE ENGINE                              │
│   ├── windows/Audit-Security.ps1  ──► Export JSON / Score              │
│   ├── windows/Apply-Hardening.ps1 ──► Backup Registre + Durcissement   │
│   ├── windows/Rollback-Security.ps1 ──► Restauration instantanée       │
│   ├── docker/audit_docker.sh     ──► CIS Docker Benchmark             │
│   └── tools/Compare-Reports.ps1  ──► Génération PDF / Diff             │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 2. Méthode 1 : Intégration en Module de Commandes (Recommandée)

Cette méthode expose AutoSec directement dans la grille de cartes d'IT-Command-Hub avec le bouton **⚡ Exécuter**.

### Étape 1 : Ajouter la catégorie dans la barre latérale

Dans le fichier HTML ou le fichier de configuration des catégories d'IT-Command-Hub, ajoutez :

```javascript
{
  id: 'autosec',
  label: 'Sécurité & Hardening (ANSSI)',
  icon: 'shield-check',
  count: 6,
  badge: 'CIS / ANSSI'
}
```

### Étape 2 : Importer les commandes

Copiez les objets de commandes depuis [`autosec-commands-fragment.js`](./autosec-commands-fragment.js) et ajoutez-les dans le tableau `commands` du fichier `data/commands.js` d'IT-Command-Hub.

Ces commandes incluent :
- **Audit de Sécurité Windows** (`Audit-Security.ps1 -JsonExport`)
- **Application du Durcissement** (`Apply-Hardening.ps1`)
- **Rollback de Sécurité** (`Rollback-Security.ps1`)
- **Rapport de Comparaison Avant/Après** (`Compare-Reports.ps1 -Pdf`)
- **Audit Docker CIS** (`audit_docker.sh --json` via WSL)
- **⚡ Playbook automatisé** (Cycle complet : Audit → Hardening → Audit post)

### Étape 3 : Exécution 1-Clic via l'Agent Compagnon

Lorsque l'utilisateur clique sur **⚡ Exécuter** sur une carte AutoSec :
1. IT-Command-Hub effectue un `POST http://127.0.0.1:8484/exec`
2. Le payload transmet la commande avec `adminRequired: true`
3. L'agent C# déclenche le prompt UAC Windows et exécute le script avec les droits Administrateur
4. Le rapport JSON est horodaté et sauvegardé dans `reports/windows/`

---

## 🖥️ 3. Méthode 2 : Intégration par Onglet Dédié dans l'Interface

Pour donner accès au **Dashboard AutoSec** (jauge de score, historique, graphes) directement à l'intérieur d'IT-Command-Hub sans quitter l'interface :

### Dans le Header d'IT-Command-Hub (`index.html`)

Ajoutez un sélecteur d'onglets au niveau de l'en-tête :

```html
<div class="flex items-center gap-1 bg-slate-100 dark:bg-slate-800 p-1 rounded-lg">
  <button id="tab-hub" class="tab-btn active px-3 py-1.5 text-xs font-semibold rounded-md">
    <i data-lucide="terminal" class="w-3.5 h-3.5 inline mr-1"></i> Command Hub
  </button>
  <button id="tab-autosec" class="tab-btn px-3 py-1.5 text-xs font-semibold rounded-md">
    <i data-lucide="shield-check" class="w-3.5 h-3.5 inline mr-1"></i> AutoSec Dashboard
  </button>
</div>
```

### Dans la zone principale

Ajoutez un conteneur iframe ou composant dynamique pointant vers AutoSec :

```html
<!-- Vue Command Hub principale -->
<div id="view-hub" class="tab-view">
  <!-- Contenu existant d'IT-Command-Hub -->
</div>

<!-- Vue AutoSec Dashboard embarquée -->
<div id="view-autosec" class="tab-view hidden h-[calc(100vh-80px)]">
  <iframe src="../autosec-hardening/dashboard/index.html" class="w-full h-full border-0 rounded-xl"></iframe>
</div>
```

---

## ⚡ 4. Extension de l'Agent Compagnon C# (CompanionServer.cs)

Pour que l'agent compagnon C# localise automatiquement AutoSec quel que soit l'emplacement :

### Variable d'environnement recommandée

Définissez une variable d'environnement système ou utilisateur :
```powershell
[Environment]::SetEnvironmentVariable("AUTODEFENSE_DIR", "C:\Chemin\autosec-hardening", "User")
```

### Amélioration de l'exécution dans `CompanionServer.cs`

Dans la méthode `HandleExec(HttpListenerContext context)` de votre agent C#, vous pouvez ajouter la résolution automatique de variable :

```csharp
// Substitution automatique du chemin AutoSec si présent dans la commande
string autoSecDir = Environment.GetEnvironmentVariable("AUTODEFENSE_DIR") ?? @"C:\autosec-hardening";
cmdText = cmdText.Replace("{autosec_path}", autoSecDir);
```

---

## ✅ 5. Bénéfices Opérationnels de la Synergie

1. **Expérience Administrateur Unifiée** : Un seul portail web pour le dépannage quotidien (réseau, comptes, matériel) et le durcissement de sécurité.
2. **Audit & Remédiation en 1 Clic** : Passage immédiat du constat d'une faille (ex: SMBv1 actif) à sa résolution sécurisée avec point de restauration.
3. **Preuve de Conformité Audit ANSSI / CIS** : Possibilité de générer en un clic le rapport PDF certifiant la progression de conformité avant/après.
