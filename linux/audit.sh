#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script d'Audit de Conformité Sécurité (ANSSI / CIS)
# ==============================================================================

set -o pipefail

# Argument Parsing
EXPORT_JSON=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../reports/linux"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --json) EXPORT_JSON=1; shift ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

# Couleurs pour le terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}${BOLD}"
    echo "============================================================"
    echo "       AUTODEFENSE & SECURITY AUDITOR (ANSSI / CIS)         "
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
    local category="Uncategorized"

    case "$id" in
        SSH-*) category="SSH" ;;
        NET-*) category="Réseau & Noyau" ;;
        FW-*) category="Pare-feu & Détection" ;;
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

# ------------------------------------------------------------------------------
# 1. Vérification des Privilèges
# ------------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}[!] Avertissement : Exécutez ce script avec 'sudo' pour auditer tous les composants.${NC}\n"
fi

print_banner

# ------------------------------------------------------------------------------
# 2. Audit SSH
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[1] Audit de la configuration OpenSSH${NC}"
echo "------------------------------------------------------------"

# Root login
if grep -Eq "^\s*PermitRootLogin\s+no" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
    check_item "Connexion directe du compte Root désactivée" 0 "" "SSH-001" "critical" "Définir PermitRootLogin no dans /etc/ssh/sshd_config"
else
    check_item "Connexion directe du compte Root désactivée" 1 "PermitRootLogin n'est pas configuré sur 'no'" "SSH-001" "critical" "Définir PermitRootLogin no dans /etc/ssh/sshd_config"
fi

# Password auth
if grep -Eq "^\s*PasswordAuthentication\s+no" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
    check_item "Authentification par mot de passe désactivée (Clés obligatoires)" 0 "" "SSH-002" "high" "Désactiver PasswordAuthentication et configurer des clés SSH"
else
    check_item "Authentification par mot de passe désactivée (Clés obligatoires)" 1 "PasswordAuthentication est autorisé ou non défini" "SSH-002" "high" "Désactiver PasswordAuthentication et configurer des clés SSH"
fi

# MaxAuthTries
if grep -Eq "^\s*MaxAuthTries\s+[1-3]" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
    check_item "Nombre maximal de tentatives d'authentification limité (<=3)" 0 "" "SSH-003" "medium" "Définir MaxAuthTries à 3 ou moins dans sshd_config"
else
    check_item "Nombre maximal de tentatives d'authentification limité (<=3)" 1 "MaxAuthTries supérieur à 3 ou non configuré" "SSH-003" "medium" "Définir MaxAuthTries à 3 ou moins dans sshd_config"
fi

# ------------------------------------------------------------------------------
# 3. Audit Noyau & Réseau (sysctl)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[2] Audit Réseau & Paramètres Noyau (sysctl)${NC}"
echo "------------------------------------------------------------"

# SYN Cookies
SYN_COOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo 0)
if [ "$SYN_COOKIES" -eq 1 ]; then
    check_item "Protection TCP SYN Flood activée (tcp_syncookies)" 0 "" "NET-001" "high" "Activer net.ipv4.tcp_syncookies = 1 via sysctl"
else
    check_item "Protection TCP SYN Flood activée (tcp_syncookies)" 1 "net.ipv4.tcp_syncookies = 0" "NET-001" "high" "Activer net.ipv4.tcp_syncookies = 1 via sysctl"
fi

# RP Filter (Anti-spoofing)
RP_FILTER=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo 0)
if [ "$RP_FILTER" -ge 1 ]; then
    check_item "Protection anti-usurpation IP (Reverse Path Filtering)" 0 "" "NET-002" "high" "Activer net.ipv4.conf.all.rp_filter = 1 via sysctl"
else
    check_item "Protection anti-usurpation IP (Reverse Path Filtering)" 1 "net.ipv4.conf.all.rp_filter = 0" "NET-002" "high" "Activer net.ipv4.conf.all.rp_filter = 1 via sysctl"
fi

