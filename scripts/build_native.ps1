param(
  [ValidateSet("Debug", "RelWithDebInfo", "Release")]
  [string]$Configuration = "RelWithDebInfo",
  [string]$QtRoot = "",
  [string]$BuildDirectory = "",
  [switch]$Clean,
  [switch]$Package
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$NativeRoot = Join-Path $Root "native"
$DriveRoot = Split-Path -Qualifier $Root
$BuildManifestPath = Join-Path $NativeRoot "build_manifest.json"
if (-not (Test-Path -LiteralPath $BuildManifestPath)) {
  throw "Native build manifest not found: $BuildManifestPath"
}
$BuildManifest = Get-Content -LiteralPath $BuildManifestPath -Raw | ConvertFrom-Json
$ReleaseDate = [string]$BuildManifest.releaseDate
if ($ReleaseDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
  throw "Native build manifest contains an invalid releaseDate: $ReleaseDate"
}

if ([string]::IsNullOrWhiteSpace($QtRoot)) {
  $QtCandidates = @(
    $env:GSW_NATIVE_QT_ROOT,
    $env:CONDA_PREFIX,
    (Join-Path $env:USERPROFILE "miniforge3\envs\gsw_native"),
    (Join-Path $env:USERPROFILE "miniconda3\envs\gsw_native"),
    (Join-Path $env:USERPROFILE "anaconda3\envs\gsw_native"),
    (Join-Path $DriveRoot "conda\envs\gsw_native"),
    "E:\conda\envs\gsw_native"
  ) | Where-Object {
    $_ -and (Test-Path -LiteralPath ([IO.Path]::Combine(
      [string]$_,
      "Library\lib\cmake\Qt6\Qt6Config.cmake"
    )))
  }
  $QtRoot = $QtCandidates | Select-Object -First 1
}

if (-not $QtRoot -or -not (Test-Path -LiteralPath (Join-Path $QtRoot "Library\lib\cmake\Qt6\Qt6Config.cmake"))) {
  throw "Qt 6 environment not found. Set GSW_NATIVE_QT_ROOT or pass -QtRoot."
}

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
  $BuildDirectory = Join-Path $NativeRoot "build"
}

$VsDevCmdCandidates = @(
  (Join-Path $DriveRoot "vsi\Common7\Tools\VsDevCmd.bat"),
  "E:\vsi\Common7\Tools\VsDevCmd.bat",
  "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat",
  "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat",
  "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
) | Where-Object { Test-Path -LiteralPath $_ }
$VsDevCmd = $VsDevCmdCandidates | Select-Object -First 1
if (-not $VsDevCmd) {
  throw "Visual Studio C++ build environment not found."
}

function Import-VisualStudioEnvironment {
  param([Parameter(Mandatory = $true)][string]$ScriptPath)

  $command = '"{0}" -no_logo -arch=x64 && set' -f $ScriptPath
  $environmentLines = & $env:ComSpec /d /s /c $command
  if ($LASTEXITCODE -ne 0) {
    throw "VsDevCmd failed with exit code $LASTEXITCODE."
  }
  foreach ($line in $environmentLines) {
    if ($line -match '^([^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
    }
  }
}

