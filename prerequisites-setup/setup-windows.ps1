
<#
  Azure Bicep Environment Setup (Windows, PowerShell 7)
  - Install: VS Code, Azure CLI, Bicep CLI (winget), Az module (PSGallery)
  - Install VS Code Bicep extension
  - Refresh PATH and resolve Azure CLI immediately after install
  - System test: deploy RG via Bicep (CLI and PowerShell) and delete it
#>

# Resolve script directory even if invoked from another folder
$ScriptDir = Split-Path -Parent $PSCommandPath
$bicepPath = Join-Path $ScriptDir "rg-test.bicep"

Write-Host "============================================================"
Write-Host " Azure Bicep Environment Setup - PowerShell"
Write-Host "============================================================"
Write-Host "Script directory: $ScriptDir"
Write-Host ""

function Write-Info($msg) { Write-Host "INFO: $msg" }
function Write-Ok($msg)   { Write-Host "SUCCESS: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "WARNING: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "ERROR: $msg" -ForegroundColor Red }

function Confirm-Yes([string]$Message) {
    $resp = Read-Host "$Message [Y/n]"
    if ([string]::IsNullOrWhiteSpace($resp)) { return $true }
    return $resp.ToLower() -in @('y','yes')
}

function Refresh-EnvPath {
    # Refresh current process PATH from User and Machine after installs
    $user    = [Environment]::GetEnvironmentVariable("Path","User")
    $machine = [Environment]::GetEnvironmentVariable("Path","Machine")
    $newPath = ($user + ";" + $machine).TrimEnd(';')
    $env:PATH = $newPath
    Write-Info "PATH refreshed from system. Current length: $($env:PATH.Length)"
}

function Resolve-AzCli {
    # Try Get-Command first (PATH)
    $cmd = Get-Command az -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # Common install locations on Windows (MSI/winget)
    $candidates = @(
        "C:\Program Files\Microsoft SDKs\Azure\CLI\wbin\az.cmd",
        "C:\Program Files\Microsoft SDKs\Azure\CLI\bin\az.cmd",
        "C:\Program Files (x86)\Microsoft SDKs\Azure\CLI\wbin\az.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $dir = Split-Path -Parent $c
            if (-not ($env:PATH -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $dir })) {
                $env:PATH = "$env:PATH;$dir"
                Write-Info "Added Azure CLI directory to PATH: $dir"
            }
            return $c
        }
    }

    return $null
}

function Resolve-BicepCli {
    $cmd = Get-Command bicep -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # Fallback common winget path under user profile
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\bicep\bicep.exe",
        "$env:USERPROFILE\.azure\bin\bicep.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

# Ensure winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "'winget' not found. Install 'App Installer' from Microsoft Store, then re-run."
    Write-Info "More info: https://learn.microsoft.com/windows/package-manager/winget/#install-winget"
    exit 1
}

Write-Info "Installing prerequisites (interactive)..."
$apps = @(
    @{ Id = 'Git.Git'                   ; Name = 'Git'               },
    @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' },
    @{ Id = 'Microsoft.AzureCLI'        ; Name = 'Azure CLI'         },
    @{ Id = 'Microsoft.Bicep'           ; Name = 'Bicep CLI'         }
)

foreach ($app in $apps) {
    $installed = winget list --exact --id $app.Id --source winget 2>$null | Select-String $app.Id
    if ($installed) {
        Write-Ok "$($app.Name) already installed."
    } else {
        if (Confirm-Yes "Install $($app.Name)?") {
            Write-Info "Installing $($app.Name) via winget..."
            winget install --exact --id $app.Id --source winget --accept-package-agreements --accept-source-agreements --silent
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "$($app.Name) installation completed."
            } else {
                Write-Warn "$($app.Name) installation reported a non-zero exit code. You may need to re-run elevated or check corporate restrictions."
            }
        } else {
            Write-Warn "Skipped installation: $($app.Name)"
        }
    }
}

# Refresh PATH to pick up newly installed tools
Refresh-EnvPath

