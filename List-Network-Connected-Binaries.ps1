
<#
.SYNOPSIS
    Collects network connections and associated process information.
.EXAMPLE
    .\List-Network-Connected-Binaries.ps1
.EXAMPLE
    .\List-Network-Connected-Binaries.ps1 -OutputDirectory "D:\Reports"
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

    $TxtFile = Join-Path $OutputDirectory "NetworkConnections_$Timestamp.txt"
    $CsvFile = Join-Path $OutputDirectory "NetworkConnections_$Timestamp.csv"

    # Cache process information to avoid repeated queries.
    $ProcessCache = @{}

    function Get-ProcessInfo {
        param(
            [int]$ProcessId
        )

        if ($ProcessCache.ContainsKey($ProcessId)) {
            return $ProcessCache[$ProcessId]
        }

        $Info = [PSCustomObject]@{
            Name      = ""
            Path      = ""
            Command   = ""
            User      = ""
            ParentPID = ""
            Signature = ""
        }

        try {
            $Process = Get-Process -Id $ProcessId -ErrorAction Stop

            $Info.Name = $Process.ProcessName
            $Info.Path = $Process.Path
        }
        catch {
            $Info.Name = "Unavailable"
        }

        try {
            $CimProcess = Get-CimInstance Win32_Process `
                -Filter "ProcessId=$ProcessId" `
                -ErrorAction Stop

            if ($null -ne $CimProcess) {
                $Info.Command = $CimProcess.CommandLine
                $Info.ParentPID = $CimProcess.ParentProcessId

                try {
                    $Owner = Invoke-CimMethod `
                        -InputObject $CimProcess `
                        -MethodName GetOwner `
                        -ErrorAction Stop

                    if ($Owner.ReturnValue -eq 0) {
                        $Info.User = "$($Owner.Domain)\$($Owner.User)"
                    }
                }
                catch {
                    $Info.User = "Unavailable"
                }
            }
        }
        catch {
            # Some system processes may be inaccessible.
        }

        if ($Info.Path -and (Test-Path -LiteralPath $Info.Path)) {
            try {
                $Signature = Get-AuthenticodeSignature `
                    -LiteralPath $Info.Path `
                    -ErrorAction Stop

                $Info.Signature = $Signature.Status.ToString()
            }
            catch {
                $Info.Signature = "Unavailable"
            }
        }

        $ProcessCache[$ProcessId] = $Info

        return $Info
    }

    $Results = @()

    # Collect TCP connections.
    foreach ($Connection in Get-NetTCPConnection -ErrorAction Stop) {
        $Info = Get-ProcessInfo -ProcessId $Connection.OwningProcess

        $Results += [PSCustomObject]@{
            Protocol      = "TCP"
            State         = $Connection.State
            LocalAddress  = $Connection.LocalAddress
            LocalPort     = $Connection.LocalPort
            RemoteAddress = $Connection.RemoteAddress
            RemotePort    = $Connection.RemotePort
            PID           = $Connection.OwningProcess
            Process       = $Info.Name
            Path          = $Info.Path
            User          = $Info.User
            CommandLine   = $Info.Command
            ParentPID     = $Info.ParentPID
            Signature     = $Info.Signature
        }
    }

    # Collect UDP endpoints.
    foreach ($Endpoint in Get-NetUDPEndpoint -ErrorAction Stop) {
        $Info = Get-ProcessInfo -ProcessId $Endpoint.OwningProcess

        $Results += [PSCustomObject]@{
            Protocol      = "UDP"
            State         = "N/A"
            LocalAddress  = $Endpoint.LocalAddress
            LocalPort     = $Endpoint.LocalPort
            RemoteAddress = ""
            RemotePort    = ""
            PID           = $Endpoint.OwningProcess
            Process       = $Info.Name
            Path          = $Info.Path
            User          = $Info.User
            CommandLine   = $Info.Command
            ParentPID     = $Info.ParentPID
            Signature     = $Info.Signature
        }
    }

    # Save reports.
    $Results |
        Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8

    $Results |
        Format-List * |
        Out-File -FilePath $TxtFile -Encoding UTF8 -Width 300

    Write-Host "[OK] Network inspection completed." -ForegroundColor Green
    Write-Host "[OK] Connections: $($Results.Count)"
    Write-Host "[OK] TXT: $TxtFile"
    Write-Host "[OK] CSV: $CsvFile"
}
catch {
    Write-Error "Network inspection failed: $_"
    exit 1
}
