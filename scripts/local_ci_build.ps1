<#
Local CI build script for Windows (PowerShell)
- Creates a fresh venv at .local_build_env
- Installs pinned build backend and helpers
- Runs `python -m build --no-isolation -w` in ./arbitrex
- Runs a smoke-test by installing the produced wheel into the venv and importing `arbitrex`
Usage: From repository root, run `powershell -ExecutionPolicy Bypass -File .\scripts\local_ci_build.ps1`
#>

$ErrorActionPreference = 'Stop'

$venvDir = '.local_build_env'
if (Test-Path $venvDir) {
    Write-Host "Removing existing venv: $venvDir"
    Remove-Item -Recurse -Force $venvDir
}

Write-Host "Creating venv at $venvDir"
python -m venv $venvDir
$py = Join-Path $venvDir 'Scripts\python.exe'

Write-Host "Upgrading pip and installing pinned build backend and tools into venv"
& $py -m pip install --upgrade pip
& $py -m pip install --upgrade "scikit-build-core==0.11.6" "build>=1.3.0" pyproject_hooks cmake ninja
# optional helpers (speeds repeated runs; pyarrow optional)
& $py -m pip install --upgrade pybind11 pyarrow || Write-Host "optional pyarrow install failed; continuing"

# Run the build
Push-Location 'arbitrex'
Write-Host "Running build (no-isolation) in $(Get-Location) using $py"
& $py -m build --no-isolation -w --verbose .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed (exit $LASTEXITCODE)"
    Pop-Location
    exit $LASTEXITCODE
}
Pop-Location

# Package found: pick most recent wheel
$distDir = Join-Path (Get-Location) 'arbitrex\dist'
if (-not (Test-Path $distDir)) { Write-Error "dist directory not found: $distDir"; exit 2 }
$whl = Get-ChildItem -Path $distDir -Filter *.whl | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $whl) { Write-Error "No wheel found in $distDir"; exit 2 }
Write-Host "Found wheel: $($whl.FullName)"

# Smoke-test: install the generated wheel into the same venv and import
Write-Host "Installing built wheel into venv and testing import"
& $py -m pip install --upgrade pip setuptools wheel
& $py -m pip install --no-deps --force-reinstall "$($whl.FullName)"

$importCmd = 'import importlib,traceback,sys; ' +
             'try:\n    importlib.import_module("arbitrex");\n    print("IMPORT OK")\nexcept Exception:\n    traceback.print_exc(); sys.exit(4)'

& $py -c $importCmd
if ($LASTEXITCODE -ne 0) { Write-Error "Smoke-test import failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

Write-Host "Local CI build and smoke test succeeded. Clean up: leaving venv at $venvDir (remove manually if desired)"
exit 0
