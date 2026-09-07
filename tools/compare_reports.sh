#!/usr/bin/env bash
# ==============================================================================
# AutoSec-Hardener : Script de Comparaison de Rapports d'Audit (Avant / Après)
# ==============================================================================
# Usage :
#   ./compare_reports.sh <rapport_avant.json> <rapport_apres.json> [--pdf]
#
# Génère un rapport Markdown comparatif dans reports/comparisons/
# L'option --pdf convertit automatiquement en PDF via pandoc (si installé)
# ==============================================================================

set -o pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../reports/comparisons"
EXPORT_PDF=0

# --- Parsing des arguments ---
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Erreur : Deux fichiers JSON requis.${NC}"
    echo "Usage : $0 <rapport_avant.json> <rapport_apres.json> [--pdf]"
    exit 1
fi

BEFORE_FILE="$1"
AFTER_FILE="$2"
shift 2

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --pdf) EXPORT_PDF=1; shift ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo -e "${YELLOW}Paramètre inconnu : $1${NC}"; shift ;;
    esac
done

# --- Validation des fichiers ---
if [ ! -f "$BEFORE_FILE" ]; then
    echo -e "${RED}Erreur : Fichier introuvable : $BEFORE_FILE${NC}"
    exit 1
fi
if [ ! -f "$AFTER_FILE" ]; then
    echo -e "${RED}Erreur : Fichier introuvable : $AFTER_FILE${NC}"
    exit 1
fi

# --- Vérification de jq ---
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Erreur : 'jq' est requis pour parser les fichiers JSON.${NC}"
    echo "Installation : sudo apt-get install jq"
    exit 1
fi

# --- Extraction des données ---
echo -e "${BLUE}${BOLD}[+] Analyse des rapports...${NC}"

B_HOSTNAME=$(jq -r '.hostname // "inconnu"' "$BEFORE_FILE")
B_OS=$(jq -r '.os // "inconnu"' "$BEFORE_FILE")
B_OS_DETAILS=$(jq -r '.os_details // ""' "$BEFORE_FILE")
B_TIMESTAMP=$(jq -r '.timestamp // ""' "$BEFORE_FILE")
B_SCORE=$(jq -r '.score // 0' "$BEFORE_FILE")
B_PASSED=$(jq -r '.passed // 0' "$BEFORE_FILE")
B_FAILED=$(jq -r '.failed // 0' "$BEFORE_FILE")
B_TOTAL=$(jq -r '.total // 0' "$BEFORE_FILE")

A_HOSTNAME=$(jq -r '.hostname // "inconnu"' "$AFTER_FILE")
A_OS=$(jq -r '.os // "inconnu"' "$AFTER_FILE")
A_OS_DETAILS=$(jq -r '.os_details // ""' "$AFTER_FILE")
A_TIMESTAMP=$(jq -r '.timestamp // ""' "$AFTER_FILE")
A_SCORE=$(jq -r '.score // 0' "$AFTER_FILE")
A_PASSED=$(jq -r '.passed // 0' "$AFTER_FILE")
A_FAILED=$(jq -r '.failed // 0' "$AFTER_FILE")
A_TOTAL=$(jq -r '.total // 0' "$AFTER_FILE")

# --- Calcul de l'évolution ---
SCORE_DIFF=$((A_SCORE - B_SCORE))
PASSED_DIFF=$((A_PASSED - B_PASSED))
FAILED_DIFF=$((A_FAILED - B_FAILED))

if [ "$SCORE_DIFF" -gt 0 ]; then
    SCORE_ARROW="↑ +${SCORE_DIFF}%"
    SCORE_EMOJI="📈"
elif [ "$SCORE_DIFF" -lt 0 ]; then
    SCORE_ARROW="↓ ${SCORE_DIFF}%"
    SCORE_EMOJI="📉"
else
    SCORE_ARROW="= 0%"
    SCORE_EMOJI="➡️"
fi

# Niveau de sécurité
get_level() {
    local score=$1
    if [ "$score" -ge 80 ]; then echo "ÉLEVÉ"; 
    elif [ "$score" -ge 50 ]; then echo "MOYEN";
    else echo "CRITIQUE"; fi
}
B_LEVEL=$(get_level "$B_SCORE")
A_LEVEL=$(get_level "$A_SCORE")

