param(
  [switch]$SkipGates
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $projectRoot

try {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required for content verification (node)."
  }

  Write-Host "[verify] validate-data" -ForegroundColor Cyan
  node scripts\validate-data.mjs

  Write-Host "[verify] audit-repo" -ForegroundColor Cyan
  node scripts\audit-repo.mjs

  if (-not $SkipGates) {
    Write-Host "[verify] aoe-gates validate-rpggo-usage" -ForegroundColor Cyan
    node scripts\aoe-gates.mjs validate-rpggo-usage

    Write-Host "[verify] aoe-gates gate-rpggo-hotloop" -ForegroundColor Cyan
    node scripts\aoe-gates.mjs gate-rpggo-hotloop

    Write-Host "[verify] aoe-gates gate-httprequest-hotloop" -ForegroundColor Cyan
    node scripts\aoe-gates.mjs gate-httprequest-hotloop

    Write-Host "[verify] aoe-gates gate-secrets" -ForegroundColor Cyan
    node scripts\aoe-gates.mjs gate-secrets

    Write-Host "[verify] aoe-gates gate-rpggo-event-ids" -ForegroundColor Cyan
    node scripts\aoe-gates.mjs gate-rpggo-event-ids
  }

  Write-Host "[verify] OK" -ForegroundColor Green
} finally {
  Pop-Location
}
