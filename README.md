# 🛡️ AutoSec-Hardener : Framework Multi-OS de Durcissement & d'Audit de Sécurité

> **Boîte à outils opérationnelle d'audit et de sécurisation automatisée pour serveurs Linux (Debian / Ubuntu) et Windows Server / Clients.**  
> Aligné sur les recommandations de l'**ANSSI** et les **CIS Benchmarks**.

---

## 📌 1. Présentation du Projet

### Le Constat
Par défaut, une installation classique d'un système comporte plusieurs faiblesses critiques exploitables :
* **Sous Linux :** Connexion directe avec le compte `root`, protocoles réseau vulnérables au *SYN Flood DoS*, *IP Spoofing*, et absence de pare-feu actif par défaut.
* **Sous Windows :** Protocoles d'écoute hérités vulnérables (**SMBv1**, **LLMNR** permettant l'interception de hashs par *Responder*), absence de signature SMB (vulnérable au *SMB Relay*), et mémoire **LSASS** non protégée contre le vol de mots de passe par *Mimikatz*.

### La Solution
**AutoSec-Hardener** est organisé en modules indépendants (**Linux** et **Windows**) pour :
1. **Auditer sans impacter la production** avec calcul d'un score de conformité sur 100%.
2. **Sauvegarder automatiquement** les états de configuration (fichiers sous Linux, registre sous Windows).
3. **Appliquer les durcissements recommandés par l'ANSSI / CIS**.
4. **Permettre un retour arrière (Rollback) immédiat**.
5. **Visualiser les résultats** via un dashboard web interactif avec historique des scores.

---

## 📁 2. Architecture & Organisation du Projet

Le projet est proprement structuré par environnement :

```
autosec-hardening/
├── 🐧 linux/
│   ├── configs/                 # Modèles de configuration durcis
│   │   ├── sysctl_security.conf # Paramètres noyau (Anti-Spoofing, Anti-SYN flood, ASLR)
│   │   ├── sshd_hardened.conf   # Configuration OpenSSH haute sécurité
│   │   ├── audit.rules          # Règles Auditd (surveillance /etc/shadow, /etc/passwd)
│   │   └── jail.local           # Règles Fail2ban anti-brute-force
│   ├── ansible/                 # Déploiement à l'échelle
│   │   ├── playbook.yml         # Playbook Ansible multi-serveurs
│   │   └── inventory.ini        # Inventaire des machines
│   ├── audit.sh                 # Script d'audit de sécurité Linux (Score sur 100%)
│   ├── apply_hardening.sh       # Script d'application (avec backup automatique)
│   └── rollback.sh              # Script de restauration Linux
│
├── 🪟 windows/
│   ├── Audit-Security.ps1       # Audit PowerShell & Score de conformité Windows
│   ├── Apply-Hardening.ps1      # Durcissement Windows & Sauvegarde Registre
│   └── Rollback-Security.ps1    # Restauration Windows
│
├── 🐳 docker/
│   ├── configs/                 # Modèles de configuration durcis
│   │   └── daemon.json          # Paramètres durcis daemon (CIS 2.x)
│   ├── audit_docker.sh          # Audit de sécurité Docker (Score sur 100% & export JSON)
│   ├── apply_hardening.sh       # Durcissement Docker & sauvegarde automatique
│   └── rollback.sh              # Restauration Docker
│
├── 📊 dashboard/                # Dashboard web de visualisation
│   ├── index.html               # Interface principale (Tailwind + Chart.js)
│   ├── css/styles.css           # Styles personnalisés (glassmorphism, dark mode)
│   └── js/
│       ├── app.js               # Logique applicative (chargement JSON, filtres, historique)
│       └── charts.js            # Graphiques Chart.js (jauge de score, historique)
│
├── 🔧 tools/                    # Outils d'analyse et de reporting
│   ├── compare_reports.sh       # Comparaison Avant/Après Linux & export PDF
│   └── Compare-Reports.ps1      # Comparaison Avant/Après Windows & export PDF
│
├── 📄 reports/                  # Rapports d'audit JSON générés automatiquement
│   ├── linux/                   # Rapports Linux horodatés
│   ├── windows/                 # Rapports Windows horodatés
│   ├── docker/                  # Rapports Docker horodatés
│   └── comparisons/             # Rapports comparatifs Markdown et PDF
│
├── 🔗 integrations/             # Connecteurs et ponts d'intégration
│   └── it-command-hub/          # Module & commandes pour IT Support Command Hub
│
└── README.md                    # Documentation complète
```

---

## 🛡️ 3. Matrice de Sécurité Multi-OS

