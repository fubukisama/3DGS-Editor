$ErrorActionPreference = "Stop"

$InstallDrive = Split-Path -Qualifier (Resolve-Path (Join-Path $PSScriptRoot ".."))
$InstallRoot = "$InstallDrive\"
$GaussianEnv = $env:GAUSSIAN_SPLATTING_CONDA_PREFIX
if (-not $GaussianEnv) {
    $GaussianEnv = $env:GS_CONDA_PREFIX
}
if (-not $GaussianEnv) {
    $Candidates = @(
        (Join-Path $InstallRoot "miniforge3\envs\gaussian_splatting"),
        (Join-Path $InstallRoot "conda\envs\gaussian_splatting"),
        (Join-Path $InstallRoot "anaconda\envs\gaussian_splatting"),
        (Join-Path $env:USERPROFILE "miniforge3\envs\gaussian_splatting"),
        (Join-Path $env:USERPROFILE "miniconda3\envs\gaussian_splatting"),
        (Join-Path $env:USERPROFILE "anaconda3\envs\gaussian_splatting")
    )
    $GaussianEnv = $Candidates | Where-Object { Test-Path (Join-Path $_ "python.exe") } | Select-Object -First 1
}
$CondaRoot = $env:CONDA_ROOT
if (-not $CondaRoot) {
    $CondaRootCandidates = @(
        (Join-Path $InstallRoot "miniforge3"),
        (Join-Path $InstallRoot "anaconda"),
        (Join-Path $InstallRoot "conda"),
        (Join-Path $env:USERPROFILE "miniforge3"),
        (Join-Path $env:USERPROFILE "miniconda3"),
        (Join-Path $env:USERPROFILE "anaconda3")
    )
    $CondaRoot = $CondaRootCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$ColmapBin = Join-Path $env:USERPROFILE "Downloads\colmap-x64-windows-cuda\bin"
if ($GaussianEnv -and (Test-Path $GaussianEnv)) {
    $env:GAUSSIAN_SPLATTING_CONDA_PREFIX = $GaussianEnv
    $env:GS_CONDA_PREFIX = $GaussianEnv
    $env:CONDA_PREFIX = $GaussianEnv
    $env:Path = "$GaussianEnv;$GaussianEnv\Library\bin;$GaussianEnv\Library\usr\bin;$GaussianEnv\Scripts;$env:Path"
}
if ($CondaRoot -and (Test-Path $CondaRoot)) {
    $env:Path = "$CondaRoot;$CondaRoot\Scripts;$CondaRoot\condabin;$env:Path"
}
if (Test-Path $ColmapBin) {
    $env:Path = "$ColmapBin;$env:Path"
}

$PythonExecutable = "python"
if ($GaussianEnv) {
    $EnvironmentPython = Join-Path $GaussianEnv "python.exe"
    if (Test-Path -LiteralPath $EnvironmentPython) {
        $PythonExecutable = $EnvironmentPython
    }
}
$CondaExecutable = "conda"
if ($CondaRoot) {
    $CondaCandidates = @(
        (Join-Path $CondaRoot "Scripts\conda.exe"),
        (Join-Path $CondaRoot "condabin\conda.bat")
    )
    $ResolvedConda = $CondaCandidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if ($ResolvedConda) {
        $CondaExecutable = $ResolvedConda
    }
}

$FailedChecks = [System.Collections.Generic.List[string]]::new()

function Add-FailedCheck {
    param(
        [string]$Name,
        [string]$Reason
    )

    $script:FailedChecks.Add("$Name ($Reason)")
    Write-Host "Missing or unavailable: $Reason" -ForegroundColor Red
}

function Test-Tool {
    param(
        [string]$Name,
        [string]$Executable,
        [string[]]$Arguments = @()
    )

    Write-Host ""
    Write-Host "== $Name =="
    $Resolved = Get-Command $Executable -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $Resolved) {
        Add-FailedCheck -Name $Name -Reason "$Executable was not found in PATH"
        return
    }

    try {
        & $Resolved.Source @Arguments
        if ($LASTEXITCODE -ne 0) {
            Add-FailedCheck -Name $Name -Reason "$Executable exited with code $LASTEXITCODE"
        }
    } catch {
        Add-FailedCheck -Name $Name -Reason $_.Exception.Message
    }
}

Test-Tool -Name "NVIDIA GPU driver" -Executable "nvidia-smi"
Test-Tool -Name "Python" -Executable $PythonExecutable -Arguments @("--version")
Test-Tool -Name "Python media dependencies" -Executable $PythonExecutable -Arguments @(
    "-c",
    "import numpy, plyfile; print('numpy', numpy.__version__, 'plyfile', plyfile.__version__ if hasattr(plyfile, '__version__') else 'available')"
)
Test-Tool -Name "Conda" -Executable $CondaExecutable -Arguments @("--version")
Test-Tool -Name "Git" -Executable "git" -Arguments @("--version")
Test-Tool -Name "COLMAP" -Executable "colmap" -Arguments @("-h")
Test-Tool -Name "CUDA compiler" -Executable "nvcc" -Arguments @("--version")

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
            Add-FailedCheck -Name "Visual Studio C++ compiler" -Reason "C++ workload is not installed"
        }
    } else {
        Add-FailedCheck -Name "Visual Studio C++ compiler" -Reason "cl.exe and vswhere.exe are unavailable"
    }
}

Write-Host ""
if ($FailedChecks.Count -gt 0) {
    Write-Host "Environment check failed:" -ForegroundColor Red
    foreach ($Failure in $FailedChecks) {
        Write-Host " - $Failure" -ForegroundColor Red
    }
    Write-Host "If a tool is installed but still shown as missing, open a fresh PowerShell window or add it to PATH."
    exit 1
}

Write-Host "All required 3DGS environment checks passed." -ForegroundColor Green
exit 0
