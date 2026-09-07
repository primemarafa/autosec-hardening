<#
==============================================================================
 AutoSec-Hardener : Script de Comparaison de Rapports d'Audit (Avant / Après)
==============================================================================
 Usage :
   .\Compare-Reports.ps1 -Before .\avant.json -After .\apres.json [-Pdf]

 Génère un rapport Markdown comparatif dans reports\comparisons\
 L'option -Pdf convertit automatiquement en PDF via pandoc (si installé)
==============================================================================
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Before,

    [Parameter(Mandatory = $true)]
    [string]$After,

    [switch]$Pdf,

    [string]$OutputDir
)

# Résolution robuste du répertoire de sortie
if (-not $OutputDir) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path) }
    $OutputDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\reports\comparisons"))
}

# --- Validation ---
if (-not (Test-Path $Before)) {
    Write-Error "Fichier introuvable : $Before"
    exit 1
}
if (-not (Test-Path $After)) {
    Write-Error "Fichier introuvable : $After"
    exit 1
}

# --- Chargement JSON ---
Write-Host "[+] Analyse des rapports..." -ForegroundColor Cyan

$beforeData = [System.IO.File]::ReadAllText((Resolve-Path $Before).Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$afterData = [System.IO.File]::ReadAllText((Resolve-Path $After).Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

# --- Extraction des données ---
$bScore = [int]$beforeData.score
$aScore = [int]$afterData.score
$bPassed = [int]$beforeData.passed
$aPassed = [int]$afterData.passed
$bFailed = [int]$beforeData.failed
$aFailed = [int]$afterData.failed
$bTotal = [int]$beforeData.total
$aTotal = [int]$afterData.total

$scoreDiff = $aScore - $bScore
$passedDiff = $aPassed - $bPassed
$failedDiff = $aFailed - $bFailed

# Flèche d'évolution
if ($scoreDiff -gt 0) {
    $scoreArrow = "+${scoreDiff}%"
    $scoreEmoji = "[HAUSSE]"
} elseif ($scoreDiff -lt 0) {
    $scoreArrow = "${scoreDiff}%"
    $scoreEmoji = "[BAISSE]"
} else {
    $scoreArrow = "= 0%"
    $scoreEmoji = "[STABLE]"
}

# Niveau de sécurité
function Get-SecurityLevel($score) {
    if ($score -ge 80) { return "ELEVE" }
    elseif ($score -ge 50) { return "MOYEN" }
    else { return "CRITIQUE" }
}

$bLevel = Get-SecurityLevel $bScore
$aLevel = Get-SecurityLevel $aScore

# --- Analyse des checks ---
$beforeChecks = @{}
foreach ($c in $beforeData.checks) { $beforeChecks[$c.id] = $c }

$afterChecks = @{}
foreach ($c in $afterData.checks) { $afterChecks[$c.id] = $c }

# Checks corrigés : fail avant → pass après
$fixedChecks = @()
foreach ($c in $beforeData.checks) {
    if ($c.status -eq "fail" -and $afterChecks.ContainsKey($c.id) -and $afterChecks[$c.id].status -eq "pass") {
        $fixedChecks += $c
    }
}

# Régressions : pass avant → fail après
$regressionChecks = @()
foreach ($c in $beforeData.checks) {
    if ($c.status -eq "pass" -and $afterChecks.ContainsKey($c.id) -and $afterChecks[$c.id].status -eq "fail") {
        $regressionChecks += $afterChecks[$c.id]
    }
}

# Toujours échoués : fail avant ET fail après
$stillFailed = @()
foreach ($c in $beforeData.checks) {
    if ($c.status -eq "fail" -and $afterChecks.ContainsKey($c.id) -and $afterChecks[$c.id].status -eq "fail") {
        $stillFailed += $afterChecks[$c.id]
    }
}

# Verdict
if ($scoreDiff -gt 20) {
    $verdict = "**Amelioration significative** - le niveau de securite passe de **${bLevel}** a **${aLevel}**."
} elseif ($scoreDiff -gt 0) {
    $verdict = "**Amelioration moderee** - le score progresse de ${bScore}% a ${aScore}%."
} elseif ($scoreDiff -eq 0) {
    $verdict = "**Aucun changement** - le score reste stable a ${aScore}%."
} else {
    $verdict = "**Regression detectee** - le score chute de ${bScore}% a ${aScore}%."
}

# --- Fonctions d'aide pour les tableaux ---
function Get-SeverityIcon($sev) {
    switch ($sev) {
        "critical" { return "Critical" }
        "high"     { return "High" }
        "medium"   { return "Medium" }
        "low"      { return "Low" }
        default    { return $sev }
    }
}

function Format-CheckTable($checks, $showRemediation) {
    if ($checks.Count -eq 0) {
        return "Aucun.`n"
    }

    $lines = @()
    if ($showRemediation) {
        $lines += "| ID | Description | Severite | Remediation |"
        $lines += "|:---|:---|:---:|:---|"
    } else {
        $lines += "| ID | Description | Severite |"
        $lines += "|:---|:---|:---:|"
    }

    foreach ($c in $checks) {
        $sevIcon = Get-SeverityIcon $c.severity
        if ($showRemediation) {
            $lines += "| ``$($c.id)`` | $($c.description) | $sevIcon | ``$($c.remediation)`` |"
        } else {
            $lines += "| ``$($c.id)`` | $($c.description) | $sevIcon |"
        }
    }
    $lines += ""
    return ($lines -join "`n")
}

# --- Génération du rapport Markdown ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputDir "comparison_$($beforeData.hostname)_$timestamp.md"

$passedDiffStr = if ($passedDiff -ge 0) { "+$passedDiff" } else { "$passedDiff" }
$failedDiffStr = if ($failedDiff -ge 0) { "+$failedDiff" } else { "$failedDiff" }

$markdown = @"
# Rapport de Comparaison - Audit de Securite

> Rapport genere automatiquement par **AutoSec-Hardener v1.1.0**
> Date de generation : $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")

---

## Informations Systeme

| | Detail |
|:---|:---|
| **Machine** | $($beforeData.hostname) |
| **OS** | $($beforeData.os) ($($beforeData.os_details)) |
| **Audit avant** | $($beforeData.timestamp) |
| **Audit apres** | $($afterData.timestamp) |

---

## $scoreEmoji Evolution du Score

| | Avant | Apres | Evolution |
|:---|:---:|:---:|:---:|
| **Score** | ${bScore}% | ${aScore}% | **${scoreArrow}** |
| **Niveau** | ${bLevel} | ${aLevel} | |
| **Conformes** | ${bPassed} / ${bTotal} | ${aPassed} / ${aTotal} | $passedDiffStr |
| **Vulnerables** | ${bFailed} / ${bTotal} | ${aFailed} / ${aTotal} | $failedDiffStr |

**Verdict :** $verdict

---

## Controles Corriges ($($fixedChecks.Count))

$(Format-CheckTable $fixedChecks $false)

## Controles Toujours Echoues ($($stillFailed.Count))

$(Format-CheckTable $stillFailed $true)

## Regressions ($($regressionChecks.Count))

$(Format-CheckTable $regressionChecks $true)

---

*Fichiers sources :*
- Avant : ``$(Split-Path $Before -Leaf)``
- Apres : ``$(Split-Path $After -Leaf)``
- Rapport : ``$(Split-Path $reportFile -Leaf)``
"@

[System.IO.File]::WriteAllText($reportFile, $markdown, [System.Text.Encoding]::UTF8)
Write-Host "[OK] Rapport Markdown genere : $reportFile" -ForegroundColor Green

# --- Résumé terminal ---
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  COMPARAISON : $($beforeData.hostname) ($($beforeData.os))" -ForegroundColor White
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Score   : ${bScore}%  ->  ${aScore}%  ($scoreArrow)"

if ($scoreDiff -gt 0) {
    Write-Host "  Niveau  : ${bLevel}  ->  ${aLevel}" -ForegroundColor Green
} elseif ($scoreDiff -lt 0) {
    Write-Host "  Niveau  : ${bLevel}  ->  ${aLevel}" -ForegroundColor Red
} else {
    Write-Host "  Niveau  : ${bLevel}  ->  ${aLevel}" -ForegroundColor Yellow
}

Write-Host "  Corriges      : $($fixedChecks.Count)" -ForegroundColor Green
Write-Host "  Encore echoues: $($stillFailed.Count)" -ForegroundColor Red
Write-Host "  Regressions   : $($regressionChecks.Count)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan

# --- Export PDF (optionnel) ---
if ($Pdf) {
    $pdfFile = $reportFile -replace '\.md$', '.pdf'
    $pandocPath = Get-Command pandoc -ErrorAction SilentlyContinue
    $edgePath = if (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    } elseif (Test-Path "C:\Program Files\Microsoft\Edge\Application\msedge.exe") {
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    } else {
        (Get-Command msedge, chrome -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    }

    if ($pandocPath) {
        Write-Host "`n[+] Conversion en PDF via pandoc..." -ForegroundColor Cyan
        & pandoc $reportFile -o $pdfFile -V geometry:margin=2cm -V fontsize=11pt --highlight-style=tango 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $pdfFile)) {
            Write-Host "[OK] PDF genere avec succes : $pdfFile" -ForegroundColor Green
        } else {
            $pandocPath = $null # fallback to Edge
        }
    }
    
    if (-not $pandocPath -and $edgePath) {
        Write-Host "`n[+] Conversion en PDF via navigateur headless ($([System.IO.Path]::GetFileName($edgePath)))..." -ForegroundColor Cyan
        
        # Transformation Markdown -> HTML stylise pour impression PDF
        $htmlFile = $reportFile -replace '\.md$', '.html'
        $htmlContent = @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport de Comparaison - AutoSec Hardening</title>
<style>
  @page { size: A4; margin: 15mm; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.5; color: #1e293b; max-width: 900px; margin: 0 auto; padding: 20px; font-size: 13px; }
  h1 { font-size: 22px; color: #0f172a; border-bottom: 2px solid #0284c7; padding-bottom: 8px; margin-top: 0; }
  h2 { font-size: 16px; color: #0369a1; margin-top: 24px; margin-bottom: 12px; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px; }
  blockquote { margin: 10px 0; padding: 8px 14px; background: #f0f9ff; border-left: 4px solid #0ea5e9; color: #0369a1; font-size: 12px; }
  table { width: 100%; border-collapse: collapse; margin: 14px 0; font-size: 12px; }
  th, td { padding: 8px 10px; text-align: left; border: 1px solid #cbd5e1; }
  th { background-color: #f8fafc; font-weight: 600; color: #334155; }
  tr:nth-child(even) { background-color: #f8fafc; }
  code { font-family: 'Fira Code', Consolas, Monaco, monospace; background: #f1f5f9; padding: 2px 5px; border-radius: 4px; font-size: 11px; color: #0f172a; }
  .badge-crit { background: #ffe4e6; color: #be123c; font-weight: bold; padding: 2px 6px; border-radius: 4px; }
  .badge-high { background: #fef3c7; color: #b45309; font-weight: bold; padding: 2px 6px; border-radius: 4px; }
  .badge-med { background: #dbeafe; color: #1d4ed8; font-weight: bold; padding: 2px 6px; border-radius: 4px; }
  .footer { margin-top: 30px; font-size: 11px; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 10px; }
</style>
</head>
<body>
$(
    $lines = $markdown -split "`r?`n"
    $out = @()
    $inTable = $false
    foreach ($line in $lines) {
        if ($line -match '^# (.*)') { $out += "<h1>$($Matches[1])</h1>" }
        elseif ($line -match '^## (.*)') { $out += "<h2>$($Matches[1])</h2>" }
        elseif ($line -match '^> (.*)') { $out += "<blockquote>$($Matches[1])</blockquote>" }
        elseif ($line -match '^\|(.*)\|') {
            if (-not $inTable) { $inTable = $true; $out += "<table>"; $isHeader = $true }
            $cells = $line.Trim('|').Split('|')
            if ($line -match '^[\|\s\-:]+$') { continue }
            $rowTag = if ($isHeader) { 'th' } else { 'td' }
            $rowHtml = "<tr>" + (($cells | ForEach-Object { 
                $c = $_.Trim()
                $c = $c -replace '`([^`]+)`', '<code>$1</code>'
                $c = $c -replace 'Critical', '<span class="badge-crit">Critical</span>'
                $c = $c -replace 'High', '<span class="badge-high">High</span>'
                $c = $c -replace 'Medium', '<span class="badge-med">Medium</span>'
                "<$rowTag>$c</$rowTag>" 
            }) -join "") + "</tr>"
            $out += $rowHtml
            $isHeader = $false
        } else {
            if ($inTable) { $inTable = $false; $out += "</table>" }
            if ($line -match '^---\s*$') { $out += "<hr style='border:0; border-top:1px solid #e2e8f0; margin:16px 0;'>" }
            elseif ($line.Trim().Length -gt 0) {
                $p = $line -replace '\*\*([^\*]+)\*\*', '<strong>$1</strong>'
                $p = $p -replace '`([^`]+)`', '<code>$1</code>'
                $out += "<p>$p</p>"
            }
        }
    }
    if ($inTable) { $out += "</table>" }
    $out -join "`n"
)
</body>
</html>
"@
        [System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)
        
        $process = Start-Process -FilePath $edgePath -ArgumentList "--headless", "--disable-gpu", "--run-all-compositor-stages-before-draw", "--print-to-pdf=`"$pdfFile`"", "`"$htmlFile`"" -Wait -PassThru
        if (Test-Path $pdfFile) {
            Write-Host "[OK] PDF genere avec succes : $pdfFile" -ForegroundColor Green
            Remove-Item $htmlFile -ErrorAction SilentlyContinue
        } else {
            Write-Host "[!] La conversion PDF a echoue. Le rapport HTML reste disponible : $htmlFile" -ForegroundColor Yellow
        }
    } elseif (-not $pandocPath) {
        Write-Host "`n[!] Aucun moteur PDF detecte (pandoc ou navigateur Chrome/Edge introuvable)." -ForegroundColor Yellow
        Write-Host "    Pour generer des PDF : installez pandoc ou Microsoft Edge." -ForegroundColor Gray
    }
}
