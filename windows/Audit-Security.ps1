<#
==============================================================================
 AutoSec-Hardener : Script d'Audit de Sécurité Windows (ANSSI / CIS Benchmark)
 Fichier : windows/Audit-Security.ps1
 Usage   : powershell -ExecutionPolicy Bypass -File .\Audit-Security.ps1
==============================================================================
#>

# Vérification des privilèges Administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Avertissement : Lancez PowerShell en tant qu'Administrateur pour un audit complet." -ForegroundColor Yellow
}

$Passed = 0
$Failed = 0
$Total = 0

function Test-CheckItem {
    param (
        [string]$Description,
        [bool]$IsCompliant,
        [string]$Details
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
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   AUTODEFENSE & SECURITY AUDITOR - WINDOWS SERVER / CLIENT " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. Audit Réseau & Protocoles Obsolètes
# ------------------------------------------------------------------------------
Write-Host "`n[1] Audit Réseau & Protocoles d'Échange" -ForegroundColor White

# SMBv1
$smb1 = (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue).State
Test-CheckItem -Description "Protocole obsolète SMBv1 désactivé" `
               -IsCompliant ($smb1 -ne "Enabled") `
               -Details "SMBv1 est actif (Vulnérabilité critique type WannaCry/EternalBlue)"

# LLMNR (Link-Local Multicast Name Resolution)
$llmnr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue).EnableMulticast
Test-CheckItem -Description "Protocole LLMNR désactivé (Anti-Responder/MitM)" `
               -IsCompliant ($llmnr -eq 0) `
               -Details "LLMNR est actif, permettant l'interception de hashs NTLM"

# Signature SMB obligatoire
$smbSig = (Get-SmbServerConfiguration -ErrorAction SilentlyContinue).RequireSecuritySignature
Test-CheckItem -Description "Signature SMB requise (Anti-SMB Relay)" `
               -IsCompliant ($smbSig -eq $true) `
               -Details "RequireSecuritySignature est à False"

# ------------------------------------------------------------------------------
# 2. Audit Authentification & Protection Mémoire LSA
# ------------------------------------------------------------------------------
Write-Host "`n[2] Audit Authentification & Protection Identité" -ForegroundColor White

# NTLMv2 forcé (LmCompatibilityLevel = 5)
$lmLevel = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue).LmCompatibilityLevel
Test-CheckItem -Description "NTLMv2 forcé uniquement (LM & NTLMv1 refusés)" `
               -IsCompliant ($lmLevel -ge 5) `
               -Details "LmCompatibilityLevel < 5 (Hashs faibles autorisés)"

# LSA Protection (RunAsPPL) contre le dumping Mimikatz
$lsaPPL = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue).RunAsPPL
Test-CheckItem -Description "Protection mémoire LSA activée (Anti-Mimikatz)" `
               -IsCompliant ($lsaPPL -eq 1 -or $lsaPPL -eq 2) `
               -Details "LSA Protection désactivée, les hashs en mémoire sont extractibles"

# ------------------------------------------------------------------------------
# 3. Audit Pare-feu Windows Defender
# ------------------------------------------------------------------------------
Write-Host "`n[3] Audit Pare-feu Windows Defender" -ForegroundColor White

$profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
$allEnabled = ($profiles | Where-Object { $_.Enabled -eq $true }).Count -eq 3
Test-CheckItem -Description "Pare-feu actif sur tous les profils (Domain, Private, Public)" `
               -IsCompliant ($allEnabled) `
               -Details "Le pare-feu est désactivé sur au moins un profil"

# ------------------------------------------------------------------------------
# 4. Audit Journalisation & Détection
# ------------------------------------------------------------------------------
Write-Host "`n[4] Audit Traçabilité & Journalisation des Événements" -ForegroundColor White

# PowerShell Script Block Logging (Event ID 4104)
$psLog = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -ErrorAction SilentlyContinue).EnableScriptBlockLogging
Test-CheckItem -Description "PowerShell Script Block Logging activé (Event 4104)" `
               -IsCompliant ($psLog -eq 1) `
               -Details "Les commandes PowerShell malveillantes ne sont pas tracées dans les logs"

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
