#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script d'Audit de Sécurité Docker (CIS Docker Benchmark)
# ==============================================================================

set -o pipefail

# Argument Parsing
EXPORT_JSON=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../reports/docker"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --json) EXPORT_JSON=1; shift ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Paramètre inconnu : $1"; exit 1 ;;
    esac
done

# Couleurs pour le terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
TOTAL=0

declare -a JSON_CHECKS=()

escape_json() {
    local string="$1"
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    echo -n "$string"
}

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "       AUTODEFENSE & AUDITOR - CIS DOCKER BENCHMARK         "
    echo "============================================================"
    echo -e "${NC}"
}

check_item() {
    local description="$1"
    local status="$2" # 0 for pass, 1 for fail
    local details="$3"
    local id="$4"
    local severity="$5"
    local remediation="$6"
    local category="Docker"

    case "$id" in
        DOCK-DAEMON-*) category="Démon Docker" ;;
        DOCK-RUN-*)    category="Sécurité Conteneurs" ;;
        DOCK-IMG-*)    category="Images & Supply Chain" ;;
    esac

    TOTAL=$((TOTAL + 1))
    local pass_fail_str="fail"
    if [ "$status" -eq 0 ]; then
        echo -e "  [${GREEN}CONFORME${NC}]  $description"
        PASSED=$((PASSED + 1))
        pass_fail_str="pass"
    else
        echo -e "  [${RED}VULNÉRABLE${NC}] $description"
        if [ -n "$details" ]; then
            echo -e "               ${YELLOW}↳ Détail : $details${NC}"
        fi
        FAILED=$((FAILED + 1))
    fi
    
    if [ "$EXPORT_JSON" -eq 1 ]; then
        local check_json="    {
      \"id\": \"$(escape_json "$id")\",
      \"category\": \"$(escape_json "$category")\",
      \"description\": \"$(escape_json "$description")\",
      \"status\": \"$pass_fail_str\",
      \"severity\": \"$(escape_json "$severity")\",
      \"remediation\": \"$(escape_json "$remediation")\"
    }"
        JSON_CHECKS+=("$check_json")
    fi
}

print_banner

# ------------------------------------------------------------------------------
# 1. Vérification de la disponibilité du moteur Docker
# ------------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}[!] Erreur : Docker n'est pas installé sur cette machine.${NC}"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] Avertissement : Le démon Docker n'est pas accessible. Exécutez avec 'sudo' ou vérifiez le service.${NC}\n"
fi

DAEMON_JSON="/etc/docker/daemon.json"
DOCKER_INFO=$(docker info --format '{{json .}}' 2>/dev/null || echo "{}")

# ------------------------------------------------------------------------------
# 2. Audit du Démon Docker (CIS 2.x)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[1] Audit de la Configuration du Démon Docker${NC}"
echo "------------------------------------------------------------"

# CIS 2.1: Pas de socket TCP non sécurisé
TCP_LISTEN=$(ps -ef 2>/dev/null | grep -E 'dockerd.*-H\s+tcp://' | grep -v grep | grep -v 'tlsverify' || true)
PORT_2375=$(ss -tlpn 2>/dev/null | grep ':2375 ' || netstat -tlpn 2>/dev/null | grep ':2375 ' || true)
if [ -z "$TCP_LISTEN" ] && [ -z "$PORT_2375" ]; then
    check_item "Socket TCP du démon non exposé sans TLS (Port 2375)" 0 "" \
               "DOCK-DAEMON-001" "critical" "Ne pas exposer l'API Docker sur tcp:// sans authentification mTLS (--tlsverify)"
else
    check_item "Socket TCP du démon non exposé sans TLS (Port 2375)" 1 "API Docker accessible en clair sur le réseau" \
               "DOCK-DAEMON-001" "critical" "Ne pas exposer l'API Docker sur tcp:// sans authentification mTLS (--tlsverify)"
fi

# CIS 2.2: Inter-container communication (icc=false)
ICC_CONFIG=1
if [ -f "$DAEMON_JSON" ]; then
    if grep -Eq '"icc"\s*:\s*false' "$DAEMON_JSON" 2>/dev/null; then
        ICC_CONFIG=0
    fi
fi
if [ "$ICC_CONFIG" -eq 0 ]; then
    check_item "Communication inter-conteneurs restreinte (icc: false)" 0 "" \
               "DOCK-DAEMON-002" "high" "Définir '\"icc\": false' dans /etc/docker/daemon.json"
