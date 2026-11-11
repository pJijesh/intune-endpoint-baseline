#Requires -Version 7.0
<#
.SYNOPSIS
    Creates or updates the baseline policies in an Intune tenant through Microsoft Graph.

.DESCRIPTION
    Reads policies/manifest.json and each referenced JSON file, then for every policy:
      * looks up an existing policy with the same displayName (after prefix and suffix are applied)
        and the same @odata.type
      * creates it if missing, updates it if its settings differ, or leaves it alone if identical

    Safe by default: nothing is written unless -Apply is given. Without -Apply the script runs as
    a dry run (it behaves as if -WhatIf were set) and reports what it would do. The standard
    -WhatIf and -Confirm switches also work together with -Apply.

    Policies are never assigned to any group. Assign them yourself, to a pilot group first.

    Least privilege: the only Graph scope requested is DeviceManagementConfiguration.ReadWrite.All.
    The script uses Invoke-MgGraphRequest, so only the Microsoft.Graph.Authentication module is needed.

    Idempotent: running it twice with the same inputs creates nothing the second time. Matching is
    by displayName and type, so renaming a policy in the portal makes the script treat it as new.
    If more than one existing policy matches, the script skips that policy and reports an error.

    Limitation: on update, scheduledActionsForRule is not changed. Edit compliance actions in the
    portal or recreate the policy.

.PARAMETER PolicyPath
    Folder containing manifest.json and the policy files. Defaults to ../policies.

.PARAMETER NamePrefix
    Text added before each displayName, for example "PILOT-". Letters, digits, space, dot,
    underscore, hyphen and square brackets only, 32 characters at most.

.PARAMETER NameSuffix
    Text added after each displayName, for example "-v2". Same character rules as NamePrefix.

.PARAMETER Apply
    Actually create or update policies. Omit for a dry run.

.PARAMETER Offline
    Do not connect to Graph. Prints what would be attempted without checking tenant state.
    Useful for reviewing the plan and for testing without a tenant.

.EXAMPLE
    ./scripts/Import-IntunePolicies.ps1 -NamePrefix 'PILOT-'
    Dry run against the connected tenant. No changes are made.

.EXAMPLE
    ./scripts/Import-IntunePolicies.ps1 -NamePrefix 'PILOT-' -Apply
    Creates or updates the policies with a PILOT- prefix.

.EXAMPLE
    ./scripts/Import-IntunePolicies.ps1 -Offline
    Prints the plan without connecting to Graph.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$PolicyPath = (Join-Path $PSScriptRoot '..' 'policies'),

    [ValidatePattern('^[A-Za-z0-9 _.\-\[\]]{0,32}$')]
    [string]$NamePrefix = '',

    [ValidatePattern('^[A-Za-z0-9 _.\-\[\]]{0,32}$')]
    [string]$NameSuffix = '',

    [switch]$Apply,

    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requiredScope = 'DeviceManagementConfiguration.ReadWrite.All'
$readOnlyKeys = @('id', 'createdDateTime', 'lastModifiedDateTime', 'version')

# Dry run unless -Apply is given
if (-not $Apply) { $WhatIfPreference = $true }

function Get-GraphBase {
    param([string]$GraphVersion)
    return "https://graph.microsoft.com/$GraphVersion"
}

function Get-AllPage {
    param([string]$Uri)
    $items = [System.Collections.Generic.List[object]]::new()
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        if ($page.PSObject.Properties.Name -contains 'value') {
            foreach ($item in @($page.value)) { $items.Add($item) }
        }
        $Uri = if ($page.PSObject.Properties.Name -contains '@odata.nextLink') { $page.'@odata.nextLink' } else { $null }
    }
    return , $items
}

function ConvertTo-Canonical {
    param($Value)
    return (ConvertTo-Json -InputObject $Value -Depth 20 -Compress)
}

function Test-SettingsMatch {
    <# True when every desired property already has the same value on the existing object. #>
    param($Desired, $Existing, [string[]]$IgnoreKeys)
    foreach ($key in $Desired.PSObject.Properties.Name) {
        if ($IgnoreKeys -contains $key) { continue }
        if ($Existing.PSObject.Properties.Name -notcontains $key) { return $false }
        $want = ConvertTo-Canonical $Desired.$key
        $have = ConvertTo-Canonical $Existing.$key
        if ($want -ne $have) {
            # Enum casing can differ between request and response, so compare strings loosely
            if (-not ($Desired.$key -is [string] -and $Existing.$key -is [string] -and $Desired.$key -ieq $Existing.$key)) {
                return $false
            }
        }
    }
    return $true
}

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result {
    param([string]$Name, [string]$Action, [string]$Detail = '')
    $results.Add([pscustomobject]@{ Policy = $Name; Action = $Action; Detail = $Detail })
}

