<#
.SYNOPSIS
    Read-only readiness check for a Windows 11 device against this baseline.

.DESCRIPTION
    Reports BitLocker, TPM, Secure Boot, Microsoft Defender, firewall, OS build, join and
    management state, local administrator count and pending restart. It changes nothing on the
    device and sends nothing anywhere. Run it in an elevated session for complete results;
    without elevation some checks report WARN with the reason.

    Output contains booleans, counts and versions only. It does not print user names, tenant
    names, tenant IDs or recovery keys, so results are safer to paste into a ticket.

    Works in Windows PowerShell 5.1 and PowerShell 7. On a non-Windows host it exits with code 2.

    Exit codes: 0 no FAIL results, 1 at least one FAIL, 2 not a Windows host.

.PARAMETER MinimumBuild
    Minimum Windows build number. Keep in step with osMinimumVersion in the compliance policy.

.PARAMETER MaxSignatureAgeDays
    Defender signature age (days) above which the check warns.

.PARAMETER MaxLocalAdmins
    Number of local administrator group members above which the check warns.

.PARAMETER AsJson
    Emit results as JSON instead of a table.

.EXAMPLE
    .\Test-WindowsReadiness.ps1

.EXAMPLE
    .\Test-WindowsReadiness.ps1 -AsJson | Out-File readiness.json
#>
[CmdletBinding()]
param(
    [int]$MinimumBuild = 26100,
    [int]$MaxSignatureAgeDays = 3,
    [int]$MaxLocalAdmins = 2,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isWindowsHost = $true
if ($PSVersionTable.PSEdition -eq 'Core') {
    $isWindowsHost = [bool]$IsWindows
}
if (-not $isWindowsHost) {
    Write-Output 'This check runs on Windows only. Nothing was checked.'
    exit 2
}

$results = New-Object System.Collections.Generic.List[object]
function Add-Check {
    param(
        [string]$Check,
        [ValidateSet('PASS', 'WARN', 'FAIL', 'INFO')][string]$Status,
        [string]$Detail
    )
    $results.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Add-Check 'Elevation' 'WARN' 'Not running as administrator. BitLocker, TPM and Secure Boot checks may be incomplete.'
}

# Operating system
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $detail = "$($os.Caption), build $($os.BuildNumber)"
    if ($build -ge $MinimumBuild) { Add-Check 'OS build' 'PASS' "$detail (minimum $MinimumBuild)" }
    else { Add-Check 'OS build' 'FAIL' "$detail is below the minimum build $MinimumBuild" }
}
catch { Add-Check 'OS build' 'WARN' "Could not read OS details: $($_.Exception.Message)" }

# TPM
try {
    $tpm = Get-Tpm
    if ($tpm.TpmPresent -and $tpm.TpmReady) { Add-Check 'TPM' 'PASS' 'TPM present and ready' }
    elseif ($tpm.TpmPresent) { Add-Check 'TPM' 'WARN' 'TPM present but not ready' }
    else { Add-Check 'TPM' 'FAIL' 'No TPM detected' }
}
catch { Add-Check 'TPM' 'WARN' "Could not query TPM (elevation may be required): $($_.Exception.Message)" }

# Secure Boot
try {
    if (Confirm-SecureBootUEFI) { Add-Check 'Secure Boot' 'PASS' 'Enabled' }
    else { Add-Check 'Secure Boot' 'FAIL' 'Supported but disabled' }
}
catch { Add-Check 'Secure Boot' 'WARN' 'Could not confirm. Device may use legacy BIOS, or elevation is required.' }

# BitLocker on the system drive
try {
    $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive
    $hasRecovery = @($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).Count -gt 0
    $detail = "Volume $($volume.VolumeStatus), protection $($volume.ProtectionStatus), method $($volume.EncryptionMethod), recovery password protector present: $hasRecovery"
    if ($volume.ProtectionStatus -eq 'On') { Add-Check 'BitLocker (system drive)' 'PASS' $detail }
    else { Add-Check 'BitLocker (system drive)' 'FAIL' $detail }
}
catch { Add-Check 'BitLocker (system drive)' 'WARN' "Could not query BitLocker (elevation required, or feature unavailable): $($_.Exception.Message)" }