# Install Az module
if (-not (Get-Module -ListAvailable -Name Az)) {
    if (Confirm-Yes "Install Az PowerShell module (scope CurrentUser)?") {
        Write-Info "Installing Az module from PSGallery..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Install-Module -Name Az -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
            Write-Ok "Az module installed."
        } catch {
            Write-Err "Az module installation failed: $($_.Exception.Message)"
            Write-Info "Action: Try running PowerShell as Administrator or check proxy settings."
        }
    } else {
        Write-Warn "Skipped Az module installation."
    }
} else {
    Write-Ok "Az module already available."
}

# VS Code Bicep extension
function Install-BicepExtension {
    $codeCandidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    ) | Where-Object { Test-Path $_ }

    if ($codeCandidates.Count -gt 0) {
        $codeExe = $codeCandidates | Select-Object -First 1
        Write-Info "Installing VS Code Bicep extension using: $codeExe"
        try {
            & $codeExe --install-extension ms-azuretools.vscode-bicep
            Write-Ok "VS Code Bicep extension installed."
        } catch {
            Write-Warn "Automatic VS Code extension installation failed: $($_.Exception.Message)"
            Write-Info "Manual install: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep"
        }
    } else {
        Write-Warn "VS Code executable not found in typical locations."
        Write-Info "If Code is installed, ensure 'code' is in PATH, then run: code --install-extension ms-azuretools.vscode-bicep"
    }
}
Install-BicepExtension

# Resolve Azure CLI immediately (handles first-run detection)
$AzCliPath = Resolve-AzCli
if ($AzCliPath) {
    Write-Ok "Azure CLI resolved: $AzCliPath"
} else {
    Write-Warn "Azure CLI not found after installation."
    Write-Info "Action: Open a new terminal and re-run, or verify MSI install paths under 'C:\Program Files\Microsoft SDKs\Azure\CLI'."
}

# Resolve Bicep CLI for PowerShell compilation fallback
$BicepExe = Resolve-BicepCli
if ($BicepExe) {
    Write-Ok "Bicep CLI resolved: $BicepExe"
} else {
    Write-Warn "Standalone Bicep CLI not found. Will use 'az bicep' where possible."
}

# Azure login (PowerShell)
if (Get-Module -ListAvailable -Name Az) {
    try {
        $ctx = Get-AzContext
        if (-not $ctx) {
            if (Confirm-Yes "Login to Azure with PowerShell (Connect-AzAccount)?") {
                Connect-AzAccount
                Write-Ok "Azure login (PowerShell) completed."
            }
        } else {
            Write-Ok "Already logged in (PowerShell). Subscription: $($ctx.Subscription.Name)"
        }
    } catch {
        Write-Warn "Azure login (PowerShell) failed: $($_.Exception.Message)"
    }
}

# Azure login (CLI)
if ($AzCliPath) {
    $cliCtx = & $AzCliPath account show 2>$null
    if (-not $cliCtx) {
        if (Confirm-Yes "Login to Azure with Azure CLI (az login)?") {
            & $AzCliPath login
            Write-Ok "Azure login (CLI) completed."
        }
    } else {
        Write-Ok "Already logged in (Azure CLI). Subscription: $((($cliCtx | ConvertFrom-Json).name))"
    }
}

