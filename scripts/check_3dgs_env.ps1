$ErrorActionPreference = "Continue"

$InstallDrive = Split-Path -Qualifier (Resolve-Path (Join-Path $PSScriptRoot ".."))
$InstallRoot = "$InstallDrive\"
$GaussianEnv = $env:GAUSSIAN_SPLATTING_CONDA_PREFIX
if (-not $GaussianEnv) {
    $Candidates = @(
        (Join-Path $InstallRoot "miniforge3\envs\gaussian_splatting"),
        (Join-Path $InstallRoot "conda\envs\gaussian_splatting"),
        (Join-Path $InstallRoot "anaconda\envs\gaussian_splatting"),
        (Join-Path $env:USERPROFILE "miniforge3\envs\gaussian_splatting")
    )
    $GaussianEnv = $Candidates | Where-Object { Test-Path (Join-Path $_ "python.exe") } | Select-Object -First 1
}
$CondaRoot = $env:CONDA_ROOT
if (-not $CondaRoot) {
    $CondaRootCandidates = @(
        (Join-Path $InstallRoot "miniforge3"),
        (Join-Path $InstallRoot "anaconda"),
        (Join-Path $InstallRoot "conda"),
        (Join-Path $env:USERPROFILE "miniforge3")
    )
    $CondaRoot = $CondaRootCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$ColmapCandidates = @($env:COLMAP_PATH, $env:COLMAP_EXE) | Where-Object { $_ }
$ColmapCandidates += @(
    (Join-Path $InstallRoot "COLMAP\bin\colmap.exe"),
    (Join-Path $env:USERPROFILE "Downloads\colmap-x64-windows-cuda\bin\colmap.exe")
)
$VersionedColmapRoot = Join-Path $InstallRoot "Tools\COLMAP"
if (Test-Path -LiteralPath $VersionedColmapRoot) {
    $ColmapCandidates += Get-ChildItem -LiteralPath $VersionedColmapRoot -Directory |
        Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
        ForEach-Object { Join-Path $_.FullName "bin\colmap.exe" }
}
$ColmapExe = $ColmapCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if ($GaussianEnv -and (Test-Path $GaussianEnv)) {
    $env:GAUSSIAN_SPLATTING_CONDA_PREFIX = $GaussianEnv
    $env:CONDA_PREFIX = $GaussianEnv
    $env:Path = "$GaussianEnv;$GaussianEnv\Library\bin;$GaussianEnv\Library\usr\bin;$GaussianEnv\Scripts;$env:Path"
}
if ($CondaRoot -and (Test-Path $CondaRoot)) {
    $env:Path = "$CondaRoot;$CondaRoot\Scripts;$CondaRoot\condabin;$env:Path"
}
if ($ColmapExe) {
    $env:COLMAP_PATH = $ColmapExe
    $env:COLMAP_EXE = $ColmapExe
    $env:Path = "$(Split-Path -Parent $ColmapExe);$env:Path"
}

function Test-Tool {
    param(
        [string]$Name,
        [string]$Command
    )

    Write-Host ""
    Write-Host "== $Name =="
    try {
        Invoke-Expression $Command
    } catch {
        Write-Host "Missing or not available in PATH"
    }
}

Test-Tool "NVIDIA GPU driver" "nvidia-smi"
Test-Tool "Python" "python --version"
Test-Tool "Conda" "conda --version"
Test-Tool "Git" "git --version"
if ($ColmapExe) {
    Test-Tool "COLMAP" "& `"$ColmapExe`" -h"
} else {
    Test-Tool "COLMAP" "colmap -h"
}
Test-Tool "CUDA compiler" "nvcc --version"

Write-Host ""
Write-Host "== Visual Studio C++ compiler =="
$cl = Get-Command cl.exe -ErrorAction SilentlyContinue
if ($cl) {
    Write-Host $cl.Source
} else {
    $VsWhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $VsWhere) {
        $VsPath = & $VsWhere -products * -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath
        if ($VsPath) {
            Write-Host "Installed at $VsPath"
            Write-Host "Use scripts\open_3dgs_shell.bat before building 3DGS."
        } else {
            Write-Host "Missing Visual Studio C++ workload"
        }
    } else {
        Write-Host "Missing or not available in PATH"
    }
}

Write-Host ""
Write-Host "If a tool is installed but still shown as missing, open a fresh PowerShell window or add it to PATH."
