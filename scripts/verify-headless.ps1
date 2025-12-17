param(
  [Parameter(Mandatory=$true)][string]$GodotExe
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Test-Path -LiteralPath $GodotExe)) {
  throw "Godot executable not found at: $GodotExe"
}

Push-Location $projectRoot
try {
  Write-Host "[headless] Running Godot smoke + tests" -ForegroundColor Cyan
  & $GodotExe --headless --path $projectRoot -- --run-tests

  if ($LASTEXITCODE -ne 0) {
    throw "Godot headless tests failed (exit=$LASTEXITCODE)"
  }

  Write-Host "[headless] OK" -ForegroundColor Green
} finally {
  Pop-Location
}
