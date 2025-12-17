param(
  [Parameter(Mandatory=$false)][string]$GodotExe = "E:\Godot\Godot_v4.5.1-stable_win64.exe",
  [switch]$Editor
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path -LiteralPath $GodotExe)) {
  throw "Godot executable not found at: $GodotExe"
}

Write-Host "Launching Godot from: $GodotExe"
Write-Host "Project: $projectRoot"

if ($Editor) {
  & $GodotExe --path $projectRoot --editor
} else {
  & $GodotExe --path $projectRoot
}
