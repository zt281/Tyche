# Tyche Engine 启动脚本
# 用法: .\scripts\start-engine.ps1 [-Mode <cpp|python>] [-BasePort <int>]

param(
    [ValidateSet("cpp", "python")]
    [string]$Mode = "cpp",
    [int]$BasePort = 7700
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "=== Tyche Engine Startup ===" -ForegroundColor Cyan
Write-Host "Mode: $Mode"
Write-Host "Base Port: $BasePort"
Write-Host "Repo Root: $RepoRoot"

# 启动引擎
if ($Mode -eq "cpp") {
    $EngineExe = Join-Path $RepoRoot "core\cpp\build\tyche_engine.exe"
    if (-not (Test-Path $EngineExe)) {
        $EngineExe = Join-Path $RepoRoot "core\cpp\build\Release\tyche_engine.exe"
    }
    if (-not (Test-Path $EngineExe)) {
        Write-Error "C++ engine not found. Please build it first: cd core\cpp && cmake -B build && cmake --build build"
        exit 1
    }
    Write-Host "Starting C++ Engine..." -ForegroundColor Green
    & $EngineExe --config (Join-Path $RepoRoot "config\tyche_engine.json") --base-port $BasePort
} else {
    Write-Host "Starting Python Engine..." -ForegroundColor Green
    python -m tyche.engine_main --base-port $BasePort
}