else
    check_item "Communication inter-conteneurs restreinte (icc: false)" 1 "Tous les conteneurs du bridge par défaut peuvent dialoguer" \
               "DOCK-DAEMON-002" "high" "Définir '\"icc\": false' dans /etc/docker/daemon.json"
fi

# CIS 2.18: Interdire l'escalade de privilèges par défaut
NO_NEW_PRIV=1
if [ -f "$DAEMON_JSON" ]; then
    if grep -Eq '"no-new-privileges"\s*:\s*true' "$DAEMON_JSON" 2>/dev/null; then
        NO_NEW_PRIV=0
    fi
fi
if [ "$NO_NEW_PRIV" -eq 0 ]; then
    check_item "Empêcher l'escalade de privilèges par défaut (no-new-privileges: true)" 0 "" \
               "DOCK-DAEMON-003" "high" "Définir '\"no-new-privileges\": true' dans /etc/docker/daemon.json"
else
    check_item "Empêcher l'escalade de privilèges par défaut (no-new-privileges: true)" 1 "Les conteneurs peuvent obtenir de nouveaux privilèges via suid/sgid" \
               "DOCK-DAEMON-003" "high" "Définir '\"no-new-privileges\": true' dans /etc/docker/daemon.json"
fi

# CIS 2.14: Live restore activé
LIVE_RESTORE=1
if [ -f "$DAEMON_JSON" ]; then
    if grep -Eq '"live-restore"\s*:\s*true' "$DAEMON_JSON" 2>/dev/null; then
        LIVE_RESTORE=0
    fi
fi
if [ "$LIVE_RESTORE" -eq 0 ]; then
    check_item "Fonction Live-Restore activée (disponibilité lors des màj dockerd)" 0 "" \
               "DOCK-DAEMON-004" "medium" "Définir '\"live-restore\": true' dans /etc/docker/daemon.json"
else
    check_item "Fonction Live-Restore activée (disponibilité lors des màj dockerd)" 1 "Arrêt des conteneurs lors du redémarrage du démon" \
               "DOCK-DAEMON-004" "medium" "Définir '\"live-restore\": true' dans /etc/docker/daemon.json"
fi

# CIS 2.12: Limitation de la taille des logs
LOG_OPTS=1
if [ -f "$DAEMON_JSON" ]; then
    if grep -Eq '"max-size"' "$DAEMON_JSON" 2>/dev/null; then
        LOG_OPTS=0
    fi
fi
if [ "$LOG_OPTS" -eq 0 ]; then
    check_item "Rotation et limitation de taille des journaux configurées (max-size)" 0 "" \
               "DOCK-DAEMON-005" "medium" "Configurer 'log-opts': {'max-size': '10m', 'max-file': '3'} dans daemon.json"
else
    check_item "Rotation et limitation de taille des journaux configurées (max-size)" 1 "Risque de saturation du disque hôte par les logs conteneurs" \
               "DOCK-DAEMON-005" "medium" "Configurer 'log-opts': {'max-size': '10m', 'max-file': '3'} dans daemon.json"
fi

# ------------------------------------------------------------------------------
# 3. Audit des Conteneurs en Exécution (CIS 5.x)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[2] Audit de la Sécurité des Conteneurs (Runtime)${NC}"
echo "------------------------------------------------------------"

CONTAINER_IDS=$(docker ps -q 2>/dev/null || true)
CONTAINER_COUNT=$(echo "$CONTAINER_IDS" | grep -c . || echo 0)