| Périmètre | Mesure Technique | Risque / Attaque Bloquée |
| :--- | :--- | :--- |
| **🐧 Linux — SSH** | Clés seules, `PermitRootLogin no`, Ciphers forts | Attaques Brute-force & vol d'accès |
| **🐧 Linux — Réseau** | `tcp_syncookies = 1`, `rp_filter = 1`, `accept_redirects = 0` | Déni de service (SYN Flood), IP Spoofing, MitM |
| **🐧 Linux — IDS / Pare-feu**| UFW en politique `DROP`, Fail2ban ban 24h, Auditd | Mouvements latéraux, altération système |
| **🪟 Windows — Réseau** | Désactivation SMBv1, désactivation LLMNR, NetBIOS | Attaques type WannaCry / EternalBlue, empoisonnement *Responder* |
| **🪟 Windows — SMB** | Activation de la signature SMB obligatoire | Attaques *SMB Relay* |
| **🪟 Windows — Identité** | NTLMv2 forcé (Niveau 5), LSA Protection (`RunAsPPL = 1`) | Extraction de mots de passe en mémoire par *Mimikatz* |
| **🪟 Windows — Logs** | Pare-feu Defender actif 3 profils, ScriptBlock Logging (4104) | Détection d'attaques PowerShell obfusquées |
| **🐳 Docker — Démon** | `icc: false`, `no-new-privileges: true`, `live-restore: true`, logs limités | Mouvements latéraux inter-conteneurs, escalade de privilèges |
| **🐳 Docker — Runtime** | Interdiction `--privileged`, conteneurs non-root, limites RAM/CPU, `--read-only` | Compromission de l'hôte, DoS ressource, altération binaire |
| **🐳 Docker — Supply Chain** | `DOCKER_CONTENT_TRUST = 1` (Signature cryptographique obligatoire) | Exécution d'images empoisonnées ou altérées |

---

## 🚀 4. Guide d'Utilisation

### 🐧 Module Linux (Ubuntu Server / Debian)

```bash
# 1. Se positionner dans le dossier linux
cd autosec-hardening/linux

# 2. Rendre exécutable et lancer l'audit initial
chmod +x *.sh
sudo ./audit.sh

# 3. Appliquer le durcissement (Sauvegarde dans /var/backups/)
sudo ./apply_hardening.sh

# 4. Vérifier le score à 100%
sudo ./audit.sh

# 5. (Optionnel) Restaurer en cas de besoin :
sudo ./rollback.sh
```

**Déploiement avec Ansible :**
```bash
cd autosec-hardening/linux/ansible
ansible-playbook -i inventory.ini playbook.yml -k -K
```

---

### 🪟 Module Windows (Windows Server & Windows 10/11)

Ouvrez une console **PowerShell en tant qu'Administrateur** :

```powershell
# 1. Se positionner dans le dossier windows
cd autosec-hardening\windows

# 2. Lancer l'audit initial
powershell -ExecutionPolicy Bypass -File .\Audit-Security.ps1

# 3. Appliquer le durcissement sécurisé (Sauvegarde dans C:\WindowsBackups_AutoSec_*)
powershell -ExecutionPolicy Bypass -File .\Apply-Hardening.ps1

# 4. Vérifier le nouveau score de sécurité
powershell -ExecutionPolicy Bypass -File .\Audit-Security.ps1

# 5. (Optionnel) Restaurer en cas de besoin :
powershell -ExecutionPolicy Bypass -File .\Rollback-Security.ps1
```

---

### 🐳 Module Docker (CIS Docker Benchmark)

```bash
# 1. Se positionner dans le dossier docker
cd autosec-hardening/docker

# 2. Rendre exécutable et lancer l'audit initial
chmod +x *.sh
sudo ./audit_docker.sh

# 3. Lancer l'audit avec export JSON compatible dashboard
sudo ./audit_docker.sh --json

# 4. Appliquer le durcissement CIS (Sauvegarde automatique préalable)
sudo ./apply_hardening.sh

# 5. Vérifier le nouveau score de sécurité
sudo ./audit_docker.sh

# 6. (Optionnel) Restaurer la configuration antérieure :
sudo ./rollback.sh
```

---

## 📊 5. Dashboard de Visualisation & Export JSON

### Export JSON des résultats d'audit

Les scripts d'audit peuvent exporter leurs résultats au format **JSON structuré**, compatible avec le dashboard de visualisation.

**Linux :**
```bash
# Audit avec export JSON (le rapport terminal reste identique)
sudo ./audit.sh --json

# Spécifier un dossier de sortie personnalisé
sudo ./audit.sh --json --output-dir /chemin/personnalise/
```

**Windows :**
```powershell
# Audit avec export JSON
powershell -ExecutionPolicy Bypass -File .\Audit-Security.ps1 -JsonExport

# Spécifier un dossier de sortie personnalisé
powershell -ExecutionPolicy Bypass -File .\Audit-Security.ps1 -JsonExport -OutputDir "C:\MesRapports"
```

Les fichiers JSON sont automatiquement sauvegardés dans `reports/linux/` ou `reports/windows/` avec un nommage horodaté : `audit_<hostname>_<YYYYMMDD_HHMMSS>.json`.

### Format JSON de sortie

```json
{
  "tool": "autosec-hardening",
  "version": "1.1.0",
  "timestamp": "2026-09-07T13:00:00+02:00",
  "hostname": "srv-prod-01",
  "os": "linux",
  "os_details": "Ubuntu 22.04.3 LTS",
  "score": 70,
  "passed": 7,
  "failed": 3,
  "total": 10,
  "checks": [
    {
      "id": "SSH-001",
      "category": "SSH",
      "description": "Connexion directe du compte Root désactivée",
      "status": "pass",
      "severity": "critical",
      "remediation": "Définir PermitRootLogin no dans /etc/ssh/sshd_config"
    }
  ]
}
```