# Load the manifest
$policyRoot = (Resolve-Path -LiteralPath $PolicyPath).Path
$manifestFile = Join-Path $policyRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestFile)) { throw "manifest.json not found in $policyRoot" }
$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json -Depth 20

# Connect
if (-not $Offline) {
    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw 'Invoke-MgGraphRequest not found. Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }
    $context = Get-MgContext
    if (-not $context -or ($context.Scopes -notcontains $requiredScope)) {
        Connect-MgGraph -Scopes $requiredScope -NoWelcome | Out-Null
        $context = Get-MgContext
    }
    Write-Information "Connected. Tenant context present: $([bool]$context). Mode: $(if ($Apply) { 'APPLY' } else { 'DRY RUN' })" -InformationAction Continue
}
else {
    Write-Information 'Offline mode: tenant state is not checked.' -InformationAction Continue
}

$existingCache = @{}

foreach ($entry in @($manifest.policies)) {
    $path = Join-Path $policyRoot $entry.file
    $body = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 50
    $baseName = [string]$body.displayName
    $finalName = "$NamePrefix$baseName$NameSuffix"
    $odataType = [string]$body.'@odata.type'

    # Build the request body: apply naming, drop read-only keys
    $desired = [ordered]@{}
    foreach ($prop in $body.PSObject.Properties) {
        if ($readOnlyKeys -contains $prop.Name) { continue }
        $desired[$prop.Name] = $prop.Value
    }
    $desired['displayName'] = $finalName
    $desiredObject = [pscustomobject]$desired

    if ($Offline) {
        if ($PSCmdlet.ShouldProcess($finalName, 'Create or update (remote state not checked)')) {
            Add-Result $finalName 'Applied' 'offline'
        }
        else {
            Add-Result $finalName 'WouldCreateOrUpdate' "offline, $($entry.graphVersion) $($entry.collection)"
        }
        continue
    }

    $base = Get-GraphBase $entry.graphVersion
    $collectionUri = "$base/$($entry.collection)"
    $cacheKey = $collectionUri
    try {
        if (-not $existingCache.ContainsKey($cacheKey)) {
            $existingCache[$cacheKey] = Get-AllPage -Uri $collectionUri
        }
        $found = @($existingCache[$cacheKey] | Where-Object {
                $_.displayName -ceq $finalName -and $_.'@odata.type' -eq $odataType
            })

        if ($found.Count -gt 1) {
            Add-Result $finalName 'Error' "$($found.Count) existing policies share this name and type. Resolve manually."
            continue
        }

        if ($found.Count -eq 0) {
            if ($PSCmdlet.ShouldProcess($finalName, "Create ($($entry.graphVersion))")) {
                $json = ConvertTo-Json -InputObject $desiredObject -Depth 20
                $created = Invoke-MgGraphRequest -Method POST -Uri $collectionUri -Body $json -ContentType 'application/json' -OutputType PSObject
                $existingCache[$cacheKey].Add($created)
                Add-Result $finalName 'Created'
            }
            else {
                Add-Result $finalName 'WouldCreate'
            }
            continue
        }

        $current = $found[0]
        # scheduledActionsForRule cannot be patched inline, so it is excluded from update and comparison
        $ignore = @('@odata.type', 'scheduledActionsForRule')
        if (Test-SettingsMatch -Desired $desiredObject -Existing $current -IgnoreKeys $ignore) {
            Add-Result $finalName 'Unchanged'
            continue
        }

        if ($PSCmdlet.ShouldProcess($finalName, "Update ($($entry.graphVersion))")) {
            $patch = [ordered]@{}
            foreach ($prop in $desiredObject.PSObject.Properties) {
                if ($prop.Name -eq 'scheduledActionsForRule') { continue }
                $patch[$prop.Name] = $prop.Value
            }
            $json = ConvertTo-Json -InputObject $patch -Depth 20
            Invoke-MgGraphRequest -Method PATCH -Uri "$collectionUri/$($current.id)" -Body $json -ContentType 'application/json' | Out-Null
            Add-Result $finalName 'Updated'
        }
        else {
            Add-Result $finalName 'WouldUpdate'
        }
    }
    catch {
        Add-Result $finalName 'Error' $_.Exception.Message
    }
}

$results | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output
$errors = @($results | Where-Object Action -eq 'Error').Count
Write-Output ("Summary: {0}" -f (($results | Group-Object Action | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '))
if (-not $Apply) { Write-Output 'Dry run only. Re-run with -Apply to make changes.' }
if ($errors -gt 0) { exit 1 }
exit 0