# ICMP Redirects
ICMP_REDIR=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo 1)
if [ "$ICMP_REDIR" -eq 0 ]; then
    check_item "Refus des redirections ICMP (Anti-MitM)" 0 "" "NET-003" "medium" "Définir net.ipv4.conf.all.accept_redirects = 0 via sysctl"
else
    check_item "Refus des redirections ICMP (Anti-MitM)" 1 "accept_redirects = 1 (vulnérable au détournement)" "NET-003" "medium" "Définir net.ipv4.conf.all.accept_redirects = 0 via sysctl"
fi

# ASLR
ASLR=$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo 0)
if [ "$ASLR" -eq 2 ]; then
    check_item "Randomisation mémoire ASLR au niveau maximal (2)" 0 "" "NET-004" "high" "Définir kernel.randomize_va_space = 2 via sysctl"
else
    check_item "Randomisation mémoire ASLR au niveau maximal (2)" 1 "kernel.randomize_va_space < 2" "NET-004" "high" "Définir kernel.randomize_va_space = 2 via sysctl"
fi

# ------------------------------------------------------------------------------
# 4. Audit Pare-feu & Protection Active
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[3] Audit Pare-feu & Détection d'Attaques${NC}"
echo "------------------------------------------------------------"

# UFW Status
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    check_item "Pare-feu applicatif (UFW) actif" 0 "" "FW-001" "critical" "Installer et activer UFW avec ufw --force enable"
else
    check_item "Pare-feu applicatif (UFW) actif" 1 "UFW est inactif ou non installé" "FW-001" "critical" "Installer et activer UFW avec ufw --force enable"
fi

# Fail2ban Status
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    check_item "Service Fail2ban actif et surveillant les logs" 0 "" "FW-002" "medium" "Installer et démarrer le service fail2ban"
else
    check_item "Service Fail2ban actif et surveillant les logs" 1 "Fail2ban n'est pas en cours d'exécution" "FW-002" "medium" "Installer et démarrer le service fail2ban"
fi

# Auditd Status
if systemctl is-active --quiet auditd 2>/dev/null; then
    check_item "Service de traçabilité Auditd actif" 0 "" "FW-003" "medium" "Installer et démarrer le service auditd"
else
    check_item "Service de traçabilité Auditd actif" 1 "Auditd n'est pas actif" "FW-003" "medium" "Installer et démarrer le service auditd"
fi

# ------------------------------------------------------------------------------
# 5. Calcul du Score Global
# ------------------------------------------------------------------------------
SCORE=$(( (PASSED * 100) / TOTAL ))

echo -e "\n============================================================"
echo -e "${BOLD}RÉSULTATS DE L'AUDIT SÉCURITÉ :${NC}"
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
    OS_DETAILS=""
    if [ -f /etc/os-release ]; then
        OS_DETAILS=$(grep -oP '(?<=^PRETTY_NAME=")[^"]*' /etc/os-release 2>/dev/null)
        if [ -z "$OS_DETAILS" ]; then
            OS_DETAILS=$(grep -oP '(?<=^PRETTY_NAME=)[^"]*' /etc/os-release 2>/dev/null)
        fi
    fi
    if [ -z "$OS_DETAILS" ]; then
        OS_DETAILS=$(uname -a 2>/dev/null || echo "Unknown OS")
    fi
    
    JSON_FILE="${OUTPUT_DIR}/audit_${HOSTNAME_VAL}_$(date +%Y%m%d_%H%M%S).json"
    
    # join array elements with comma and newline
    CHECKS_JOINED=$(IFS=, ; echo "${JSON_CHECKS[*]}")
    
    cat <<EOF > "$JSON_FILE"
{
  "tool": "autosec-hardening",
  "version": "1.1.0",
  "timestamp": "$TIMESTAMP",
  "hostname": "$(escape_json "$HOSTNAME_VAL")",
  "os": "linux",
  "os_details": "$(escape_json "$OS_DETAILS")",
  "score": $SCORE,
  "passed": $PASSED,
  "failed": $FAILED,
  "total": $TOTAL,
  "checks": [
$CHECKS_JOINED
  ]
}
EOF
fi
