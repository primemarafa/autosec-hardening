<#
==============================================================================
 AutoSec-Hardener : Script d'Audit de Sécurité Windows (ANSSI / CIS Benchmark)
 Fichier : windows/Audit-Security.ps1
 Usage   : powershell -ExecutionPolicy Bypass -File .\Audit-Security.ps1
==============================================================================
#>

param (
    [switch]$JsonExport,
    [string]$OutputDir = "$PSScriptRoot\..\reports\windows"
)

# Vérification des privilèges Administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Avertissement : Lancez PowerShell en tant qu'Administrateur pour un audit complet." -ForegroundColor Yellow
}

$Passed = 0
$Failed = 0
$Total = 0
$Script:Results = @()

function Test-CheckItem {
    param (
        [string]$Id,
        [string]$Description,
        [string]$Severity,
        [bool]$IsCompliant,
        [string]$Details,
        [string]$Remediation
    )
    $script:Total++
    if ($IsCompliant) {
        Write-Host "  [CONFORME]   $Description" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [VULNERABLE] $Description" -ForegroundColor Red
        if ($Details) {
            Write-Host "               ↳ Detail : $Details" -ForegroundColor Yellow
        }
        $script:Failed++
    }
    
    $checkResult = [PSCustomObject]@{
        id          = $Id
        category    = $null
        description = $Description
        status      = if ($IsCompliant) { "pass" } else { "fail" }
        severity    = $Severity
        remediation = $Remediation
    }
    $Script:Results += $checkResult
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   AUTODEFENSE & SECURITY AUDITOR - WINDOWS SERVER / CLIENT " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. Audit Réseau & Protocoles Obsolètes
# ------------------------------------------------------------------------------
Write-Host "`n[1] Audit Réseau & Protocoles d'Échange" -ForegroundColor White
$category = "Réseau & Protocoles"

# SMBv1
$smb1 = (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue).State
Test-CheckItem -Id "WIN-NET-001" `
               -Severity "critical" `
               -Description "Protocole obsolète SMBv1 désactivé" `
               -IsCompliant ($smb1 -ne "Enabled") `
               -Details "SMBv1 est actif (Vulnérabilité critique type WannaCry/EternalBlue)" `
               -Remediation "Désactiver SMBv1 via Disable-WindowsOptionalFeature -FeatureName SMB1Protocol"
$Script:Results[-1].category = $category

# LLMNR (Link-Local Multicast Name Resolution)
$llmnr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue).EnableMulticast
Test-CheckItem -Id "WIN-NET-002" `
               -Severity "high" `
               -Description "Protocole LLMNR désactivé (Anti-Responder/MitM)" `
               -IsCompliant ($llmnr -eq 0) `
               -Details "LLMNR est actif, permettant l'interception de hashs NTLM" `
               -Remediation "Définir EnableMulticast = 0 dans HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
$Script:Results[-1].category = $category

# Signature SMB obligatoire
$smbSig = (Get-SmbServerConfiguration -ErrorAction SilentlyContinue).RequireSecuritySignature
Test-CheckItem -Id "WIN-NET-003" `
               -Severity "high" `
               -Description "Signature SMB requise (Anti-SMB Relay)" `
               -IsCompliant ($smbSig -eq $true) `
               -Details "RequireSecuritySignature est à False" `
               -Remediation "Activer RequireSecuritySignature via Set-SmbServerConfiguration"
$Script:Results[-1].category = $category

# ------------------------------------------------------------------------------
# 2. Audit Authentification & Protection Mémoire LSA
# ------------------------------------------------------------------------------
Write-Host "`n[2] Audit Authentification & Protection Identité" -ForegroundColor White
$category = "Authentification & Identité"

# NTLMv2 forcé (LmCompatibilityLevel = 5)
$lmLevel = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue).LmCompatibilityLevel
Test-CheckItem -Id "WIN-AUTH-001" `
               -Severity "high" `
               -Description "NTLMv2 forcé uniquement (LM & NTLMv1 refusés)" `
               -IsCompliant ($lmLevel -ge 5) `
               -Details "LmCompatibilityLevel < 5 (Hashs faibles autorisés)" `
               -Remediation "Définir LmCompatibilityLevel = 5 dans HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$Script:Results[-1].category = $category

# LSA Protection (RunAsPPL) contre le dumping Mimikatz
$lsaPPL = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue).RunAsPPL
Test-CheckItem -Id "WIN-AUTH-002" `
               -Severity "critical" `
               -Description "Protection mémoire LSA activée (Anti-Mimikatz)" `
               -IsCompliant ($lsaPPL -eq 1 -or $lsaPPL -eq 2) `
               -Details "LSA Protection désactivée, les hashs en mémoire sont extractibles" `
               -Remediation "Activer RunAsPPL = 1 dans HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$Script:Results[-1].category = $category

