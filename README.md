# 🛡️ AutoSec-Hardener : Framework de Durcissement & d'Audit de Sécurité

> **Guide Opérationnel pour Administrateurs Système, Réseau et Sécurité**  
> Aligné sur les recommandations de l'**ANSSI** et les **CIS Benchmarks**.

---

## 🎯 Objectif du Projet
Ce projet fournit une boîte à outils complète, modulaire et prête à l'emploi pour auditer, sécuriser et maintenir en conformité des serveurs Linux (Debian, Ubuntu, etc.) sans risque de blocage opérationnel.

---

## 📁 Structure du Projet

```
autosec-hardening/
├── configs/
│   ├── sysctl_security.conf     # Durcissement réseau (Anti-Spoofing, Anti-SYN flood, ASLR)
│   ├── sshd_hardened.conf       # Sécurisation OpenSSH (clés seules, ciphers forts, root désactivé)
│   ├── audit.rules              # Règles Auditd pour la traçabilité des fichiers critiques
│   └── jail.local               # Configuration Fail2ban anti-brute-force
├── audit.sh                     # Script d'audit et calcul du score de conformité
├── apply_hardening.sh           # Déploiement automatique avec sauvegarde préalable
├── rollback.sh                  # Restauration instantanée de la configuration antérieure
├── playbook.yml                 # Version Ansible pour déploiement multi-serveurs
├── inventory.ini                # Inventaire des machines pour Ansible
└── README.md                    # Documentation complète
```

---

## 🧪 Comment Tester dans un Environnement Local (Laboratoire)

### Option A : Avec une Machine Virtuelle (VirtualBox / VMware)
1. Installez une VM avec **Ubuntu Server** ou **Debian**.
2. Configurez la carte réseau en mode **Accès par pont (Bridged)** ou **Réseau privé hôte (Host-Only)**.
3. Copiez le dossier `autosec-hardening` sur votre VM :
   ```bash
   scp -r autosec-hardening/ utilisateur@<IP_VM>:~/
   ```
4. Connectez-vous en SSH à votre VM :
   ```bash
   ssh utilisateur@<IP_VM>
   cd autosec-hardening
   ```

---

## 🚀 Guide d'Utilisation

### Étape 1 : Exécuter l'Audit Initial (État des lieux)
Avant toute modification, mesurez le niveau de sécurité actuel :
```bash
sudo chmod +x *.sh
sudo ./audit.sh
```
*Le script affichera la liste des éléments vulnérables et un score de sécurité initial (souvent inférieur à 40%).*

---

### Étape 2 : Appliquer le Durcissement
Appliquez les mesures de sécurité en une seule commande (avec création automatique d'un point de sauvegarde dans `/var/backups/`) :
```bash
sudo ./apply_hardening.sh
```

---

### Étape 3 : Vérifier le Nouveau Score de Sécurité
Relancez l'audit pour constater l'impact :
```bash
sudo ./audit.sh
```
*Le score passera à **100%** de conformité.*

---

### Étape 4 (Optionnelle) : Restauration en cas de besoin (Rollback)
Si vous souhaitez annuler les modifications et revenir à l'état initial :
```bash
sudo ./rollback.sh
```

---

## 🤖 Utilisation avec Ansible (Déploiement à l'échelle)
Si vous gérez plusieurs serveurs ou souhaitez automatiser via Ansible :
```bash
# Modifier l'adresse IP dans inventory.ini
nano inventory.ini

# Lancer le playbook
ansible-playbook -i inventory.ini playbook.yml -k -K
```

---

## 🛡️ Matrice de Sécurité & Protections Appliquées

| Composant | Risque Atténué | Mesure Technique |
| :--- | :--- | :--- |
| **OpenSSH** | Brute-force & Vol d'identifiants | Mots de passe désactivés, clés SSH obligatoires, `PermitRootLogin no`, chiffrement moderne |
| **Kernel / Sysctl** | DoS & Man-in-the-Middle | `tcp_syncookies = 1`, `rp_filter = 1`, `accept_redirects = 0` |
| **Mémoire (ASLR)** | Exploitation de Buffer Overflow | `kernel.randomize_va_space = 2` |
| **Pare-feu (UFW)** | Exposition de services non sollicités | Politique par défaut `DROP`, seuls les flux indispensables autorisés |
| **Fail2ban** | Attaques automatisées par dictionnaire | Bannissement temporaire (IP jail) après 3 échecs |
| **Auditd** | Altération discrète de configurations | Traçabilité des écritures sur `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` |
| **Mises à jour** | Failles non corrigées (CVEs) | Déploiement automatique des correctifs de sécurité (`unattended-upgrades`) |
