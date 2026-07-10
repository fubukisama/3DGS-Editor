# Gaussian Scene Workbench Native

`native/` is the Qt 6/C++ desktop replacement for the legacy Electron and HTML interface. The native target does not load a browser engine, start a local HTTP server, or require Node.js at runtime.

## Current preview

- Native Qt Widgets application with a GPU-backed OpenGL viewport.
- Dockable project tree, inspector, task queue, and process log.
- Portable `.gsw.json` project files with relative asset paths.
- Dataset folder and PLY scene metadata import.
- Existing PowerShell/Python backend execution through `QProcess`.
- Qt high-DPI support plus persistent 75%-125% manual UI scaling.

The current viewport is the native shell and interaction layer. SIBR scene rendering is deliberately reported as offline until the renderer adapter is integrated; the preview does not fabricate an FPS value from lightweight UI paint time.

## Local Windows build

The default toolchain is installed outside the system drive:

- Qt/CMake/Ninja: `E:\conda\envs\gsw_native`
- Visual Studio C++ tools: discovered automatically, including `E:\vsi`

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_native.ps1
```

Build and collect a runnable directory:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_native.ps1 -Configuration Release -Package
```

Set `GSW_NATIVE_QT_ROOT` or pass `-QtRoot` when Qt is installed elsewhere.

## License boundary

LichtFeld Studio is used as an architecture and workflow reference. Its source is GPL-3.0-or-later. No LichtFeld source code is copied into this MIT-licensed native preview. Any future direct reuse must be isolated and licensed compatibly before it is merged.
