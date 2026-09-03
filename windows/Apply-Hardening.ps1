<#
==============================================================================
 AutoSec-Hardener : Script d'Application du Durcissement Windows
 Fichier : windows/Apply-Hardening.ps1
 Usage   : powershell -ExecutionPolicy Bypass -File .\Apply-Hardening.ps1
==============================================================================
#>

# Vérification des privilèges Administrateur requis
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "[-] Ce script doit être exécuté dans une invite PowerShell 'En tant qu'administrateur'."
    exit 1
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = "C:\WindowsBackups_AutoSec_$Timestamp"

Write-Host "[+] Création du point de sauvegarde dans : $BackupDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

# 1. Sauvegarde des clés de registre critiques
Write-Host "[+] Sauvegarde des clés de registre..." -ForegroundColor Cyan
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" "$BackupDir\Lsa_backup.reg" /y | Out-Null
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "$BackupDir\DNSClient_backup.reg" /y 2>$null

# 2. Désactivation de SMBv1
Write-Host "[+] Désactivation du protocole vulnérable SMBv1..." -ForegroundColor Green
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue

# 3. Forcer la signature SMB (Anti-SMB Relay)
Write-Host "[+] Activation obligatoire de la signature SMB..." -ForegroundColor Green
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue
Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue

# 4. Désactivation de LLMNR (Anti-Responder / Vol d'identifiants)
Write-Host "[+] Désactivation de LLMNR..." -ForegroundColor Green
$dnsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
if (-not (Test-Path $dnsPolicyPath)) { New-Item -Path $dnsPolicyPath -Force | Out-Null }
Set-ItemProperty -Path $dnsPolicyPath -Name "EnableMulticast" -Value 0 -Type DWord

# 5. Sécurisation NTLM (Forcer NTLMv2 uniquement - Rejeter LM/NTLMv1)
Write-Host "[+] Durcissement NTLM (Niveau 5 : NTLMv2 uniquement)..." -ForegroundColor Green
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 5 -Type DWord

# 6. Activation de la protection mémoire LSA (RunAsPPL - Anti-Mimikatz)
Write-Host "[+] Activation de la protection LSA RunAsPPL..." -ForegroundColor Green
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord

# 7. Activation et durcissement du Pare-feu Windows Defender
Write-Host "[+] Activation du pare-feu sur tous les profils (Domain, Private, Public)..." -ForegroundColor Green
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow

# 8. Activation de la journalisation des blocs de scripts PowerShell (Event 4104)
Write-Host "[+] Activation du Script Block Logging pour PowerShell..." -ForegroundColor Green
$psLogPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if (-not (Test-Path $psLogPath)) { New-Item -Path $psLogPath -Force | Out-Null }
Set-ItemProperty -Path $psLogPath -Name "EnableScriptBlockLogging" -Value 1 -Type DWord

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "[✓] DURCISSEMENT WINDOWS APPLIQUÉ AVEC SUCCÈS !" -ForegroundColor Green
Write-Host "[i] Sauvegarde stockée dans : $BackupDir" -ForegroundColor Gray
Write-Host "[i] Un redémarrage système est recommandé pour finaliser la protection LSA." -ForegroundColor Yellow
Write-Host "[i] Vous pouvez exécuter '.\Audit-Security.ps1' pour valider le score." -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
