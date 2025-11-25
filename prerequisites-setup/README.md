
# AVM/Bicep Hands-on Setup (Windows)

This folder contains scripts that prepare your Windows environment for the AVM/Bicep hands-on session. It installs the required tools for **both** Azure CLI and PowerShell users and runs a **Bicep-based** system test.
It also includes a **prerequisite checker** you can run to verify your setup before the session.

---

## Required software

To fully participate in the lab, you should have:

- **PowerShell 7 (pwsh)**  
  Required for running setup and checker scripts.
- **Azure CLI** (latest version)  
  For CLI-based deployments and Bicep support.
- **Bicep CLI**  
  Installed either standalone or via Azure CLI.
- **Az PowerShell module**  
  For PowerShell-based deployments.
- **Visual Studio Code**  
  Recommended editor for Bicep development.
- **VS Code Bicep extension**  
  Extension ID: `ms-azuretools.vscode-bicep`.
- **Active Azure subscription**  
  With permissions to create and delete resource groups.
- **winget (App Installer)**  
  Required for automated installation of tools if missing.
- **Git**  
  Recommended for version control and cloning repositories.

## Repository Contents

- `check.cmd` — Bootstrap for the prerequisite checker; **requires PowerShell 7** and offers to install it via `winget` if missing.
- `check-prereqs.ps1` — **Does not install anything**; checks tooling & login status and runs Bicep-based deployment tests.
- `setup.cmd` — Bootstrap from CMD; ensures PowerShell 7 and launches the main setup.
- `setup-windows.ps1` — Main setup (installs VS Code, Azure CLI, Bicep CLI, Az module; adds VS Code Bicep extension; runs system test).
- `rg-test.bicep` — Bicep template used by the system test and checker (creates and removes a Resource Group to validate deployment).

---

## Prerequisites

To run the setup and checker scripts, you need:

- An **active Azure subscription** with permission to create resource groups.
- **Windows 11** with **App Installer** (`winget`) available.
- For the **checker**: **PowerShell 7 (`pwsh`)** is required. If missing, `check.cmd` will offer to install it and then run the checker.

---

## Quick Start — Setup

1. Download all files into a folder.

2. To check prerequisites, open **CMD** and run:

   ```cmd
   check.cmd
   ```

3. To set up the environment, open **CMD** and run:

   ```cmd
   setup.cmd
   ```

## Additional Information

- [Install Bicep Tools - Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)