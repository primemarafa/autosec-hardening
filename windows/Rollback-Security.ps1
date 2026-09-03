<#
==============================================================================
 AutoSec-Hardener : Script de Restauration Windows (Rollback)
 Fichier : windows/Rollback-Security.ps1
 Usage   : powershell -ExecutionPolicy Bypass -File .\Rollback-Security.ps1
==============================================================================
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "[-] Ce script doit être exécuté dans une invite PowerShell 'En tant qu'administrateur'."
    exit 1
}

$lastBackup = Get-ChildItem -Path "C:\" -Directory -Filter "WindowsBackups_AutoSec_*" | Sort-Object CreationTime -Descending | Select-Object -First 1

if (-not $lastBackup) {
    Write-Warning "[-] Aucun dossier de sauvegarde 'WindowsBackups_AutoSec_*' trouvé à la racine C:\"
    exit 1
}

Write-Host "[?] Dernière sauvegarde détectée : $($lastBackup.FullName)" -ForegroundColor Yellow
$response = Read-Host "Confirmez-vous la restauration ? (O/N)"

if ($response -match "^[oOyY]$") {
    Write-Host "[+] Restauration des clés de registre..." -ForegroundColor Cyan
    
    if (Test-Path "$($lastBackup.FullName)\Lsa_backup.reg") {
        reg import "$($lastBackup.FullName)\Lsa_backup.reg" | Out-Null
    }
    if (Test-Path "$($lastBackup.FullName)\DNSClient_backup.reg") {
        reg import "$($lastBackup.FullName)\DNSClient_backup.reg" | Out-Null
    }

    # Réactiver LLMNR
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue

    Write-Host "[✓] Restauration terminée avec succès !" -ForegroundColor Green
} else {
    Write-Host "[-] Annulation." -ForegroundColor Gray
}
