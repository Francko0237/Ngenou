<#
.SYNOPSIS
    Script de publication dynamique des versions Ngenou (Mobile & Web)

.DESCRIPTION
    Automatise l'enregistrement de la version dans Supabase, lie les captures d'écran
    hébergées sur GitHub / CDN, et prépare la release GitHub.

.EXAMPLE
    .\publish-release.ps1
    .\publish-release.ps1 -Title "Mise à jour majeure" -Notes "Nouvel algorithme et interface"
    .\publish-release.ps1 -Bump "1.2.0+2" -Title "Version 1.2.0" -Force
    .\publish-release.ps1 -DryRun
#>

param(
    [string]$Title,
    [string]$Notes,
    [string]$Bump,
    [switch]$Force,
    [switch]$DryRun
)

$argsList = @()

if ($Title) {
    $argsList += "--title=$Title"
}
if ($Notes) {
    $argsList += "--notes=$Notes"
}
if ($Bump) {
    $argsList += "--bump=$Bump"
}
if ($Force) {
    $argsList += "--force"
}
if ($DryRun) {
    $argsList += "--dry-run"
}

Write-Host "Lancement de la publication Ngenou..." -ForegroundColor Cyan
dart run tool/publish_release.dart $argsList