if [ "$CONTAINER_COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}[i] Aucun conteneur en cours d'exécution. Audit des règles théoriques...${NC}"
fi

# CIS 5.4: Conteneurs privilégiés
PRIVILEGED_CONTAINERS=0
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    for cid in $CONTAINER_IDS; do
        IS_PRIV=$(docker inspect --format '{{.HostConfig.Privileged}}' "$cid" 2>/dev/null || echo "false")
        if [ "$IS_PRIV" = "true" ]; then
            PRIVILEGED_CONTAINERS=$((PRIVILEGED_CONTAINERS + 1))
        fi
    done
fi
if [ "$PRIVILEGED_CONTAINERS" -eq 0 ]; then
    check_item "Aucun conteneur en mode Privilégié (--privileged=false)" 0 "" \
               "DOCK-RUN-001" "critical" "Ne jamais utiliser le drapeau --privileged qui donne les droits root réels de l'hôte"
else
    check_item "Aucun conteneur en mode Privilégié (--privileged=false)" 1 "$PRIVILEGED_CONTAINERS conteneur(s) privilégié(s) détecté(s)" \
               "DOCK-RUN-001" "critical" "Supprimer le drapeau --privileged et accorder uniquement les capacités requises"
fi

# CIS 4.1: Utilisateur non-root dans les conteneurs
ROOT_CONTAINERS=0
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    for cid in $CONTAINER_IDS; do
        USER_VAL=$(docker inspect --format '{{.Config.User}}' "$cid" 2>/dev/null || echo "")
        if [ -z "$USER_VAL" ] || [ "$USER_VAL" = "0" ] || [ "$USER_VAL" = "root" ]; then
            ROOT_CONTAINERS=$((ROOT_CONTAINERS + 1))
        fi
    done
fi
if [ "$ROOT_CONTAINERS" -eq 0 ] && [ "$CONTAINER_COUNT" -gt 0 ]; then
    check_item "Conteneurs exécutés avec un utilisateur non-root dédié" 0 "" \
               "DOCK-RUN-002" "critical" "Spécifier 'USER <uid>' dans le Dockerfile ou exécuter avec --user <uid>:<gid>"
elif [ "$CONTAINER_COUNT" -eq 0 ]; then
    check_item "Conteneurs exécutés avec un utilisateur non-root dédié" 0 "" \
               "DOCK-RUN-002" "critical" "Spécifier 'USER <uid>' dans le Dockerfile ou exécuter avec --user <uid>:<gid>"
else
    check_item "Conteneurs exécutés avec un utilisateur non-root dédié" 1 "$ROOT_CONTAINERS conteneur(s) tournant sous l'UID 0 (root)" \
               "DOCK-RUN-002" "critical" "Spécifier 'USER <uid>' dans le Dockerfile ou exécuter avec --user <uid>:<gid>"
fi

# CIS 5.10 & 5.11: Limites de ressources CPU et Mémoire
UNLIMITED_CONTAINERS=0
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    for cid in $CONTAINER_IDS; do
        MEM_VAL=$(docker inspect --format '{{.HostConfig.Memory}}' "$cid" 2>/dev/null || echo "0")
        CPUS_VAL=$(docker inspect --format '{{.HostConfig.NanoCpus}}' "$cid" 2>/dev/null || echo "0")
        if [ "$MEM_VAL" -eq 0 ] || [ "$CPUS_VAL" -eq 0 ]; then
            UNLIMITED_CONTAINERS=$((UNLIMITED_CONTAINERS + 1))
        fi
    done
fi
if [ "$UNLIMITED_CONTAINERS" -eq 0 ] && [ "$CONTAINER_COUNT" -gt 0 ]; then
    check_item "Limites de ressources (RAM & CPU) configurées (Anti-DoS hôte)" 0 "" \
               "DOCK-RUN-003" "high" "Définir --memory et --cpus pour chaque conteneur"
elif [ "$CONTAINER_COUNT" -eq 0 ]; then
    check_item "Limites de ressources (RAM & CPU) configurées (Anti-DoS hôte)" 0 "" \
               "DOCK-RUN-003" "high" "Définir --memory et --cpus pour chaque conteneur"
else
    check_item "Limites de ressources (RAM & CPU) configurées (Anti-DoS hôte)" 1 "$UNLIMITED_CONTAINERS conteneur(s) sans plafond mémoire ou CPU" \
               "DOCK-RUN-003" "high" "Définir --memory (ex: --memory=512m) et --cpus (ex: --cpus=1.0) sur les conteneurs"
fi

# CIS 5.12: Système de fichiers racine en lecture seule
NON_READONLY_FS=0
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    for cid in $CONTAINER_IDS; do
        IS_RO=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$cid" 2>/dev/null || echo "false")
        if [ "$IS_RO" != "true" ]; then
            NON_READONLY_FS=$((NON_READONLY_FS + 1))
        fi
    done
fi
if [ "$NON_READONLY_FS" -eq 0 ] && [ "$CONTAINER_COUNT" -gt 0 ]; then
    check_item "Système de fichiers racine monté en lecture seule (--read-only)" 0 "" \
               "DOCK-RUN-004" "medium" "Lancer les conteneurs avec le paramètre --read-only pour éviter l'altération de fichiers"
elif [ "$CONTAINER_COUNT" -eq 0 ]; then
    check_item "Système de fichiers racine monté en lecture seule (--read-only)" 0 "" \
               "DOCK-RUN-004" "medium" "Lancer les conteneurs avec le paramètre --read-only pour éviter l'altération de fichiers"
else
    check_item "Système de fichiers racine monté en lecture seule (--read-only)" 1 "$NON_READONLY_FS conteneur(s) avec système de fichiers racine modifiable" \
               "DOCK-RUN-004" "medium" "Lancer les conteneurs avec --read-only et monter des volumes temporaires en tmpfs pour l'écriture"
fi

# ------------------------------------------------------------------------------
# 4. Images & Chaîne d'Approvisionnement (CIS 4.x)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[3] Audit des Images & Signature (Supply Chain)${NC}"
echo "------------------------------------------------------------"

# CIS 4.5: Content Trust (Docker Content Trust activé)
if [ "$DOCKER_CONTENT_TRUST" = "1" ]; then
    check_item "Signature des images et Content Trust actifs (DOCKER_CONTENT_TRUST=1)" 0 "" \
               "DOCK-IMG-001" "high" "Exporter DOCKER_CONTENT_TRUST=1 dans l'environnement (/etc/environment)"
else
    check_item "Signature des images et Content Trust actifs (DOCKER_CONTENT_TRUST=1)" 1 "Images non vérifiées cryptographiquement au pull" \
               "DOCK-IMG-001" "high" "Exporter 'export DOCKER_CONTENT_TRUST=1' dans /etc/environment ou le profil shell"
fi

# ------------------------------------------------------------------------------
# 5. Calcul du Score Global
# ------------------------------------------------------------------------------
SCORE=$(( (PASSED * 100) / TOTAL ))

echo -e "\n============================================================"
echo -e "${BOLD}RÉSULTATS DE L'AUDIT SÉCURITÉ DOCKER :${NC}"
echo -e "Tests réussis : ${GREEN}${PASSED} / ${TOTAL}${NC}"
echo -e "Tests échoués : ${RED}${FAILED} / ${TOTAL}${NC}"

if [ "$SCORE" -ge 80 ]; then
    echo -e "Score global  : ${GREEN}${BOLD}${SCORE}% (Niveau de sécurité ÉLEVÉ)${NC}"
elif [ "$SCORE" -ge 50 ]; then
    echo -e "Score global  : ${YELLOW}${BOLD}${SCORE}% (Niveau de sécurité MOYEN - Durcissement requis)${NC}"
else
    echo -e "Score global  : ${RED}${BOLD}${SCORE}% (Niveau de sécurité CRITIQUE - Vulnérabilités multiples)${NC}"
fi
echo "============================================================"

# ------------------------------------------------------------------------------
# 6. Export JSON
# ------------------------------------------------------------------------------
if [ "$EXPORT_JSON" -eq 1 ]; then
    mkdir -p "$OUTPUT_DIR"
    TIMESTAMP=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
    HOSTNAME_VAL=$(hostname 2>/dev/null || echo "unknown")
    DOCKER_VER=$(docker --version 2>/dev/null || echo "Docker Engine (inconnu)")
    
    JSON_FILE="${OUTPUT_DIR}/audit_docker_${HOSTNAME_VAL}_$(date +%Y%m%d_%H%M%S).json"
    
    CHECKS_JOINED=$(IFS=, ; echo "${JSON_CHECKS[*]}")
    
    cat <<EOF > "$JSON_FILE"
{
  "tool": "autosec-hardening",
  "version": "1.1.0",
  "timestamp": "$TIMESTAMP",
  "hostname": "$(escape_json "$HOSTNAME_VAL")",
  "os": "docker",
  "os_details": "$(escape_json "$DOCKER_VER")",
  "score": $SCORE,
  "passed": $PASSED,
  "failed": $FAILED,
  "total": $TOTAL,
  "checks": [
$CHECKS_JOINED
  ]
}
EOF
    echo -e "\n[+] Rapport d'audit Docker exporté vers : $JSON_FILE"
fi
