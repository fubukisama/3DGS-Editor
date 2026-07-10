@echo off
setlocal

set "ROOT=%~dp0"
set "DEFAULT_RUNTIME=%~d0\Gaussian-Scene-Workbench-Runtime"
if exist "%~d0\3DGS-Editor-Runtime\" if not exist "%DEFAULT_RUNTIME%\" set "DEFAULT_RUNTIME=%~d0\3DGS-Editor-Runtime"
set "INSTALL_ROOT=%~1"

if "%INSTALL_ROOT%"=="" (
  echo.
  echo Gaussian Scene Workbench runtime install folder
  echo Default: %DEFAULT_RUNTIME%
  echo.
  echo Press Enter to use the default, or type another folder such as E:\Gaussian-Scene-Workbench-Runtime.
  set /p "INSTALL_ROOT=Runtime folder: "
)

if "%INSTALL_ROOT%"=="" set "INSTALL_ROOT=%DEFAULT_RUNTIME%"

echo.
echo Runtime folder: %INSTALL_ROOT%
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\bootstrap_3dgs_editor.ps1" -NonInteractive -InstallRoot "%INSTALL_ROOT%"
if errorlevel 1 (
  echo.
  echo Setup failed. See setup_gaussian_scene_workbench.log in this folder.
  pause
  exit /b %errorlevel%
)
echo.
echo Setup finished. Starting Gaussian Scene Workbench...
if not exist "%ROOT%Gaussian Scene Workbench.exe" (
  echo.
  echo Gaussian Scene Workbench.exe was not found in this folder:
  echo %ROOT%
  pause
  exit /b 1
)
start "" "%ROOT%Gaussian Scene Workbench.exe"
timeout /t 2 /nobreak >nul
exit /b 0
