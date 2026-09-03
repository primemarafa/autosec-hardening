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
**AutoSec-Hardener** est organisé en deux modules indépendants (**Linux** et **Windows**) pour :
1. **Auditer sans impacter la production** avec calcul d'un score de conformité sur 100%.
2. **Sauvegarder automatiquement** les états de configuration (fichiers sous Linux, registre sous Windows).
3. **Appliquer les durcissements recommandés par l'ANSSI / CIS**.
4. **Permettre un retour arrière (Rollback) immédiat**.

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

## 👤 Auteur & Licence
* **Auteur :** Moustapha Marafa ([@primemarafa](https://github.com/primemarafa))
* **Spécialité :** Administration Système, Réseau et Sécurité
* **Licence :** MIT
