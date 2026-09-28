@echo off
rem Pixel ARPG Windows Batch Launcher
setlocal

cd /d "%~dp0"

where godot.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [Launcher] Starting Pixel ARPG with godot.exe...
    godot.exe --path "%~dp0" %*
    goto end
)

where godot_v4*.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [Launcher] Starting Pixel ARPG...
    for /f "delims=" %%i in ('where godot_v4*.exe') do (
        "%%i" --path "%~dp0" %*
        goto end
    )
)

echo ============================================================
echo  [!] Godot 4 was not found in PATH.
echo ============================================================
echo Please open Godot 4 Editor, click "Import", and select:
echo   %~dp0project.godot
echo ============================================================
pause

:end