function Copy-AppLocalDependencies {
  param(
    [Parameter(Mandatory = $true)][string]$PackageBin,
    [Parameter(Mandatory = $true)][string[]]$SearchRoots
  )

  $DumpBin = (Get-Command dumpbin.exe -ErrorAction Stop).Source
  $available = @{}
  foreach ($searchRoot in $SearchRoots) {
    if (-not $searchRoot -or -not (Test-Path -LiteralPath $searchRoot)) { continue }
    Get-ChildItem -LiteralPath $searchRoot -Filter *.dll -File -ErrorAction SilentlyContinue | ForEach-Object {
      if (-not $available.ContainsKey($_.Name)) {
        $available[$_.Name] = $_.FullName
      }
    }
  }

  $present = @{}
  Get-ChildItem -LiteralPath $PackageBin -Recurse -File | Where-Object { $_.Extension -in ".dll", ".exe" } | ForEach-Object {
    $present[$_.Name] = $_.FullName
  }

  $queue = [System.Collections.Generic.Queue[string]]::new()
  foreach ($path in $present.Values) { $queue.Enqueue($path) }
  $processed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  while ($queue.Count -gt 0) {
    $binary = $queue.Dequeue()
    if (-not $processed.Add($binary)) { continue }
    $dependencyOutput = & $DumpBin /nologo /dependents $binary 2>$null
    foreach ($line in $dependencyOutput) {
      if ($line -notmatch '^\s+([A-Za-z0-9_.+\-]+\.dll)\s*$') { continue }
      $dependency = $Matches[1]
      if ($present.ContainsKey($dependency) -or -not $available.ContainsKey($dependency)) { continue }
      $destination = Join-Path $PackageBin $dependency
      Copy-Item -LiteralPath $available[$dependency] -Destination $destination -Force
      $present[$dependency] = $destination
      $queue.Enqueue($destination)
      Write-Host "Adding app-local dependency $dependency"
    }
  }
}

