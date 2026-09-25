#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Enables PowerShell auditing on Windows.
.DESCRIPTION
    Configures Script Block Logging, Module Logging and
    PowerShell Transcription through Windows registry policies.
.EXAMPLE
    .\Enable-PowerShellAuditing.ps1
.EXAMPLE
    .\Enable-PowerShellAuditing.ps1 -OutputDirectory "D:\SecurityLogs"
#>

param(
    [string]$OutputDirectory = "C:\PS_Transcript"
)

$ErrorActionPreference = "Stop"

function Set-SafeRegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty `
        -Path $Path `
        -Name $Name `
        -Value $Value `
        -PropertyType $Type `
        -Force | Out-Null
}

try {
    $OutputDirectory = [System.IO.Path]::GetFullPath(
        $OutputDirectory
    )

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force | Out-Null

    # Enable Script Block Logging
    $ScriptBlockPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"

    Set-SafeRegistryValue `
        -Path $ScriptBlockPath `
        -Name "EnableScriptBlockLogging" `
        -Value 1

    # Enable Module Logging
    $ModulePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"

    Set-SafeRegistryValue `
        -Path $ModulePath `
        -Name "EnableModuleLogging" `
        -Value 1

    $ModuleNamesPath = Join-Path $ModulePath "ModuleNames"

    Set-SafeRegistryValue `
        -Path $ModuleNamesPath `
        -Name "*" `
        -Value "*" `
        -Type "String"

    # Enable Transcription
    $TranscriptionPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"

    Set-SafeRegistryValue `
        -Path $TranscriptionPath `
        -Name "EnableTranscripting" `
        -Value 1

    Set-SafeRegistryValue `
        -Path $TranscriptionPath `
        -Name "EnableInvocationHeader" `
        -Value 1

    Set-SafeRegistryValue `
        -Path $TranscriptionPath `
        -Name "OutputDirectory" `
        -Value $OutputDirectory `
        -Type "String"

    # Generate a test Script Block event.
    "PowerShell auditing test: $(Get-Date)" | Out-Null

    # Save a configuration confirmation.
    $ConfirmationFile = Join-Path $OutputDirectory "AuditEnabled.txt"

    "PowerShell auditing configured on $(Get-Date)" |
        Out-File -FilePath $ConfirmationFile -Encoding UTF8 -Force

    Write-Host "[OK] PowerShell auditing configured." -ForegroundColor Green
    Write-Host "[OK] Transcript directory: $OutputDirectory"
    Write-Host "[OK] Confirmation file: $ConfirmationFile"
    Write-Host "[INFO] Verify Event ID 4104 in the PowerShell Operational log."
}
catch {
    Write-Error "Failed to configure PowerShell auditing: $_"
    exit 1
}