### Dashboard Web

Le dashboard est une application web légère (HTML/JS/Tailwind, **zéro dépendance serveur**) qui lit les fichiers JSON d'audit et affiche :

- 📊 **Jauge de score** avec code couleur (vert ≥80% / jaune ≥50% / rouge <50%)
- 📋 **Détail de chaque contrôle** : statut conforme/vulnérable, sévérité, remédiation recommandée
- 📈 **Historique des scores** dans le temps (stocké dans le navigateur via `localStorage`)

**Utilisation :**
```bash
# Ouvrir le dashboard dans votre navigateur
# Linux :
xdg-open dashboard/index.html

# macOS :
open dashboard/index.html

# Windows :
start dashboard\index.html
```

Puis **glissez-déposez** un fichier JSON d'audit ou cliquez sur « Charger un rapport ».

Le dashboard supporte le **mode sombre/clair** et est visuellement cohérent avec [IT-Command-Hub](https://github.com/primemarafa/it-command-hub).

---

## 📈 6. Rapports Comparatifs Avant / Après (Markdown & PDF)

Pour mesurer objectivement l'impact d'un durcissement (`apply_hardening.sh` ou `Apply-Hardening.ps1`), des scripts dédiés comparent deux exports JSON d'audit (ex: run initial vs run post-durcissement).

Ils analysent :
- L'**évolution du score global** (ex: `40% → 90% (+50%)`)
- La transition du **niveau de sécurité** (ex: `CRITIQUE → ÉLEVÉ`)
- La liste précise des **contrôles corrigés**
- La liste des **contrôles restant à corriger** avec leur remédiation recommandée
- Les éventuelles **régressions de sécurité**

### Utilisation sous Linux (Bash)

```bash
# Générer le rapport Markdown comparatif
./tools/compare_reports.sh reports/linux/audit_avant.json reports/linux/audit_apres.json

# Générer le rapport Markdown ET l'exporter en PDF
./tools/compare_reports.sh reports/linux/audit_avant.json reports/linux/audit_apres.json --pdf
```

*(L'export PDF sous Linux s'appuie sur `pandoc` ou, en fallback automatique, sur un navigateur headless comme `chromium` / `google-chrome`)*

### Utilisation sous Windows (PowerShell)

```powershell
# Générer le rapport Markdown comparatif
powershell -ExecutionPolicy Bypass -File .\tools\Compare-Reports.ps1 `
    -Before .\reports\windows\audit_avant.json `
    -After .\reports\windows\audit_apres.json

# Générer le rapport Markdown ET l'exporter directement en PDF
powershell -ExecutionPolicy Bypass -File .\tools\Compare-Reports.ps1 `
    -Before .\reports\windows\audit_avant.json `
    -After .\reports\windows\audit_apres.json `
    -Pdf
```

*(L'export PDF sous Windows convertit le rapport avec mise en page soignée via `msedge.exe` headless nativement présent sur Windows 10/11/Server ou via `pandoc` si installé).*

Tous les rapports générés sont stockés dans `reports/comparisons/` au format `.md` et `.pdf`.

---

## 🔗 7. Intégration avec IT-Command-Hub

**AutoSec-Hardener** est conçu pour s'intégrer nativement dans [IT Support Command Hub](https://github.com/primemarafa/it-command-hub) (interface web moderne + agent compagnon C# `CompanionServer.exe` sur le port local `8484`).

### Deux modes d'intégration disponibles :

1. **Module de Commandes 1-Clic (`data/commands.js`)** :
   - Ajoutez la catégorie `Sécurité & Hardening (ANSSI)` dans le volet de navigation.
   - Intégrez les 6 cartes prêtes à l'emploi fournies dans [`integrations/it-command-hub/autosec-commands-fragment.js`](./integrations/it-command-hub/autosec-commands-fragment.js).
   - Déclenchez l'audit, le durcissement ou le rollback en 1-clic avec élévation UAC automatique via l'agent C#.
   - Exécutez le **Playbook automatisé** enchaînant l'audit initial, le backup, le durcissement et la validation finale.

2. **Onglet Dédié Embarqué (Dashboard AutoSec)** :
   - Intégrez le dashboard interactif dans un onglet `[ 🛡️ AutoSec Dashboard ]` au sein du header d'IT-Command-Hub.
   - Visualisez la jauge de conformité, le détail des contrôles et l'historique sans quitter la console d'administration.

Consultez le guide complet : [`integrations/it-command-hub/INTEGRATION_GUIDE.md`](./integrations/it-command-hub/INTEGRATION_GUIDE.md).

---

## 👤 Auteur & Licence
* **Auteur :** Moustapha Marafa ([@primemarafa](https://github.com/primemarafa))
* **Spécialité :** Administration Système, Réseau et Sécurité
* **Licence :** MIT
