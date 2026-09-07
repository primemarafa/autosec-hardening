#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Application du Durcissement Docker (CIS Benchmark)
# ==============================================================================

set -e

# Vérification des privilèges root
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Erreur : Ce script doit être exécuté avec les privilèges root (sudo ./apply_hardening.sh)."
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups/autosec_docker_hardening_${TIMESTAMP}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Initialisation de la sauvegarde préalable dans : $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 1. Sauvegarde des configurations existantes
[ -f /etc/docker/daemon.json ] && cp /etc/docker/daemon.json "$BACKUP_DIR/"
[ -f /etc/environment ] && cp /etc/environment "$BACKUP_DIR/"

echo "[+] Sauvegardes effectuées avec succès."

# 2. Déploiement de la configuration durcie daemon.json
echo "[+] Application de la configuration durcie /etc/docker/daemon.json..."
mkdir -p /etc/docker/

# Fusion ou copie propre du daemon.json
cp "$SCRIPT_DIR/configs/daemon.json" /etc/docker/daemon.json

# 3. Activation de Docker Content Trust dans l'environnement
echo "[+] Activation de Docker Content Trust (DOCKER_CONTENT_TRUST=1)..."
if ! grep -q "DOCKER_CONTENT_TRUST=1" /etc/environment 2>/dev/null; then
    echo "DOCKER_CONTENT_TRUST=1" >> /etc/environment
fi
export DOCKER_CONTENT_TRUST=1

# 4. Redémarrage et validation du service Docker
echo "[+] Rechargement et redémarrage du service Docker..."
systemctl daemon-reload
systemctl restart docker

echo ""
echo "============================================================"
echo "[✓] DURCISSEMENT DOCKER APPLIQUÉ AVEC SUCCÈS !"
echo "[i] Sauvegarde stockée dans : $BACKUP_DIR"
echo "[i] Vous pouvez exécuter './audit_docker.sh' pour valider le nouveau score."
echo "============================================================"
