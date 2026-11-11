#Requires -Version 7.0
<#
.SYNOPSIS
    Exercises Import-IntunePolicies.ps1 against an in-memory fake of Microsoft Graph.

.DESCRIPTION
    No tenant, network or Graph module is used. Connect-MgGraph, Get-MgContext and
    Invoke-MgGraphRequest are replaced by functions defined here, which take precedence over
    the real cmdlets. Verifies dry-run safety, create, idempotency, drift update, paging,
    duplicate-name handling and that -WhatIf blocks writes even with -Apply.

    Exit code 0 when all checks pass, 1 otherwise.
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Mock functions called from a child script need shared state; script-scope variables resolve against the caller.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$importScript = Join-Path $PSScriptRoot '..' 'scripts' 'Import-IntunePolicies.ps1'

$global:Store = @{}      # collection URI -> list of objects
$global:Calls = [System.Collections.Generic.List[object]]::new()
$global:PageSize = 3

function Connect-MgGraph { param([string[]]$Scopes, [switch]$NoWelcome) $null = $NoWelcome; $global:Calls.Add(@{ Method = 'CONNECT'; Scopes = $Scopes }) }
function Get-MgContext { return [pscustomobject]@{ Scopes = @('DeviceManagementConfiguration.ReadWrite.All') } }

function Invoke-MgGraphRequest {
    param([string]$Method, [string]$Uri, $Body, [string]$ContentType, [string]$OutputType)
    $global:Calls.Add(@{ Method = $Method; Uri = $Uri; Body = $Body })
    $null = $ContentType; $null = $OutputType
    switch ($Method) {
        'GET' {
            $page = 0
            $base = $Uri
            if ($Uri -match '^(.*)\?page=(\d+)$') { $base = $Matches[1]; $page = [int]$Matches[2] }
            $all = @(if ($global:Store.ContainsKey($base)) { $global:Store[$base] })
            $slice = @($all | Select-Object -Skip ($page * $global:PageSize) -First $global:PageSize)
            $result = [ordered]@{ value = $slice }
            if (($page + 1) * $global:PageSize -lt $all.Count) { $result['@odata.nextLink'] = "${base}?page=$($page + 1)" }
            return [pscustomobject]$result
        }
        'POST' {
            $obj = $Body | ConvertFrom-Json -Depth 50
            $obj | Add-Member -NotePropertyName id -NotePropertyValue ([guid]::NewGuid().ToString()) -Force
            $obj | Add-Member -NotePropertyName version -NotePropertyValue 1 -Force
            if (-not $global:Store.ContainsKey($Uri)) { $global:Store[$Uri] = [System.Collections.Generic.List[object]]::new() }
            $global:Store[$Uri].Add($obj)
            return $obj
        }
        'PATCH' {
            $patch = $Body | ConvertFrom-Json -Depth 50
            $collection = $Uri.Substring(0, $Uri.LastIndexOf('/'))
            $id = $Uri.Substring($Uri.LastIndexOf('/') + 1)
            $target = $global:Store[$collection] | Where-Object { $_.id -eq $id }
            foreach ($p in $patch.PSObject.Properties) {
                $target | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
            }
            return $null
        }
        default { throw "Unexpected method $Method" }
    }
}

$global:Failures = 0
function Assert-That {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Output "PASS  $Message" }
    else { Write-Output "FAIL  $Message"; $global:Failures++ }
}
function Get-WriteCount { param([string]$Method) return @($global:Calls | Where-Object { $_.Method -eq $Method }).Count }
function Clear-CallLog { $global:Calls.Clear() }
function Get-StoredCount { return @($global:Store.Values | ForEach-Object { $_ }).Count }

# 1. Dry run (no -Apply) must not write
Clear-CallLog
$null = & $importScript -NamePrefix 'T-'
Assert-That ((Get-WriteCount 'POST') -eq 0 -and (Get-WriteCount 'PATCH') -eq 0) 'dry run performs no POST or PATCH'
Assert-That ((Get-StoredCount) -eq 0) 'dry run leaves the store empty'
Assert-That ($LASTEXITCODE -eq 0) 'dry run exits 0'

# 2. -Apply with -WhatIf must not write either
Clear-CallLog
$null = & $importScript -NamePrefix 'T-' -Apply -WhatIf
Assert-That ((Get-WriteCount 'POST') -eq 0) '-Apply -WhatIf performs no POST'

