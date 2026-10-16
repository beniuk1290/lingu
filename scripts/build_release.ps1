# build_release.ps1 — buduje APK LingoPilot na tej maszynie
# Użycie: powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1 [-Debug]
param([switch]$Debug)

$ErrorActionPreference = "Continue"

# --- Toolchain (zainstalowany ręcznie w C:\dev) ---
$env:JAVA_HOME      = "C:\dev\jdk_extract\jdk-17.0.20.1+1"
$env:ANDROID_HOME   = "C:\dev\android"
$env:ANDROID_SDK_ROOT = "C:\dev\android"
$env:PUB_CACHE      = "C:\dev\pub-cache"
$env:PATH           = "C:\dev\flutter\bin;C:\dev\mingit\cmd;C:\dev\jdk_extract\jdk-17.0.20.1+1\bin;C:\dev\android\cmdline-tools\latest\bin;" + $env:PATH

# --- Dlaczego junction C:\dev\lp? ---
# Ścieżka projektu zawiera "ś" ("Projekt domyślny"). Gradle i gen_snapshot
# gubią ten znak (błędy kodowania), więc release budujemy przez junction
# o ASCII-owej nazwie. Pliki są identyczne — edytuj w oryginalnym folderze.
$junction = "C:\dev\lp"
$real     = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $junction)) {
    cmd /c "mklink /J `"$junction`" `"$real`"" | Out-Null
}

Set-Location $junction
$mode = if ($Debug) { "--debug" } else { "--release" }
flutter build apk $mode

$apk = if ($Debug) { "build\app\outputs\flutter-apk\app-debug.apk" } else { "build\app\outputs\flutter-apk\app-release.apk" }
if (Test-Path $apk) {
    New-Item -ItemType Directory -Force "dist" | Out-Null
    Copy-Item $apk "dist\" -Force
    $f = Get-Item "dist\$(Split-Path $apk -Leaf)"
    Write-Host ("OK: {0} ({1:N1} MB)" -f $f.FullName, ($f.Length / 1MB)) -ForegroundColor Green
} else {
    Write-Host "BUILD NIEUDANY" -ForegroundColor Red
}