function Resolve-SafeRemovalDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$AllowedParent
  )

  $TargetItem = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  $ParentItem = Get-Item -LiteralPath $AllowedParent -Force -ErrorAction Stop
  if (-not $TargetItem.PSIsContainer) {
    throw "Refusing to recursively remove a non-directory path: $($TargetItem.FullName)"
  }
  if (-not $ParentItem.PSIsContainer) {
    throw "Removal boundary is not a directory: $($ParentItem.FullName)"
  }
  if (($ParentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Refusing to remove through a reparse-point boundary: $($ParentItem.FullName)"
  }

  $ResolvedTarget = [IO.Path]::GetFullPath($TargetItem.FullName).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $ResolvedParent = [IO.Path]::GetFullPath($ParentItem.FullName).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $ParentPrefix = $ResolvedParent + [IO.Path]::DirectorySeparatorChar
  if (-not $ResolvedTarget.StartsWith($ParentPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a directory outside the allowed parent '$ResolvedParent': $ResolvedTarget"
  }

  $Cursor = $TargetItem
  while (-not $Cursor.FullName.Equals($ResolvedParent, [StringComparison]::OrdinalIgnoreCase)) {
    if (($Cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Refusing to recursively remove a reparse point or junction: $($Cursor.FullName)"
    }
    $Cursor = $Cursor.Parent
    if ($null -eq $Cursor) {
      throw "Unable to verify removal boundary for: $ResolvedTarget"
    }
  }

  # Enumerate one directory level at a time so junctions are detected before
  # they can be traversed. Remove-Item -Recurse is only used after the complete
  # target tree has been proven free of reparse points.
  $PendingDirectories = New-Object System.Collections.Stack
  $PendingDirectories.Push($TargetItem)
  while ($PendingDirectories.Count -gt 0) {
    $Directory = $PendingDirectories.Pop()
    foreach ($Child in Get-ChildItem -LiteralPath $Directory.FullName -Force -ErrorAction Stop) {
      if (($Child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to recursively remove a tree containing a reparse point or junction: $($Child.FullName)"
      }
      if ($Child.PSIsContainer) {
        $PendingDirectories.Push($Child)
      }
    }
  }
  return $ResolvedTarget
}

function Remove-DirectoryWithRetry {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$AllowedParent,
    [int]$Attempts = 6
  )

  $SafePath = Resolve-SafeRemovalDirectory -Path $Path -AllowedParent $AllowedParent
  for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
    try {
      Remove-Item -LiteralPath $SafePath -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($Attempt -eq $Attempts) {
        throw "Unable to remove directory after $Attempts attempts: $SafePath. $($_.Exception.Message)"
      }
      Start-Sleep -Milliseconds (350 * $Attempt)
    }
  }
}

function Find-PythonForNativeChecks {
  $PathCommand = Get-Command python.exe -ErrorAction SilentlyContinue
  $Candidates = @(
    $(if ($PathCommand) { $PathCommand.Source }),
    $(if ($env:GAUSSIAN_SPLATTING_CONDA_PREFIX) { Join-Path $env:GAUSSIAN_SPLATTING_CONDA_PREFIX "python.exe" }),
    $(if ($env:GS_CONDA_PREFIX) { Join-Path $env:GS_CONDA_PREFIX "python.exe" }),
    $(if ($env:CONDA_PREFIX) { Join-Path $env:CONDA_PREFIX "python.exe" })
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
  foreach ($Candidate in $Candidates | Select-Object -Unique) {
    & $Candidate -B -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"
    if ($LASTEXITCODE -eq 0) {
      return (Resolve-Path -LiteralPath $Candidate).Path
    }
  }
  throw "Python 3.10 or newer was not found; native worker tests and syntax gates cannot run."
}

function Invoke-PythonSyntaxGate {
  param(
    [Parameter(Mandatory = $true)][string]$Python,
    [Parameter(Mandatory = $true)][string]$SourceRoot
  )

  $CompileScript = @'
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
paths = sorted(root.rglob("*.py"))
if not paths:
    raise SystemExit("No staged Python files were found under {}".format(root))
for path in paths:
    compile(path.read_bytes(), str(path), "exec")
print("Compiled {} staged Python files without bytecode output.".format(len(paths)))
'@
  $CompileScript | & $Python -B - $SourceRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Staged Python syntax gate failed with exit code $LASTEXITCODE."
  }
}

Import-VisualStudioEnvironment -ScriptPath $VsDevCmd

$CMake = Join-Path $QtRoot "Library\bin\cmake.exe"
$CTest = Join-Path $QtRoot "Library\bin\ctest.exe"
$Ninja = Join-Path $QtRoot "Library\bin\ninja.exe"
$WinDeployQtCandidates = @(
  (Join-Path $QtRoot "Library\bin\windeployqt.exe"),
  (Join-Path $QtRoot "Library\bin\windeployqt6.exe"),
  (Join-Path $QtRoot "Library\lib\qt6\bin\windeployqt.exe")
) | Where-Object { Test-Path -LiteralPath $_ }
$WinDeployQt = $WinDeployQtCandidates | Select-Object -First 1
foreach ($tool in @($CMake, $CTest, $Ninja)) {
  if (-not (Test-Path -LiteralPath $tool)) {
    throw "Required native build tool not found: $tool"
  }
}

$QtRuntimePaths = @(
  $QtRoot,
  (Join-Path $QtRoot "Library\bin"),
  (Join-Path $QtRoot "Library\lib\qt6\bin"),
  (Join-Path $QtRoot "Scripts")
) -join ";"
$env:Path = "$QtRuntimePaths;$env:Path"

if ($Clean -and (Test-Path -LiteralPath $BuildDirectory)) {
  Remove-DirectoryWithRetry -Path $BuildDirectory -AllowedParent $NativeRoot
}

& $CMake `
  -S $NativeRoot `
  -B $BuildDirectory `
  -G Ninja `
  "-DCMAKE_MAKE_PROGRAM=$Ninja" `
  "-DCMAKE_PREFIX_PATH=$(Join-Path $QtRoot 'Library')" `
  "-DCMAKE_BUILD_TYPE=$Configuration" `
  "-DGSW_RELEASE_DATE=$ReleaseDate" `
  "-DBUILD_TESTING=ON"
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE." }

& $CMake --build $BuildDirectory --parallel
if ($LASTEXITCODE -ne 0) { throw "Native build failed with exit code $LASTEXITCODE." }

& $CTest --test-dir $BuildDirectory --no-tests=error --output-on-failure
if ($LASTEXITCODE -ne 0) { throw "Native tests failed with exit code $LASTEXITCODE." }

$CheckPython = Find-PythonForNativeChecks
$PreviousBytecodeSetting = $env:PYTHONDONTWRITEBYTECODE
$env:PYTHONDONTWRITEBYTECODE = "1"
Push-Location $Root
try {
  & $CheckPython -B -m unittest native.worker.test_gsw_worker native.worker.test_import_preflight
  if ($LASTEXITCODE -ne 0) {
    throw "Native worker tests failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
  $env:PYTHONDONTWRITEBYTECODE = $PreviousBytecodeSetting
}

$Executable = Join-Path $BuildDirectory "Gaussian Scene Workbench.exe"
if (-not (Test-Path -LiteralPath $Executable)) {
  throw "Native executable was not produced: $Executable"
}

Write-Host "Native build completed:"
Write-Host $Executable

if ($Package) {
  if (-not (Test-Path -LiteralPath $WinDeployQt)) {
    throw "windeployqt was not found: $WinDeployQt"
  }
  $PackageRoot = Join-Path $NativeRoot "dist\Gaussian-Scene-Workbench-0.3.0-native-preview-win-x64"
  if (Test-Path -LiteralPath $PackageRoot) {
    Remove-DirectoryWithRetry -Path $PackageRoot -AllowedParent (Join-Path $NativeRoot "dist")
  }
  & $CMake --install $BuildDirectory --prefix $PackageRoot
  if ($LASTEXITCODE -ne 0) { throw "Native install failed with exit code $LASTEXITCODE." }
  $PackagedExecutable = Join-Path $PackageRoot "bin\Gaussian Scene Workbench.exe"
  $DeployConfigurationFlag = if ($Configuration -eq "Debug") { "--debug" } else { "--release" }
  & $WinDeployQt $DeployConfigurationFlag --no-translations --compiler-runtime $PackagedExecutable
  if ($LASTEXITCODE -ne 0) { throw "windeployqt failed with exit code $LASTEXITCODE." }
  $RuntimeSearchRoots = @(
    (Join-Path $QtRoot "Library\bin"),
    (Join-Path $env:VCToolsRedistDir "x64\Microsoft.VC143.CRT")
  )
  Copy-AppLocalDependencies -PackageBin (Split-Path -Parent $PackagedExecutable) -SearchRoots $RuntimeSearchRoots
  Copy-Item -LiteralPath (Join-Path $NativeRoot "README.md") -Destination $PackageRoot -Force
  Copy-Item -LiteralPath (Join-Path $NativeRoot "build_manifest.json") -Destination $PackageRoot -Force
  Copy-Item -LiteralPath (Join-Path $Root "docs\NATIVE_MIGRATION.md") -Destination $PackageRoot -Force
  Copy-Item -LiteralPath (Join-Path $Root "docs\NATIVE_PARITY.md") -Destination $PackageRoot -Force
  Copy-Item -LiteralPath (Join-Path $Root "LICENSE") -Destination $PackageRoot -Force
  Copy-Item -LiteralPath (Join-Path $Root "THIRD_PARTY_LICENSES.md") -Destination $PackageRoot -Force
  & (Join-Path $Root "scripts\stage_native_backend.ps1") `
    -SourceRoot $Root `
    -DestinationRoot $PackageRoot
  Invoke-PythonSyntaxGate -Python $CheckPython -SourceRoot $PackageRoot
  $RequiredBackendFiles = @(
    "native\worker\gsw_worker.py",
    "native\worker\import_preflight.py",
    "crop_editor\server.py",
    "crop_editor\video_extract.py",
    "scripts\check_3dgs_env.ps1",
    "gaussian-splatting\train.py",
    "training_kit\apply_local_fixes.bat",
    "backend_manifest.json"
  ) | ForEach-Object { Join-Path $PackageRoot $_ }
  $MissingBackendFiles = $RequiredBackendFiles | Where-Object {
    -not (Test-Path -LiteralPath $_)
  }
  if ($MissingBackendFiles) {
    throw "Native package is missing backend files: $($MissingBackendFiles -join ', ')"
  }
  Write-Host "Native package directory:"
  Write-Host $PackageRoot
}
