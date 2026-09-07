#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script de Rollback Docker (Restauration)
# ==============================================================================

set -e

# Vérification des privilèges root
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Erreur : Ce script doit être exécuté avec les privilèges root (sudo ./rollback.sh)."
    exit 1
fi

echo "[*] Recherche de la dernière sauvegarde de durcissement Docker..."
LAST_BACKUP=$(ls -td /var/backups/autosec_docker_hardening_* 2>/dev/null | head -n 1)

if [ -z "$LAST_BACKUP" ]; then
    echo "[-] Aucune sauvegarde automatique trouvée dans /var/backups/autosec_docker_hardening_*"
    echo "[!] Restauration manuelle requise."
    exit 1
fi

echo "[+] Dernière sauvegarde identifiée : $LAST_BACKUP"
read -p "[?] Confirmez-vous la restauration de cet état ? (o/N) : " CONFIRM
if [[ ! "$CONFIRM" =~ ^[oOyY]$ ]]; then
    echo "[-] Opération annulée par l'utilisateur."
    exit 0
fi

# 1. Restauration daemon.json
if [ -f "$LAST_BACKUP/daemon.json" ]; then
    echo "[+] Restauration de /etc/docker/daemon.json..."
    cp "$LAST_BACKUP/daemon.json" /etc/docker/daemon.json
else
    echo "[-] Pas d'ancien daemon.json sauvegardé. Suppression du fichier déployé..."
    rm -f /etc/docker/daemon.json
fi

# 2. Nettoyage DOCKER_CONTENT_TRUST
if [ -f "$LAST_BACKUP/environment" ]; then
    echo "[+] Restauration de /etc/environment..."
    cp "$LAST_BACKUP/environment" /etc/environment
else
    sed -i '/DOCKER_CONTENT_TRUST=1/d' /etc/environment 2>/dev/null || true
fi

# 3. Redémarrage Docker
echo "[+] Redémarrage du service Docker..."
systemctl daemon-reload
systemctl restart docker

echo ""
echo "============================================================"
echo "[✓] RESTAURATION DOCKER TERMINÉE AVEC SUCCÈS !"
echo "[i] L'état antérieur au durcissement a été rétabli."
echo "============================================================"
