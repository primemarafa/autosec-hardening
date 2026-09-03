#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script de Restauration (Rollback)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Erreur : Ce script doit être exécuté avec les privilèges root (sudo ./rollback.sh)."
    exit 1
fi

# Trouver la dernière sauvegarde créée
LAST_BACKUP=$(ls -td /var/backups/autosec_hardening_* 2>/dev/null | head -n 1)

if [ -z "$LAST_BACKUP" ]; then
    echo "[-] Aucune sauvegarde trouvée dans /var/backups/."
    exit 1
fi

echo "[?] Dernière sauvegarde détectée : $LAST_BACKUP"
read -p "Confirmez-vous la restauration de cette sauvegarde ? (o/N) : " CONFIRM

if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
    echo "[+] Restauration des configurations..."
    
    # Restauration sysctl
    rm -f /etc/sysctl.d/99-security-hardening.conf
    [ -f "$LAST_BACKUP/sysctl.conf" ] && cp "$LAST_BACKUP/sysctl.conf" /etc/
    sysctl --system >/dev/null

    # Restauration SSH
    rm -f /etc/ssh/sshd_config.d/99-hardened.conf
    [ -f "$LAST_BACKUP/sshd_config" ] && cp "$LAST_BACKUP/sshd_config" /etc/ssh/
    systemctl restart ssh || systemctl restart sshd

    # Restauration Auditd
    rm -f /etc/audit/rules.d/audit.rules
    systemctl restart auditd || true

    # Restauration Fail2ban
    rm -f /etc/fail2ban/jail.local
    systemctl restart fail2ban || true

    echo "[✓] Restauration terminée avec succès !"
else
    echo "[-] Annulation de la restauration."
fi
