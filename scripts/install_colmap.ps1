[CmdletBinding()]
param(
    [string]$InstallRoot = "",
    [ValidateSet("cuda", "nocuda")]
    [string]$Variant = "cuda",
    [string]$Version = "latest",
    [string]$ExpectedSha256 = "",
    [switch]$Force,
    [switch]$KeepArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $driveRoot = [IO.Path]::GetPathRoot($RepositoryRoot)
    $InstallRoot = Join-Path $driveRoot "Tools\COLMAP"
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)

function Assert-ChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $fullParent = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    $prefix = $fullParent + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the COLMAP install root: $fullPath"
    }
}

function Test-ColmapExecutable {
    param([Parameter(Mandatory = $true)][string]$Executable)

    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        return $false
    }
    $output = & $Executable -h 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $output -notmatch "COLMAP\s+[0-9]") {
        throw "COLMAP executable validation failed: $Executable"
    }
    $firstLine = ($output -split "`r?`n" | Where-Object { $_ -match "COLMAP\s+[0-9]" } | Select-Object -First 1).Trim()
    Write-Host "Validated: $firstLine"
    return $true
}

function Get-ColmapRelease {
    param([Parameter(Mandatory = $true)][string]$RequestedVersion)

    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "Gaussian-Scene-Workbench-COLMAP-Installer"
    }
    if ($RequestedVersion -eq "latest") {
        return Invoke-RestMethod -Uri "https://api.github.com/repos/colmap/colmap/releases/latest" -Headers $headers
    }

    $tags = @($RequestedVersion)
    if (-not $RequestedVersion.StartsWith("v", [StringComparison]::OrdinalIgnoreCase)) {
        $tags += "v$RequestedVersion"
    }
    foreach ($tag in $tags) {
        try {
            $escaped = [Uri]::EscapeDataString($tag)
            return Invoke-RestMethod -Uri "https://api.github.com/repos/colmap/colmap/releases/tags/$escaped" -Headers $headers
        } catch {
            if ($tag -eq $tags[-1]) {
                throw
            }
        }
    }
}

function Get-ColmapAsset {
    param(
        [Parameter(Mandatory = $true)]$Release,
        [Parameter(Mandatory = $true)][string]$RequestedVariant
    )

    $exactName = if ($RequestedVariant -eq "cuda") {
        "colmap-x64-windows-cuda.zip"
    } else {
        "colmap-x64-windows-nocuda.zip"
    }
    $asset = @($Release.assets) |
        Where-Object { $_.name -ieq $exactName } |
        Select-Object -First 1
    if (-not $asset) {
        $asset = @($Release.assets) | Where-Object {
            $_.name -match "(?i)windows.*\.zip$" -and
            (($RequestedVariant -eq "cuda" -and $_.name -match "(?i)(^|[-_])cuda" -and $_.name -notmatch "(?i)nocuda") -or
             ($RequestedVariant -eq "nocuda" -and $_.name -match "(?i)no[-_]?cuda"))
        } | Select-Object -First 1
    }
    if (-not $asset) {
        throw "No official Windows $RequestedVariant archive was found in COLMAP release $($Release.tag_name)."
    }
    return $asset
}

if ($Version -ne "latest") {
    $requestedName = $Version.TrimStart('v')
    $requestedExecutable = Join-Path $InstallRoot "$requestedName\bin\colmap.exe"
    if (-not $Force -and (Test-ColmapExecutable -Executable $requestedExecutable)) {
        Write-Host "COLMAP $requestedName is already installed."
        Write-Output $requestedExecutable
        return
    }
}

Write-Host "Querying the official COLMAP GitHub release..."
$release = Get-ColmapRelease -RequestedVersion $Version
$versionName = ([string]$release.tag_name).TrimStart('v')
if ($versionName -notmatch '^[0-9A-Za-z._-]+$') {
    throw "Unexpected COLMAP release tag: $($release.tag_name)"
}
$asset = Get-ColmapAsset -Release $release -RequestedVariant $Variant
$targetRoot = Join-Path $InstallRoot $versionName
$targetExecutable = Join-Path $targetRoot "bin\colmap.exe"

if (-not $Force -and (Test-ColmapExecutable -Executable $targetExecutable)) {
    Write-Host "COLMAP $versionName is already installed."
    Write-Output $targetExecutable
    return
}

$assetDigest = if ($asset.PSObject.Properties.Name -contains "digest") {
    [string]$asset.digest
} else {
    ""
}
$expectedHash = $ExpectedSha256.Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($expectedHash) -and $assetDigest -match '^sha256:([0-9a-fA-F]{64})$') {
    $expectedHash = $Matches[1].ToLowerInvariant()
}
if ($expectedHash -notmatch '^[0-9a-f]{64}$') {
    throw "The release asset has no usable SHA-256 digest. Pass -ExpectedSha256 explicitly."
}

$downloadRoot = Join-Path $InstallRoot "downloads"
$archivePath = Join-Path $downloadRoot $asset.name
$partialPath = "$archivePath.partial-$PID"
$extractRoot = Join-Path $InstallRoot ".extract-$versionName-$PID"
New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null
Assert-ChildPath -Path $archivePath -Parent $InstallRoot
Assert-ChildPath -Path $partialPath -Parent $InstallRoot
Assert-ChildPath -Path $extractRoot -Parent $InstallRoot
Assert-ChildPath -Path $targetRoot -Parent $InstallRoot

try {
    $archiveIsValid = $false
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        $existingHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $archiveIsValid = $existingHash -eq $expectedHash
        if (-not $archiveIsValid) {
            Remove-Item -LiteralPath $archivePath -Force
        }
    }

    if (-not $archiveIsValid) {
        Write-Host "Downloading $($asset.name) ($([math]::Round([double]$asset.size / 1MB, 1)) MiB)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $partialPath -Headers @{
            "User-Agent" = "Gaussian-Scene-Workbench-COLMAP-Installer"
        }
        Move-Item -LiteralPath $partialPath -Destination $archivePath -Force
    }

    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "COLMAP archive SHA-256 mismatch. Expected $expectedHash, received $actualHash."
    }
    Write-Host "SHA-256 verified: $actualHash"

    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force

    $foundExecutable = Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Filter "colmap.exe" |
        Where-Object { $_.Directory.Name -ieq "bin" } |
        Select-Object -First 1
    if (-not $foundExecutable) {
        throw "The official archive was extracted, but bin\colmap.exe was not found."
    }
    $copyRoot = $foundExecutable.Directory.Parent.FullName

    if (Test-Path -LiteralPath $targetRoot) {
        Remove-Item -LiteralPath $targetRoot -Recurse -Force
    }
    Move-Item -LiteralPath $copyRoot -Destination $targetRoot

    if (-not (Test-ColmapExecutable -Executable $targetExecutable)) {
        throw "COLMAP installation did not produce a valid executable: $targetExecutable"
    }
    if (-not $KeepArchive) {
        Remove-Item -LiteralPath $archivePath -Force
    }
} finally {
    Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Installed COLMAP $versionName ($Variant): $targetExecutable"
Write-Host "No machine-level PATH or registry settings were changed."
Write-Output $targetExecutable
