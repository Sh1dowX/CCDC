
<#
.SYNOPSIS
    Lists scheduled tasks outside selected default Microsoft paths.
.DESCRIPTION
    Assists with manual review of Windows scheduled tasks.
    Non-default does not necessarily mean malicious.
.EXAMPLE
    .\ListNon-defaultScheduledTasks.ps1
.EXAMPLE
    .\ListNon-defaultScheduledTasks.ps1 -OutputDirectory "D:\Reports"
#>

param(
    [string]$OutputDirectory = ".\Reports"
)

$ErrorActionPreference = "Stop"

try {
    $OutputDirectory = [System.IO.Path]::GetFullPath(
        $OutputDirectory
    )

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force | Out-Null

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $ReportFile = Join-Path `
        $OutputDirectory `
        "ScheduledTasks_$Timestamp.txt"

    $DefaultPaths = @(
        "\Microsoft\Windows\",
        "\Microsoft\"
    )

    $Tasks = Get-ScheduledTask |
        Sort-Object TaskPath, TaskName

    $Results = @()

    foreach ($Task in $Tasks) {
        $TaskPath = $Task.TaskPath

        $IsDefault = $false

        foreach ($Path in $DefaultPaths) {
            if ($TaskPath.StartsWith(
                $Path,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                $IsDefault = $true
                break
            }
        }

        if ($IsDefault) {
            continue
        }

        $Actions = @(
            foreach ($Action in $Task.Actions) {
                "$($Action.Execute) $($Action.Arguments)".Trim()
            }
        ) -join "; "

        $Results += [PSCustomObject]@{
            TaskName = $Task.TaskName
            TaskPath = $Task.TaskPath
            State    = $Task.State
            Author   = $Task.Author
            Actions  = $Actions
        }
    }

    if ($Results.Count -gt 0) {
        $Results |
            Format-List * |
            Out-File -FilePath $ReportFile -Encoding UTF8 -Width 300
    }
    else {
        "No matching scheduled tasks found." |
            Out-File -FilePath $ReportFile -Encoding UTF8
    }

    Write-Host "[OK] Scheduled task inspection completed." -ForegroundColor Green
    Write-Host "[OK] Tasks found: $($Results.Count)"
    Write-Host "[OK] Report: $ReportFile"
}
catch {
    Write-Error "Scheduled task inspection failed: $_"
    exit 1
}