# 3. Apply creates all policies
Clear-CallLog
$null = & $importScript -NamePrefix 'T-' -NameSuffix '-s' -Apply -Confirm:$false
$manifest = Get-Content (Join-Path $PSScriptRoot '..' 'policies' 'manifest.json') -Raw | ConvertFrom-Json
$expected = @($manifest.policies).Count
Assert-That ((Get-WriteCount 'POST') -eq $expected) "apply creates $expected policies"
$names = @($global:Store.Values | ForEach-Object { $_ } | ForEach-Object { $_.displayName })
Assert-That (@($names | Where-Object { $_ -like 'T-EB-*-s' }).Count -eq $expected) 'prefix and suffix are applied to every displayName'
$postBodies = @($global:Calls | Where-Object { $_.Method -eq 'POST' } | ForEach-Object { $_.Body | ConvertFrom-Json -Depth 50 })
Assert-That (@($postBodies | Where-Object { $_.PSObject.Properties.Name -contains 'id' }).Count -eq 0) 'POST bodies carry no id'
$compliance = @($postBodies | Where-Object { $_.'@odata.type' -like '*CompliancePolicy' })
Assert-That ($compliance.Count -eq 2 -and @($compliance | Where-Object { $_.PSObject.Properties.Name -contains 'scheduledActionsForRule' }).Count -eq 2) 'compliance POST bodies include scheduledActionsForRule'
Assert-That ((@($global:Calls | Where-Object { $_.Method -eq 'POST' -and $_.Uri -like '*/beta/*' }).Count) -eq 2) 'exactly the two beta-targeted policies use the beta endpoint'

# 4. Idempotent second run
Clear-CallLog
$null = & $importScript -NamePrefix 'T-' -NameSuffix '-s' -Apply -Confirm:$false
Assert-That ((Get-WriteCount 'POST') -eq 0 -and (Get-WriteCount 'PATCH') -eq 0) 'second apply performs no writes (idempotent)'
Assert-That ((Get-StoredCount) -eq $expected) 'store still holds the same number of policies'

# 5. Drift is corrected with a single PATCH that excludes scheduledActionsForRule
$drift = $global:Store.Values | ForEach-Object { $_ } | Where-Object { $_.displayName -eq 'T-EB-WIN-CMP-Baseline-s' }
$drift.bitLockerEnabled = $false
Clear-CallLog
$null = & $importScript -NamePrefix 'T-' -NameSuffix '-s' -Apply -Confirm:$false
Assert-That ((Get-WriteCount 'PATCH') -eq 1 -and (Get-WriteCount 'POST') -eq 0) 'drift triggers exactly one PATCH'
$patchBody = ($global:Calls | Where-Object { $_.Method -eq 'PATCH' } | Select-Object -First 1).Body | ConvertFrom-Json -Depth 50
Assert-That ($patchBody.PSObject.Properties.Name -notcontains 'scheduledActionsForRule') 'PATCH body excludes scheduledActionsForRule'
Assert-That ($drift.bitLockerEnabled -eq $true) 'drifted value restored'

# 6. Different prefix means separate objects (no accidental overwrite)
Clear-CallLog
$null = & $importScript -NamePrefix 'OTHER-' -NameSuffix '-s' -Apply -Confirm:$false
Assert-That ((Get-WriteCount 'POST') -eq $expected -and (Get-WriteCount 'PATCH') -eq 0) 'a different prefix creates new policies and leaves existing ones alone'

# 7. Duplicate display names are reported, not guessed
$dupe = $global:Store.Values | ForEach-Object { $_ } | Where-Object { $_.displayName -eq 'OTHER-EB-MAC-CMP-Baseline-s' } | Select-Object -First 1
$copy = $dupe | ConvertTo-Json -Depth 50 | ConvertFrom-Json -Depth 50
$copy.id = [guid]::NewGuid().ToString()
$collectionKey = @($global:Store.Keys | Where-Object { $_ -like '*v1.0*deviceCompliancePolicies' })[0]
$global:Store[$collectionKey].Add($copy)
Clear-CallLog
$null = & $importScript -NamePrefix 'OTHER-' -NameSuffix '-s' -Apply -Confirm:$false
Assert-That ($LASTEXITCODE -eq 1) 'duplicate display names produce a non-zero exit code'
Assert-That ((Get-WriteCount 'PATCH') -eq 0) 'no PATCH is attempted on ambiguous matches'

# 8. Invalid prefix is rejected
$rejected = $false
try { $null = & $importScript -NamePrefix 'bad/prefix' } catch { $rejected = $true }
Assert-That $rejected 'prefix with disallowed characters is rejected'

if ($global:Failures -gt 0) { Write-Output "$($global:Failures) check(s) failed."; exit 1 }
Write-Output 'All mock import checks passed.'
exit 0
