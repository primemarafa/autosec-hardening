#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script d'Audit de Conformité Sécurité (ANSSI / CIS)
# ==============================================================================

set -o pipefail

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

    TOTAL=$((TOTAL + 1))
    if [ "$status" -eq 0 ]; then
        echo -e "  [${GREEN}CONFORME${NC}]  $description"
        PASSED=$((PASSED + 1))
    else
        echo -e "  [${RED}VULNÉRABLE${NC}] $description"
        if [ -n "$details" ]; then
            echo -e "               ${YELLOW}↳ Détail : $details${NC}"
        fi
        FAILED=$((FAILED + 1))
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
    check_item "Connexion directe du compte Root désactivée" 0
else
    check_item "Connexion directe du compte Root désactivée" 1 "PermitRootLogin n'est pas configuré sur 'no'"
fi

# Password auth
if grep -Eq "^\s*PasswordAuthentication\s+no" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
    check_item "Authentification par mot de passe désactivée (Clés obligatoires)" 0
else
    check_item "Authentification par mot de passe désactivée (Clés obligatoires)" 1 "PasswordAuthentication est autorisé ou non défini"
fi

# MaxAuthTries
if grep -Eq "^\s*MaxAuthTries\s+[1-3]" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
    check_item "Nombre maximal de tentatives d'authentification limité (<=3)" 0
else
    check_item "Nombre maximal de tentatives d'authentification limité (<=3)" 1 "MaxAuthTries supérieur à 3 ou non configuré"
fi

# ------------------------------------------------------------------------------
# 3. Audit Noyau & Réseau (sysctl)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[2] Audit Réseau & Paramètres Noyau (sysctl)${NC}"
echo "------------------------------------------------------------"

# SYN Cookies
SYN_COOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo 0)
if [ "$SYN_COOKIES" -eq 1 ]; then
    check_item "Protection TCP SYN Flood activée (tcp_syncookies)" 0
else
    check_item "Protection TCP SYN Flood activée (tcp_syncookies)" 1 "net.ipv4.tcp_syncookies = 0"
fi

# RP Filter (Anti-spoofing)
RP_FILTER=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo 0)
if [ "$RP_FILTER" -ge 1 ]; then
    check_item "Protection anti-usurpation IP (Reverse Path Filtering)" 0
else
    check_item "Protection anti-usurpation IP (Reverse Path Filtering)" 1 "net.ipv4.conf.all.rp_filter = 0"
fi

# ICMP Redirects
ICMP_REDIR=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo 1)
if [ "$ICMP_REDIR" -eq 0 ]; then
    check_item "Refus des redirections ICMP (Anti-MitM)" 0
else
    check_item "Refus des redirections ICMP (Anti-MitM)" 1 "accept_redirects = 1 (vulnérable au détournement)"
fi

# ASLR
ASLR=$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo 0)
if [ "$ASLR" -eq 2 ]; then
    check_item "Randomisation mémoire ASLR au niveau maximal (2)" 0
else
    check_item "Randomisation mémoire ASLR au niveau maximal (2)" 1 "kernel.randomize_va_space < 2"
fi

# ------------------------------------------------------------------------------
# 4. Audit Pare-feu & Protection Active
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[3] Audit Pare-feu & Détection d'Attaques${NC}"
echo "------------------------------------------------------------"

# UFW Status
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    check_item "Pare-feu applicatif (UFW) actif" 0
else
    check_item "Pare-feu applicatif (UFW) actif" 1 "UFW est inactif ou non installé"
fi

# Fail2ban Status
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    check_item "Service Fail2ban actif et surveillant les logs" 0
else
    check_item "Service Fail2ban actif et surveillant les logs" 1 "Fail2ban n'est pas en cours d'exécution"
fi

# Auditd Status
if systemctl is-active --quiet auditd 2>/dev/null; then
    check_item "Service de traçabilité Auditd actif" 0
else
    check_item "Service de traçabilité Auditd actif" 1 "Auditd n'est pas actif"
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