# ---------------------------
# Bicep System Test (using rg-test.bicep)
# ---------------------------
if (Confirm-Yes "Run the Bicep system test now (creates and deletes a temporary Resource Group)?") {
    if (-not (Test-Path $bicepPath)) {
        Write-Host "ERROR: Bicep file not found at: $bicepPath"
        Write-Host "Action: Ensure 'rg-test.bicep' is present next to the scripts."
        exit 1
    }

    $Location = "westeurope"
    $rgNameCli = "rg-bicep-test-cli-{0}" -f ([System.Guid]::NewGuid().ToString().Substring(0,8))
    $rgNamePwsh = "rg-bicep-test-pwsh-{0}" -f ([System.Guid]::NewGuid().ToString().Substring(0,8))

    Write-Host "INFO: Test RG name (CLI): $rgNameCli"
    Write-Host "INFO: Test RG name (PowerShell): $rgNamePwsh"
    Write-Host "INFO: Using template: $bicepPath"
    Write-Host "INFO: Target scope: subscription, Location: $Location"
    Write-Host ""

    # CLI-based Bicep deployment (verbose) if CLI available
    $azCmd = Get-Command az -ErrorAction SilentlyContinue
    $cliDeployed = $false
    if ($azCmd) {
        Write-Host "INFO: Deploying via Azure CLI (subscription scope) with verbose output..."
        try {
            & $azCmd.Source deployment sub create --location $Location `
                --template-file $bicepPath `
                --parameters rgName=$rgNameCli rgLocation=$Location `
                --verbose `
                --output none
            Write-Host "SUCCESS: CLI Bicep deployment completed. Resource group created: $rgNameCli"
            $cliDeployed = $true
        } catch {
            Write-Host "ERROR: CLI Bicep deployment failed: $($_.Exception.Message)"
        }
    } else {
        Write-Host "WARNING: Azure CLI not available; skipping CLI deployment path."
    }

    # PowerShell-based path: compile Bicep then deploy with -Verbose
    $pwshDeployed = $false
    $compiled = Join-Path $ScriptDir "rg-test.json"
    if (Get-Module -ListAvailable -Name Az) {
        try {
            Write-Host "INFO: Compiling Bicep to JSON: $compiled"
            $bicepExe = Get-Command bicep -ErrorAction SilentlyContinue
            if ($bicepExe) {
                & $bicepExe.Source build $bicepPath --outfile $compiled
            } elseif ($azCmd) {
                & $azCmd.Source bicep build --file $bicepPath --outfile $compiled
            } else {
                Write-Host "ERROR: No Bicep compiler found (bicep or az). Install Bicep CLI or Azure CLI."
                throw "Compiler missing"
            }

            Write-Host "INFO: Deploying via PowerShell (subscription scope) with -Verbose..."
            New-AzSubscriptionDeployment -Location $Location `
                -TemplateFile $compiled `
                -TemplateParameterObject @{ rgName = $rgNamePwsh; rgLocation = $Location } `
                -Verbose | Out-Null

            Write-Host "SUCCESS: PowerShell deployment ensured resource group: $rgNamePwsh"
            $pwshDeployed = $true
        } catch {
            Write-Host "ERROR: PowerShell Bicep deployment failed: $($_.Exception.Message)"
        } finally {
            # Delete compiled ARM template
            if (Test-Path $compiled) {
                Remove-Item $compiled -Force
                Write-Host "INFO: Deleted compiled ARM template: $compiled"
            }
        }
    } else {
        Write-Host "WARNING: Az PowerShell module not available; skipping PowerShell deployment path."
    }

    # Cleanup - Delete both resource groups
    Write-Host ""
    Write-Host "INFO: Cleaning up test resource groups..."
    
    # Delete CLI resource group
    if ($cliDeployed) {
        try {
            if ($azCmd) {
                & $azCmd.Source group delete --name $rgNameCli --yes --no-wait
                Write-Host "SUCCESS: CLI resource group deletion requested (asynchronous): $rgNameCli"
            } elseif (Get-Module -ListAvailable -Name Az) {
                Remove-AzResourceGroup -Name $rgNameCli -Force -AsJob | Out-Null
                Write-Host "SUCCESS: CLI resource group deletion requested via PowerShell (asynchronous): $rgNameCli"
            }
        } catch {
            Write-Host "WARNING: CLI resource group deletion failed: $($_.Exception.Message)"
            Write-Host "ACTION: Please delete manually: $rgNameCli"
        }
    }
    
    # Delete PowerShell resource group
    if ($pwshDeployed) {
        try {
            if (Get-Module -ListAvailable -Name Az) {
                Remove-AzResourceGroup -Name $rgNamePwsh -Force -AsJob | Out-Null
                Write-Host "SUCCESS: PowerShell resource group deletion requested (asynchronous): $rgNamePwsh"
            } elseif ($azCmd) {
                & $azCmd.Source group delete --name $rgNamePwsh --yes --no-wait
                Write-Host "SUCCESS: PowerShell resource group deletion requested via CLI (asynchronous): $rgNamePwsh"
            }
        } catch {
            Write-Host "WARNING: PowerShell resource group deletion failed: $($_.Exception.Message)"
            Write-Host "ACTION: Please delete manually: $rgNamePwsh"
        }
    }
}

Write-Host ""
Write-Host "SUCCESS: Setup completed."
Write-Host "NOTE: If any tool was installed, open a NEW terminal to ensure PATH is fully updated."
