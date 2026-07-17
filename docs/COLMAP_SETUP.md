# COLMAP Setup

Gaussian Scene Workbench uses COLMAP as an external native dependency. It does not require COLMAP on the system drive and does not require a machine-level `PATH` change.

## Recommended Windows install

Install the latest official CUDA build on the same non-system drive as the workbench:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_colmap.ps1 `
  -InstallRoot E:\Tools\COLMAP `
  -Variant cuda
```

The installer:

- queries the official `colmap/colmap` GitHub Release API;
- selects the requested Windows CUDA or no-CUDA archive;
- requires and verifies the official SHA-256 asset digest;
- installs into a versioned directory such as `E:\Tools\COLMAP\4.1.0`;
- validates `bin\colmap.exe` before reporting success;
- removes the downloaded archive by default; and
- does not modify the registry or global `PATH`.

Use `-Variant nocuda` on a Windows computer without a compatible NVIDIA GPU. Use `-KeepArchive` only when an offline reinstall copy is required.

Install or verify a specific version without changing an existing installation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_colmap.ps1 `
  -InstallRoot E:\Tools\COLMAP `
  -Version 4.1.0 `
  -Variant cuda
```

## Application discovery

The native application and Python worker resolve COLMAP in this order:

1. the saved executable path;
2. `COLMAP_EXE` or `COLMAP_PATH`;
3. repository-local tool directories;
4. the newest semantic version under `<application-drive>:\Tools\COLMAP`;
5. legacy download locations; and
6. the current process `PATH`.

A stale saved path on `C:` therefore does not prevent discovery of a valid versioned installation on the application drive.

## Validated baseline

The current native preview is validated against official COLMAP `4.1.0` with CUDA, published on 2026-06-26. The Windows CUDA archive used for validation was `colmap-x64-windows-cuda.zip` with SHA-256:

```text
ccd2f8c5b44f3e0ce645170d6abad30ff763ede97eeb0e6e23af1993e624e64b
```

The deterministic end-to-end worker test can start from either photos or a
video. The video path exercises frame extraction before COLMAP and 3DGS:

```powershell
powershell -ExecutionPolicy Bypass -File native\tests\run_training_e2e_smoke.ps1 -MediaMode Video
```

On an RTX 4070 Laptop GPU, the validated video run registered 16 of 16
multi-depth views, reconstructed 12,779 sparse points with 0.760 px mean
reprojection error, completed 1,000 3DGS steps at 30.17 dB training PSNR,
produced 33,278 Gaussians, and reopened the binary PLY in the native desktop
application. These numbers are integration evidence, not photogrammetric
quality targets.

COLMAP undistortion is written to a validated staging directory before
`images/`, `sparse/`, and `stereo/` are replaced. This prevents an imported
`dataset/images` directory from also being used as the undistorter's output and
keeps the original trainable folders intact when COLMAP fails.

## Verification

```powershell
E:\Tools\COLMAP\4.1.0\bin\colmap.exe -h
powershell -ExecutionPolicy Bypass -File scripts\check_3dgs_env.ps1
```

The prebuilt CUDA package does not require `nvcc` for normal COLMAP use. `nvcc` is only required when compiling CUDA software from source.