# --- Analyse des checks ---
# Checks corrigés : fail dans before → pass dans after
FIXED_CHECKS=$(jq -r --slurpfile after "$AFTER_FILE" '
    [.checks[] | select(.status == "fail") | .id] as $before_fails |
    [$after[0].checks[] | select(.status == "pass") | .id] as $after_passes |
    [$before_fails[] | select(. as $id | $after_passes | index($id))]
' "$BEFORE_FILE")

# Régressions : pass dans before → fail dans after
REGRESSION_CHECKS=$(jq -r --slurpfile after "$AFTER_FILE" '
    [.checks[] | select(.status == "pass") | .id] as $before_passes |
    [$after[0].checks[] | select(.status == "fail") | .id] as $after_fails |
    [$before_passes[] | select(. as $id | $after_fails | index($id))]
' "$BEFORE_FILE")

# Toujours échoués : fail dans before ET fail dans after
STILL_FAILED=$(jq -r --slurpfile after "$AFTER_FILE" '
    [.checks[] | select(.status == "fail") | .id] as $before_fails |
    [$after[0].checks[] | select(.status == "fail") | .id] as $after_fails |
    [$before_fails[] | select(. as $id | $after_fails | index($id))]
' "$BEFORE_FILE")

FIXED_COUNT=$(echo "$FIXED_CHECKS" | jq 'length')
REGRESSION_COUNT=$(echo "$REGRESSION_CHECKS" | jq 'length')
STILL_FAILED_COUNT=$(echo "$STILL_FAILED" | jq 'length')

# Verdict
if [ "$SCORE_DIFF" -gt 20 ]; then
    VERDICT="🟢 **Amélioration significative** — le niveau de sécurité passe de **${B_LEVEL}** à **${A_LEVEL}**."
elif [ "$SCORE_DIFF" -gt 0 ]; then
    VERDICT="🟡 **Amélioration modérée** — le score progresse de ${B_SCORE}% à ${A_SCORE}%."
elif [ "$SCORE_DIFF" -eq 0 ]; then
    VERDICT="⚪ **Aucun changement** — le score reste stable à ${A_SCORE}%."
else
    VERDICT="🔴 **Régression détectée** — le score chute de ${B_SCORE}% à ${A_SCORE}%."
fi

# --- Génération du rapport Markdown ---
mkdir -p "$OUTPUT_DIR"
REPORT_FILE="${OUTPUT_DIR}/comparison_${B_HOSTNAME}_$(date +%Y%m%d_%H%M%S).md"

generate_check_table() {
    local check_ids="$1"
    local source_file="$2"
    local show_remediation="$3"

    local count
    count=$(echo "$check_ids" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        echo "Aucun."
        echo ""
        return
    fi

    if [ "$show_remediation" = "true" ]; then
        echo "| ID | Description | Sévérité | Remédiation |"
        echo "|:---|:---|:---:|:---|"
    else
        echo "| ID | Description | Sévérité |"
        echo "|:---|:---|:---:|"
    fi

    echo "$check_ids" | jq -r '.[]' | while read -r check_id; do
        local desc sev remed sev_icon
        desc=$(jq -r --arg id "$check_id" '.checks[] | select(.id == $id) | .description' "$source_file")
        sev=$(jq -r --arg id "$check_id" '.checks[] | select(.id == $id) | .severity' "$source_file")
        remed=$(jq -r --arg id "$check_id" '.checks[] | select(.id == $id) | .remediation // ""' "$source_file")

        case "$sev" in
            critical) sev_icon="🔴 Critical" ;;
            high)     sev_icon="🟠 High" ;;
            medium)   sev_icon="🟡 Medium" ;;
            low)      sev_icon="🟢 Low" ;;
            *)        sev_icon="$sev" ;;
        esac

        if [ "$show_remediation" = "true" ]; then
            echo "| \`${check_id}\` | ${desc} | ${sev_icon} | \`${remed}\` |"
        else
            echo "| \`${check_id}\` | ${desc} | ${sev_icon} |"
        fi
    done
    echo ""
}

