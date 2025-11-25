
<#
  Azure Bicep Prerequisite Checker (Windows)
  - No installations; checks tooling and login status
  - If possible, runs Bicep-based subscription-scope deployment tests using rg-test.bicep
    * Uses different RG names for CLI and PowerShell tests
    * Ensures both are deleted if created
  Place this script and rg-test.bicep in the same folder.
#>

[CmdletBinding()]
param(
    [string]$Location = "westeurope",
    [switch]$RunTestIfPossible = $true
)

# Resolve script directory
$ScriptDir = Split-Path -Parent $PSCommandPath
$bicepPath = Join-Path $ScriptDir "rg-test.bicep"

function Write-Section($title) {
    Write-Host ""
    Write-Host ("=" * 60)
    Write-Host " $title"
    Write-Host ("=" * 60)
}

function Write-Ok($msg)   { Write-Host "SUCCESS: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "WARNING: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "ERROR:   $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "INFO:    $msg" }

function Test-Command([string]$name) {
    try {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        return $cmd -ne $null
    } catch { return $false }
}

function Find-CodeCmd {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    # fallback to PATH
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

Write-Section "Azure Bicep Prerequisite Checker"
Write-Info "Script directory: $ScriptDir"
Write-Info "Bicep template path: $bicepPath"

# 1) Check tools
Write-Section "Tooling Checks"

# Git
$hasGit = Test-Command "git"
if ($hasGit) {
    $gitVer = (& git --version 2>$null)
    Write-Ok "Git available. Version: $gitVer"
} else {
    Write-Warn "Git NOT found. Install via: winget install Git.Git"
}

# PowerShell 7 (pwsh)
$hasPwsh = Test-Command "pwsh"
if ($hasPwsh) {
    $pwshVer = (& pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null)
    Write-Ok "PowerShell 7 (pwsh) available. Version: $pwshVer"
} else {
    Write-Warn "PowerShell 7 (pwsh) NOT found. Recommended for session."
}

# Azure CLI
$hasAzCli = Test-Command "az"
if ($hasAzCli) {
    $azVer = (& az version 2>$null) -join ""
    Write-Ok "Azure CLI available."
    # Bicep via Azure CLI
    $azBicepVer = (& az bicep version 2>$null)
    if ($azBicepVer) {
        Write-Ok "Bicep support in Azure CLI available. Version: $azBicepVer"
    } else {
        Write-Warn "Azure CLI does not report Bicep support (az bicep version failed)."
    }
} else {
    Write-Warn "Azure CLI (az) NOT found."
}

# Standalone Bicep CLI
$hasBicepExe = Test-Command "bicep"
if ($hasBicepExe) {
    $bicepVer = (& bicep --version 2>$null)
    Write-Ok "Standalone Bicep CLI available. Version: $bicepVer"
} else {
    Write-Warn "Standalone Bicep CLI NOT found (CLI path can still build via 'az bicep build' if Azure CLI is present)."
}

# VS Code + Bicep extension
$codeExe = Find-CodeCmd
if ($codeExe) {
    $codeVer = (& $codeExe --version 2>$null) -split "`n" | Select-Object -First 1
    Write-Ok "VS Code CLI found: $codeExe (Version: $codeVer)"
    $exts = (& $codeExe --list-extensions 2>$null)
    if ($exts -and ($exts -match "^ms-azuretools\.vscode-bicep$")) {
        Write-Ok "VS Code Bicep extension installed: ms-azuretools.vscode-bicep"
    } else {
        Write-Warn "VS Code Bicep extension NOT found. Install via: code --install-extension ms-azuretools.vscode-bicep"
    }
} else {
    Write-Warn "VS Code CLI ('code') NOT found. If VS Code is installed, ensure its CLI is in PATH."
}

# Az PowerShell module
$hasAzModule = (Get-Module -ListAvailable -Name Az) -ne $null
if ($hasAzModule) {
    $azModule = Get-Module -ListAvailable -Name Az | Sort-Object Version -Descending | Select-Object -First 1
    Write-Ok "Az PowerShell module available. Version: $($azModule.Version)"
} else {
    Write-Warn "Az PowerShell module NOT found."
}

# 2) Check Azure login status
Write-Section "Azure Login Checks"

# CLI login
$cliLoggedIn = $false
if ($hasAzCli) {
    try {
        $cliCtx = az account show 2>$null
        if ($cliCtx) { $cliLoggedIn = $true; Write-Ok "Azure CLI: logged in. Subscription: $((($cliCtx | ConvertFrom-Json).name))" }
        else { Write-Warn "Azure CLI: NOT logged in. Run 'az login'." }
    } catch {
        Write-Warn "Azure CLI: login check failed. Run 'az login'."
    }
} else {
    Write-Warn "Azure CLI not available; skipping CLI login check."
}

# PowerShell login
$psLoggedIn = $false
if ($hasAzModule) {
    try {
        $ctx = Get-AzContext
        if ($ctx) { $psLoggedIn = $true; Write-Ok "PowerShell Az: logged in. Subscription: $($ctx.Subscription.Name)" }
        else { Write-Warn "PowerShell Az: NOT logged in. Run 'Connect-AzAccount'." }
    } catch {
        Write-Warn "PowerShell Az: login check failed. Run 'Connect-AzAccount'."
    }
} else {
    Write-Warn "Az PowerShell module not available; skipping PowerShell login check."
}

# 3) Validate Bicep template presence
Write-Section "Bicep Template Check"
if (Test-Path $bicepPath) {
    Write-Ok "Found rg-test.bicep in script directory."
} else {
    Write-Err "rg-test.bicep NOT found in: $ScriptDir"
    Write-Host "Action: Place rg-test.bicep next to this script."
}

# 4) Decide whether we can run the deployment test
Write-Section "Deployment Test Eligibility"
$canRunCliTest = $hasAzCli -and $cliLoggedIn -and (Test-Path $bicepPath)
$canRunPsTest  = $hasAzModule -and $psLoggedIn -and (Test-Path $bicepPath) -and ($hasBicepExe -or $hasAzCli)

if ($canRunCliTest) {
    Write-Ok "CLI-based Bicep deployment test is possible."
} else {
    Write-Warn "CLI-based test NOT possible. Requirements: az, az login, rg-test.bicep."
}

if ($canRunPsTest) {
    Write-Ok "PowerShell-based Bicep deployment test is possible."
} else {
    Write-Warn "PowerShell-based test NOT possible. Requirements: Az module + login, rg-test.bicep, and either bicep CLI or az (for build)."
}

# 5) Run test if requested and possible
#    Uses different RG names for CLI vs PowerShell paths and ensures both are deleted.
if ($RunTestIfPossible) {
    Write-Section "Bicep Deployment Tests (Subscription Scope)"
    $rgNameCli = "rg-bicep-test-cli-{0}" -f ([System.Guid]::NewGuid().ToString().Substring(0,8))
    $rgNamePs  = "rg-bicep-test-pwsh-{0}"  -f ([System.Guid]::NewGuid().ToString().Substring(0,8))
    $createdCli = $false
    $createdPs  = $false

    Write-Info "Location: $Location"
    Write-Info "CLI test RG: $rgNameCli"
    Write-Info "PS  test RG: $rgNamePs"

    if ($canRunCliTest) {
        Write-Info "Running CLI-based deployment (verbose)..."
        try {
            az deployment sub create --location $Location `
                --template-file $bicepPath `
                --parameters rgName=$rgNameCli rgLocation=$Location `
                --verbose `
                --output none
            Write-Ok "CLI deployment completed. Resource group created: $rgNameCli"
            $createdCli = $true
        } catch {
            Write-Err "CLI deployment failed: $($_.Exception.Message)"
        }
    }

    if ($canRunPsTest) {
        # Compile Bicep to JSON using bicep or az bicep
        $compiled = Join-Path $ScriptDir "rg-test.json"
        try {
            if ($hasBicepExe) {
                Write-Info "Compiling with standalone Bicep CLI: $compiled"
                bicep build $bicepPath --outfile $compiled
            } elseif ($hasAzCli) {
                Write-Info "Compiling with Azure CLI Bicep: $compiled"
                az bicep build --file $bicepPath --outfile $compiled
            }

            Write-Info "Deploying via PowerShell Az (Verbose)..."
            New-AzSubscriptionDeployment -Location $Location `
                -TemplateFile $compiled `
                -TemplateParameterObject @{ rgName=$rgNamePs; rgLocation=$Location } `
                -Verbose | Out-Null
            Write-Ok "PowerShell deployment completed. Resource group created: $rgNamePs"
            $createdPs = $true
        } catch {
            Write-Err "PowerShell deployment failed: $($_.Exception.Message)"
        } finally {
            # Delete compiled ARM template
            if (Test-Path $compiled) {
                Remove-Item $compiled -Force
                Write-Info "Deleted compiled ARM template: $compiled"
            }
        }
    }

    # Cleanup: delete any RG created by the tests
    Write-Section "Cleanup"
    if ($createdCli) {
        Write-Info "Requesting deletion of CLI test RG: $rgNameCli"
        try {
            az group delete --name $rgNameCli --yes --no-wait
            Write-Ok "Deletion requested via CLI (asynchronous)."
        } catch {
            Write-Warn "CLI RG deletion request encountered an issue: $($_.Exception.Message)"
        }
    } else {
        Write-Info "No CLI test RG to delete."
    }

    if ($createdPs) {
        Write-Info "Requesting deletion of PowerShell test RG: $rgNamePs"
        try {
            Remove-AzResourceGroup -Name $rgNamePs -Force -AsJob | Out-Null
            Write-Ok "Deletion requested via PowerShell (asynchronous)."
        } catch {
            Write-Warn "PowerShell RG deletion request encountered an issue: $($_.Exception.Message)"
        }
    } else {
        Write-Info "No PowerShell test RG to delete."
    }
}

Write-Section "Summary"
Write-Info ("Git:           " + ($(if($hasGit){"FOUND"}else{"MISSING"})))
Write-Info ("pwsh:          " + ($(if($hasPwsh){"FOUND"}else{"MISSING"})))
Write-Info ("Azure CLI:     " + ($(if($hasAzCli){"FOUND"}else{"MISSING"})))
Write-Info ("Bicep CLI:     " + ($(if($hasBicepExe){"FOUND"}else{"MISSING"})))
$codeExeSummary = if ($codeExe) {"FOUND"} else {"MISSING"}
Write-Info ("VS Code:       " + $codeExeSummary)
$extInstalled = ($codeExe -and $exts -and ($exts -match "^ms-azuretools\.vscode-bicep$"))
Write-Info ("VSCode Bicep:  " + ($(if($extInstalled){"FOUND"}else{"MISSING"})))
Write-Info ("Az module:     " + ($(if($hasAzModule){"FOUND"}else{"MISSING"})))
Write-Info ("CLI login:     " + ($(if($cliLoggedIn){"OK"}else{"NO"})))
Write-Info ("PS login:      " + ($(if($psLoggedIn){"OK"}else{"NO"})))
Write-Host ""
Write-Ok "Prerequisite check finished."