# Microsoft Defender Antivirus
try {
    $mp = Get-MpComputerStatus
    if ($mp.AMServiceEnabled -and $mp.AntivirusEnabled) { Add-Check 'Defender antivirus' 'PASS' 'Service and antivirus enabled' }
    else { Add-Check 'Defender antivirus' 'FAIL' "AMServiceEnabled=$($mp.AMServiceEnabled), AntivirusEnabled=$($mp.AntivirusEnabled). Another product may be primary." }
    if ($mp.RealTimeProtectionEnabled) { Add-Check 'Defender real-time protection' 'PASS' 'On' }
    else { Add-Check 'Defender real-time protection' 'FAIL' 'Off' }
    $age = [int]$mp.AntivirusSignatureAge
    if ($age -le $MaxSignatureAgeDays) { Add-Check 'Defender signatures' 'PASS' "$age day(s) old" }
    else { Add-Check 'Defender signatures' 'WARN' "$age day(s) old (threshold $MaxSignatureAgeDays)" }
}
catch { Add-Check 'Defender antivirus' 'WARN' "Could not query Defender: $($_.Exception.Message)" }

# Windows Defender Firewall
try {
    foreach ($fw in Get-NetFirewallProfile) {
        if ($fw.Enabled -eq 'True' -or $fw.Enabled -eq $true) { Add-Check "Firewall: $($fw.Name)" 'PASS' "Enabled, default inbound action $($fw.DefaultInboundAction)" }
        else { Add-Check "Firewall: $($fw.Name)" 'FAIL' 'Disabled' }
    }
}
catch { Add-Check 'Firewall' 'WARN' "Could not query firewall: $($_.Exception.Message)" }

# Join and management state (booleans only)
try {
    $dsreg = & dsregcmd.exe /status 2>$null
    function Get-DsregFlag {
        param([string]$Name)
        $line = $dsreg | Where-Object { $_ -match "^\s*$Name\s*:" } | Select-Object -First 1
        if ($line) { return (($line -split ':', 2)[1]).Trim() }
        return 'UNKNOWN'
    }
    $aadJoined = Get-DsregFlag 'AzureAdJoined'
    $domainJoined = Get-DsregFlag 'DomainJoined'
    $hasPrt = Get-DsregFlag 'AzureAdPrt'
    Add-Check 'Join state' 'INFO' "Entra joined: $aadJoined, domain joined: $domainJoined, primary refresh token: $hasPrt"
    $mdmLine = $dsreg | Where-Object { $_ -match '^\s*MdmUrl\s*:\s*\S+' } | Select-Object -First 1
    if ($mdmLine) { Add-Check 'MDM enrolment' 'PASS' 'An MDM URL is configured (device appears enrolled)' }
    else { Add-Check 'MDM enrolment' 'WARN' 'No MDM URL found in dsregcmd output (device may not be enrolled)' }
}
catch { Add-Check 'Join state' 'WARN' "Could not run dsregcmd: $($_.Exception.Message)" }

# Local administrators (count only)
try {
    $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544')
    if ($admins.Count -le $MaxLocalAdmins) { Add-Check 'Local administrators' 'PASS' "$($admins.Count) member(s) (threshold $MaxLocalAdmins)" }
    else { Add-Check 'Local administrators' 'WARN' "$($admins.Count) member(s) (threshold $MaxLocalAdmins). Review who needs standing admin rights." }
}
catch { Add-Check 'Local administrators' 'WARN' "Could not read group: $($_.Exception.Message)" }

# Pending restart
$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
if ($pending) { Add-Check 'Pending restart' 'WARN' 'A restart is pending. Updates may not be fully applied.' }
else { Add-Check 'Pending restart' 'PASS' 'None detected' }

$fails = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
$warns = @($results | Where-Object { $_.Status -eq 'WARN' }).Count

if ($AsJson) {
    [pscustomobject]@{
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        failCount    = $fails
        warnCount    = $warns
        results      = $results
    } | ConvertTo-Json -Depth 5
}
else {
    $results | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output
    Write-Output "Summary: $fails FAIL, $warns WARN. This check is read-only and changed nothing."
}

if ($fails -gt 0) { exit 1 }
exit 0