{
    cat <<HEADER
# 📊 Rapport de Comparaison — Audit de Sécurité

> Rapport généré automatiquement par **AutoSec-Hardener v1.1.0**  
> Date de génération : $(date +"%d/%m/%Y %H:%M:%S")

---

## 🖥️ Informations Système

| | Détail |
|:---|:---|
| **Machine** | ${B_HOSTNAME} |
| **OS** | ${B_OS} (${B_OS_DETAILS}) |
| **Audit avant** | ${B_TIMESTAMP} |
| **Audit après** | ${A_TIMESTAMP} |

---

## ${SCORE_EMOJI} Évolution du Score

| | Avant | Après | Évolution |
|:---|:---:|:---:|:---:|
| **Score** | ${B_SCORE}% | ${A_SCORE}% | **${SCORE_ARROW}** |
| **Niveau** | ${B_LEVEL} | ${A_LEVEL} | |
| **Conformes** | ${B_PASSED} / ${B_TOTAL} | ${A_PASSED} / ${A_TOTAL} | ${PASSED_DIFF:+$PASSED_DIFF} |
| **Vulnérables** | ${B_FAILED} / ${B_TOTAL} | ${A_FAILED} / ${A_TOTAL} | ${FAILED_DIFF} |

**Verdict :** ${VERDICT}

---

## ✅ Contrôles Corrigés (${FIXED_COUNT})

HEADER

    generate_check_table "$FIXED_CHECKS" "$BEFORE_FILE" "false"

    cat <<SECTION2
## ❌ Contrôles Toujours Échoués (${STILL_FAILED_COUNT})

SECTION2

    generate_check_table "$STILL_FAILED" "$AFTER_FILE" "true"

    cat <<SECTION3
## ⚠️ Régressions (${REGRESSION_COUNT})

SECTION3

    generate_check_table "$REGRESSION_CHECKS" "$AFTER_FILE" "true"

    cat <<FOOTER
---

*Fichiers sources :*  
- Avant : \`$(basename "$BEFORE_FILE")\`  
- Après : \`$(basename "$AFTER_FILE")\`  
- Rapport : \`$(basename "$REPORT_FILE")\`
FOOTER

} > "$REPORT_FILE"

echo -e "${GREEN}${BOLD}[✓] Rapport Markdown généré : ${REPORT_FILE}${NC}"

# --- Affichage résumé terminal ---
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  COMPARAISON : ${B_HOSTNAME} (${B_OS})${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "  Score   : ${B_SCORE}%  →  ${A_SCORE}%  (${SCORE_ARROW})"
echo -e "  Niveau  : ${B_LEVEL}  →  ${A_LEVEL}"
echo -e "  Corrigés     : ${GREEN}${FIXED_COUNT}${NC}"
echo -e "  Encore échoués : ${RED}${STILL_FAILED_COUNT}${NC}"
echo -e "  Régressions  : ${YELLOW}${REGRESSION_COUNT}${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"

# --- Export PDF (optionnel) ---
if [ "$EXPORT_PDF" -eq 1 ]; then
    PDF_FILE="${REPORT_FILE%.md}.pdf"
    PDF_DONE=0
    
    if command -v pandoc >/dev/null 2>&1; then
        echo -e "${BLUE}[+] Conversion en PDF via pandoc...${NC}"
        pandoc "$REPORT_FILE" -o "$PDF_FILE" \
            --pdf-engine=xelatex \
            -V geometry:margin=2cm \
            -V fontsize=11pt \
            -V mainfont="DejaVu Sans" \
            --highlight-style=tango \
            2>/dev/null && PDF_DONE=1

        if [ "$PDF_DONE" -eq 0 ]; then
            pandoc "$REPORT_FILE" -o "$PDF_FILE" \
                -V geometry:margin=2cm \
                -V fontsize=11pt \
                2>/dev/null && PDF_DONE=1
        fi
    fi

    # Fallback vers navigateur headless (Chromium / Chrome / Edge)
    if [ "$PDF_DONE" -eq 0 ]; then
        BROWSER_BIN=""
        for b in chromium chromium-browser google-chrome google-chrome-stable msedge; do
            if command -v "$b" >/dev/null 2>&1; then
                BROWSER_BIN="$b"
                break
            fi
        done

        if [ -n "$BROWSER_BIN" ]; then
            echo -e "${BLUE}[+] Conversion en PDF via navigateur headless (${BROWSER_BIN})...${NC}"
            HTML_FILE="${REPORT_FILE%.md}.html"
            cat <<HTML_EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport de Comparaison - AutoSec Hardening</title>
<style>
  @page { size: A4; margin: 15mm; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.5; color: #1e293b; max-width: 900px; margin: 0 auto; padding: 20px; font-size: 13px; }
  h1 { font-size: 22px; color: #0f172a; border-bottom: 2px solid #0284c7; padding-bottom: 8px; }
  h2 { font-size: 16px; color: #0369a1; margin-top: 24px; margin-bottom: 12px; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px; }
  blockquote { margin: 10px 0; padding: 8px 14px; background: #f0f9ff; border-left: 4px solid #0ea5e9; color: #0369a1; }
  table { width: 100%; border-collapse: collapse; margin: 14px 0; font-size: 12px; }
  th, td { padding: 8px 10px; text-align: left; border: 1px solid #cbd5e1; }
  th { background-color: #f8fafc; font-weight: 600; color: #334155; }
  tr:nth-child(even) { background-color: #f8fafc; }
  code { font-family: monospace; background: #f1f5f9; padding: 2px 5px; border-radius: 4px; }
</style>
</head>
<body>
<pre style="white-space: pre-wrap; font-family: inherit;">
$(cat "$REPORT_FILE")
</pre>
</body>
</html>
HTML_EOF
            "$BROWSER_BIN" --headless --disable-gpu --run-all-compositor-stages-before-draw --print-to-pdf="$PDF_FILE" "$HTML_FILE" 2>/dev/null
            if [ -f "$PDF_FILE" ]; then
                PDF_DONE=1
                rm -f "$HTML_FILE"
            fi
        fi
    fi

    if [ "$PDF_DONE" -eq 1 ]; then
        echo -e "${GREEN}[✓] PDF généré : ${PDF_FILE}${NC}"
    else
        echo -e "${YELLOW}[!] pandoc ou un navigateur headless est requis pour l'export PDF.${NC}"
        echo -e "    Installation pandoc : sudo apt-get install pandoc texlive-xetex"
        echo -e "    Ou installez chromium : sudo apt-get install chromium-browser"
    fi
fi
