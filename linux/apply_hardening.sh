#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script d'Application Sécurisée du Durcissement
# ==============================================================================

set -e

# Vérifier les droits root
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Erreur : Ce script doit être exécuté avec les privilèges root (sudo ./apply_hardening.sh)."
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups/autosec_hardening_${TIMESTAMP}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Initialisation de la sauvegarde préalable dans : $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 1. Sauvegarde des configurations existantes
[ -f /etc/sysctl.conf ] && cp /etc/sysctl.conf "$BACKUP_DIR/"
[ -d /etc/sysctl.d ] && cp -r /etc/sysctl.d "$BACKUP_DIR/"
[ -f /etc/ssh/sshd_config ] && cp /etc/ssh/sshd_config "$BACKUP_DIR/"
[ -d /etc/ssh/sshd_config.d ] && cp -r /etc/ssh/sshd_config.d "$BACKUP_DIR/"
[ -d /etc/audit/rules.d ] && cp -r /etc/audit/rules.d "$BACKUP_DIR/"
[ -f /etc/fail2ban/jail.local ] && cp /etc/fail2ban/jail.local "$BACKUP_DIR/" || true

echo "[+] Sauvegardes effectuées avec succès."

# 2. Installation des paquets de sécurité requis
echo "[+] Vérification et installation des paquets (ufw, fail2ban, auditd, libpam-pwquality)..."
apt-get update -y
apt-get install -y ufw fail2ban auditd audispd-plugins libpam-pwquality unattended-upgrades

# 3. Application du Durcissement Sysctl
echo "[+] Application des paramètres de sécurité noyau (sysctl)..."
cp "$SCRIPT_DIR/configs/sysctl_security.conf" /etc/sysctl.d/99-security-hardening.conf
sysctl --system >/dev/null

# 4. Application du Durcissement SSH
echo "[+] Configuration durcie d'OpenSSH..."
mkdir -p /etc/ssh/sshd_config.d/
cp "$SCRIPT_DIR/configs/sshd_hardened.conf" /etc/ssh/sshd_config.d/99-hardened.conf

# Test de la syntaxe SSH avant redémarrage pour éviter de bloquer l'accès
if sshd -t; then
    echo "[+] Syntaxe SSH valide. Rechargement du service SSH..."
    systemctl restart ssh || systemctl restart sshd
else
    echo "[-] ERREUR de syntaxe dans la configuration SSH ! Annulation du module SSH..."
    rm -f /etc/ssh/sshd_config.d/99-hardened.conf
fi

# 5. Configuration et activation du Pare-feu (UFW)
echo "[+] Configuration des règles de pare-feu UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH Secure Port'
ufw --force enable

# 6. Configuration de Fail2ban
echo "[+] Déploiement de Fail2ban..."
cp "$SCRIPT_DIR/configs/jail.local" /etc/fail2ban/jail.local
systemctl restart fail2ban
systemctl enable fail2ban

# 7. Configuration d'Auditd
echo "[+] Déploiement des règles Auditd..."
cp "$SCRIPT_DIR/configs/audit.rules" /etc/audit/rules.d/audit.rules
augenrules --load || systemctl restart auditd
systemctl enable auditd

# 8. Mises à jour de sécurité automatiques
echo "[+] Activation des mises à jour de sécurité automatiques (Unattended-Upgrades)..."
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades

echo ""
echo "============================================================"
echo "[✓] DURCISSEMENT TERMINÉ AVEC SUCCÈS !"
echo "[i] Sauvegarde stockée dans : $BACKUP_DIR"
echo "[i] Vous pouvez exécuter './audit.sh' pour vérifier le nouveau score."
echo "============================================================"
