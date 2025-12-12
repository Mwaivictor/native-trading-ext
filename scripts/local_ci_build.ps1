<#
Local CI build script for Windows (PowerShell)
- Creates a fresh venv at .local_build_env
- Installs pinned build backend and tools
- Supports optional Arrow build via -EnableArrow $true
- Runs `python -m build --no-isolation -w` in ./arbitrex
- Smoke-tests the produced wheel by installing and importing `arbitrex`
#>

param (
    [string]$EnableArrow = 'false'
)

$ErrorActionPreference = 'Stop'

$venvDir = '.local_build_env'
if (Test-Path $venvDir) {
    Write-Host "Removing existing venv: $venvDir"
    Remove-Item -Recurse -Force $venvDir
}

Write-Host "Creating venv at $venvDir"
python -m venv $venvDir

$venvFull = (Resolve-Path $venvDir).Path
$py = Join-Path $venvFull 'Scripts\python.exe'

$env:PATH = "$venvFull\Scripts;$env:PATH"

Write-Host "Upgrading pip and installing pinned build tools"
& $py -m pip install --upgrade pip setuptools wheel
& $py -m pip install --upgrade "scikit-build-core==0.11.6" "build>=1.3.0" pyproject_hooks cmake ninja pybind11

Write-Host "Installing pyarrow (optional)"
& $py -m pip install --upgrade pyarrow

$arbitrexDir = Join-Path (Get-Location) 'arbitrex'
if (-not (Test-Path $arbitrexDir)) {
    Write-Error "arbitrex directory not found: $arbitrexDir"
    exit 2
}

Push-Location $arbitrexDir

Write-Host "`n=== Building in: $(Get-Location) ==="
Write-Host "EnableArrow = $EnableArrow"
Write-Host "--- pyproject.toml preview (first 20 lines) ---"
Get-Content pyproject.toml -First 20 | ForEach-Object { Write-Host $_ }

$cmakeArgs = "-DBUILD_ARROW=OFF"

if ($EnableArrow -eq 'true' -or $EnableArrow -eq '1') {
    $vcpkgRoot = "C:\vcpkg"
    $toolchain = Join-Path $vcpkgRoot "scripts\buildsystems\vcpkg.cmake"

    if (Test-Path $toolchain) {
        Write-Host "Arrow enabled: using vcpkg toolchain"
        $cmakeArgs = "-DBUILD_ARROW=ON -DCMAKE_TOOLCHAIN_FILE=$toolchain"
    } else {
        Write-Warning "vcpkg toolchain not found, BUILD_ARROW=OFF"
    }
}

Write-Host "CMAKE_ARGS = $cmakeArgs"
$env:CMAKE_ARGS = $cmakeArgs

try {
    Write-Host "`nRunning build (no-isolation) with $py"

    $buildDir = Join-Path (Get-Location) 'build'
    if (Test-Path $buildDir) {
        Write-Host "Removing existing CMake build directory at $buildDir"
        Remove-Item -Recurse -Force $buildDir
    }

    # Detect Python architecture and choose a matching Visual Studio generator
    $pyArchRaw = & $py -c "import struct; print('x64' if struct.calcsize('P')*8==64 else 'Win32')"
    $pyArch = $pyArchRaw.Trim()
    Write-Host "Detected Python architecture: $pyArch"

    $vsGen = 'Visual Studio 17 2022'
    # Use doubled double-quotes to embed a quoted generator name inside the string
    $genArg = "-G ""$vsGen"" -A $pyArch"
    $cmakeCmd = "cmake -S native -B build $genArg $env:CMAKE_ARGS -DCMAKE_BUILD_TYPE=Release"
    Write-Host "Pre-configuring CMake: $cmakeCmd"
    iex $cmakeCmd

    Write-Host "Invoking python -m build"
    & $py -m build --no-isolation -w --verbose .
}
finally {
    Pop-Location
}

$distDir = Join-Path $arbitrexDir 'dist'
if (-not (Test-Path $distDir)) {
    Write-Error "dist directory not found: $distDir"
    exit 2
}

$whl = Get-ChildItem -Path $distDir -Filter *.whl |
       Sort-Object LastWriteTime -Descending |
       Select-Object -First 1

if (-not $whl) {
    Write-Error "No wheel found in $distDir"
    exit 2
}

Write-Host "`nFound wheel: $($whl.FullName)"
Write-Host "`nInstalling wheel for smoke-test"
& $py -m pip install --no-deps --force-reinstall "$($whl.FullName)"

$importScript = @'
import importlib, traceback, sys
try:
    m = importlib.import_module("arbitrex")
    from arbitrex import native_mt5
    print("IMPORT SUCCESS")
except Exception as e:
    traceback.print_exc()
    print("IMPORT FAILED")
    sys.exit(1)
'@

& $py -c $importScript

Write-Host "`nLOCAL CI BUILD + SMOKE TEST SUCCEEDED!"
Write-Host "Wheel available at: $($whl.FullName)"

exit 0