# ------------------------------------------------------------------------------
# 3. Audit Pare-feu Windows Defender
# ------------------------------------------------------------------------------
Write-Host "`n[3] Audit Pare-feu Windows Defender" -ForegroundColor White
$category = "Pare-feu"

$profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
$allEnabled = ($profiles | Where-Object { $_.Enabled -eq $true }).Count -eq 3
Test-CheckItem -Id "WIN-FW-001" `
               -Severity "critical" `
               -Description "Pare-feu actif sur tous les profils (Domain, Private, Public)" `
               -IsCompliant ($allEnabled) `
               -Details "Le pare-feu est désactivé sur au moins un profil" `
               -Remediation "Activer le pare-feu Windows Defender sur les 3 profils (Domain, Private, Public)"
$Script:Results[-1].category = $category

# ------------------------------------------------------------------------------
# 4. Audit Journalisation & Détection
# ------------------------------------------------------------------------------
Write-Host "`n[4] Audit Traçabilité & Journalisation des Événements" -ForegroundColor White
$category = "Journalisation"

# PowerShell Script Block Logging (Event ID 4104)
$psLog = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -ErrorAction SilentlyContinue).EnableScriptBlockLogging
Test-CheckItem -Id "WIN-LOG-001" `
               -Severity "medium" `
               -Description "PowerShell Script Block Logging activé (Event 4104)" `
               -IsCompliant ($psLog -eq 1) `
               -Details "Les commandes PowerShell malveillantes ne sont pas tracées dans les logs" `
               -Remediation "Activer EnableScriptBlockLogging = 1 dans les stratégies PowerShell"
$Script:Results[-1].category = $category

# ------------------------------------------------------------------------------
# Score Global
# ------------------------------------------------------------------------------
$Score = [math]::Round(($Passed / $Total) * 100)

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "RÉSULTATS DE L'AUDIT WINDOWS :" -ForegroundColor White
Write-Host "Tests réussis : $Passed / $Total" -ForegroundColor Green
Write-Host "Tests échoués : $Failed / $Total" -ForegroundColor Red

if ($Score -ge 80) {
    Write-Host "Score global  : $Score% (Niveau de sécurité ÉLEVÉ)" -ForegroundColor Green
} elseif ($Score -ge 50) {
    Write-Host "Score global  : $Score% (Niveau de sécurité MOYEN - Durcissement requis)" -ForegroundColor Yellow
} else {
    Write-Host "Score global  : $Score% (Niveau de sécurité CRITIQUE - Vulnérabilités multiples)" -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan

# Export JSON si demandé
if ($JsonExport) {
    if (-not (Test-Path -Path $OutputDir)) {
        New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    }

    $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
    if (-not $osCaption) {
        $osCaption = "Windows (Inconnu)"
    }

    $jsonOutput = [PSCustomObject]@{
        tool       = "autosec-hardening"
        version    = "1.1.0"
        timestamp  = (Get-Date).ToString("o")
        hostname   = $env:COMPUTERNAME
        os         = "windows"
        os_details = $osCaption.Trim()
        score      = $Score
        passed     = $Passed
        failed     = $Failed
        total      = $Total
        checks     = $Script:Results
    }

    $jsonStr = $jsonOutput | ConvertTo-Json -Depth 3
    $outFile = Join-Path -Path $OutputDir -ChildPath "audit_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $jsonStr | Out-File -FilePath $outFile -Encoding utf8
    
    Write-Host "`n[+] Rapport d'audit exporté vers : $outFile" -ForegroundColor Green
}
