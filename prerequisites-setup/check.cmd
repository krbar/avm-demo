
@echo off
setlocal ENABLEDELAYEDEXPANSION

rem ============================================================
rem Azure Bicep Prerequisite Checker - Bootstrap (CMD)
rem Requires PowerShell 7 (pwsh). Offers to install via winget.
rem ============================================================

set "SCRIPT_DIR=%~dp0"
set "CHECK_PS1=%SCRIPT_DIR%check-prereqs.ps1"

echo ============================================================
echo   Azure Bicep Prerequisite Checker - Bootstrap
echo ============================================================
echo Script directory: %SCRIPT_DIR%
echo Checker script:   %CHECK_PS1%
echo.

rem -- Ensure the checker PS1 exists
if not exist "%CHECK_PS1%" goto NO_PS1

rem -- Ensure winget exists (needed to install pwsh)
where winget >nul 2>&1
if %ERRORLEVEL% NEQ 0 goto NO_WINGET

rem -- If pwsh exists, run checker
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 goto RUN_CHECKER

rem -- Inform user and prompt install
echo PowerShell 7 (pwsh) is required to run the prerequisite checker.
set /p INSTALL_PWSH=Install PowerShell 7 now via winget? [Y/N]: 
if /I "%INSTALL_PWSH%"=="Y" goto INSTALL_PWSH
if /I "%INSTALL_PWSH%"=="N" goto DECLINED
rem -- Default to decline if input is anything else
goto DECLINED

:INSTALL_PWSH
echo Installing PowerShell 7 via winget...
winget install --exact --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements --silent
if %ERRORLEVEL% NEQ 0 goto INSTALL_FAIL

echo Waiting for PowerShell 7 to finish installing...
set /a tries=0
:WAIT_PWSH
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 goto RUN_CHECKER

set /a tries+=1
if !tries! LSS 20 (
  timeout /t 3 >nul
  goto WAIT_PWSH
)

goto WAIT_TIMEOUT

:RUN_CHECKER
echo Launching prerequisite checker with pwsh...
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CHECK_PS1%"
goto END

:NO_PS1
echo ERROR: check-prereqs.ps1 was not found next to this file.
echo ACTION: Place check-prereqs.ps1 in the same folder and re-run.
goto END_PAUSE

:NO_WINGET
echo ERROR: 'winget' command not found.
echo ACTION: Install "App Installer" from Microsoft Store and retry.
echo MORE INFO: https://learn.microsoft.com/windows/package-manager/winget/#install-winget
goto END_PAUSE

:INSTALL_FAIL
echo ERROR: Failed to start PowerShell 7 installation via winget.
echo ACTION: Install manually from https://aka.ms/powershell and re-run.
goto END_PAUSE

:WAIT_TIMEOUT
echo ERROR: pwsh.exe not found after waiting for installation.
echo ACTION: Open a new terminal and re-run this script.
goto END_PAUSE

:DECLINED
echo INFO: Installation declined. PowerShell 7 is required to run the checker.
echo ACTION: Install pwsh from https://aka.ms/powershell or run setup.cmd first.
goto END_PAUSE

:END_PAUSE
pause

:END
endlocal
