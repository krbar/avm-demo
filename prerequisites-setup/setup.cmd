
@echo off
setlocal ENABLEDELAYEDEXPANSION

rem ============================================================
rem Azure Bicep Environment Setup - Bootstrap (CMD)
rem Starts from CMD, installs PowerShell 7 if missing,
rem then launches setup-windows.ps1 from the same directory.
rem ============================================================

set "SCRIPT_DIR=%~dp0"
set "SETUP_PS1=%SCRIPT_DIR%setup-windows.ps1"

echo ============================================================
echo   Azure Bicep Environment Setup - Bootstrap
echo ============================================================
echo Script path: %~f0
echo Script directory: %SCRIPT_DIR%
echo Setup script: %SETUP_PS1%
echo.

rem Check winget availability
where winget >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: 'winget' command not found.
    echo Action: Install "App Installer" from Microsoft Store and retry.
    echo More info: https://learn.microsoft.com/windows/package-manager/winget/#install-winget
    pause
    exit /b 1
)

rem Locate PowerShell 7 (pwsh.exe)
set "PWSH="
for %%I in ("%ProgramFiles%\PowerShell\7\pwsh.exe" "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe") do (
    if exist "%%~I" set "PWSH=%%~I"
)

if not defined PWSH (
    echo PowerShell 7 not found. Attempting installation via winget...
    winget install --exact --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements --silent
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: PowerShell 7 installation via winget did not start successfully.
        echo Action: Install manually from https://aka.ms/powershell and re-run.
        pause
        exit /b 1
    )

    echo Waiting for PowerShell 7 to finish installing...
    set /a tries=0
    :WAIT_PWSH
    for %%I in ("%ProgramFiles%\PowerShell\7\pwsh.exe") do (
        if exist "%%~I" set "PWSH=%%~I"
    )
    if not defined PWSH (
        set /a tries+=1
        if !tries! LSS 20 (
            timeout /t 3 >nul
            goto WAIT_PWSH
        ) else (
            echo ERROR: PowerShell 7 not found after installation.
            echo Action: Open a new terminal and re-run this script.
            pause
            exit /b 1
        )
    )
)

echo SUCCESS: PowerShell 7 found at: %PWSH%
echo Launching setup script in PowerShell 7...
"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SETUP_PS1%"
