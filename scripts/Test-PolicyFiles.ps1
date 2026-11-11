#Requires -Version 7.0
<#
.SYNOPSIS
    Offline linter for the policy JSON files in this repository.

.DESCRIPTION
    Makes no network calls and needs no Microsoft Graph module. Checks that:
      * every file is valid JSON and a JSON object
      * required keys exist (@odata.type, displayName, description)
      * displayName follows the naming convention EB-<WIN|MAC>-<CMP|CFG|UPD>-<Name>
        and matches the file name
      * read-only or tenant-specific keys (id, version, assignments and so on) are absent
      * no GUIDs (tenant, object or application IDs), tenant domains, email addresses
        or secret-like strings appear anywhere in the file
      * every file is listed in manifest.json with a matching @odata.type, a valid Graph
        version and the correct collection, and no manifest entry points at a missing file
      * display names are unique
      * compliance policies carry exactly one "block" scheduled action

    Exits with code 1 if any error is found, otherwise 0. Warnings do not change the exit code.

.PARAMETER PolicyPath
    Folder containing the policy files. Defaults to ../policies relative to this script.

.PARAMETER ManifestPath
    Path to manifest.json. Defaults to manifest.json inside PolicyPath.

.EXAMPLE
    pwsh ./scripts/Test-PolicyFiles.ps1

.EXAMPLE
    pwsh ./scripts/Test-PolicyFiles.ps1 -PolicyPath ./tests/fixtures/bad
#>
[CmdletBinding()]
param(
    [string]$PolicyPath = (Join-Path $PSScriptRoot '..' 'policies'),
    [string]$ManifestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$namePattern = '^EB-(WIN|MAC)-(CMP|CFG|UPD)-[A-Za-z0-9]+(-[A-Za-z0-9]+)*$'
$guidPattern = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
$secretPatterns = @(
    '(?i)client_?secret',
    '(?i)"password"\s*:\s*"[^"]+"',
    '(?i)bearer\s+[a-z0-9\-_\.]{10,}',
    'eyJ[A-Za-z0-9_\-]{10,}\.',
    '-----BEGIN [A-Z ]*PRIVATE KEY-----',
    '(?i)SharedAccessSignature',
    '(?i)\bsig=[A-Za-z0-9%]{10,}'
)
$forbiddenKeys = @('id', 'createdDateTime', 'lastModifiedDateTime', 'version', 'assignments', 'supportsScopeTags')
$allowedGraphVersions = @('v1.0', 'beta')
$complianceTypes = @(
    '#microsoft.graph.windows10CompliancePolicy',
    '#microsoft.graph.macOSCompliancePolicy'
)

$findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param(
        [ValidateSet('ERROR', 'WARN')][string]$Severity,
        [string]$File,
        [string]$Code,
        [string]$Message
    )
    $findings.Add([pscustomobject]@{ Severity = $Severity; File = $File; Code = $Code; Message = $Message })
}

if (-not (Test-Path -LiteralPath $PolicyPath -PathType Container)) {
    Write-Output "ERROR: policy path not found: $PolicyPath"
    exit 2
}
$policyRoot = (Resolve-Path -LiteralPath $PolicyPath).Path
if (-not $ManifestPath) { $ManifestPath = Join-Path $policyRoot 'manifest.json' }

# Load the manifest
$manifestEntries = @{}
if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    try {
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -Depth 20
        foreach ($entry in @($manifest.policies)) {
            $manifestEntries[($entry.file -replace '\\', '/')] = $entry
        }
    }
    catch {
        Add-Finding -Severity ERROR -File 'manifest.json' -Code 'MANIFEST_INVALID' -Message "Manifest is not valid JSON: $($_.Exception.Message)"
    }
}
else {
    Add-Finding -Severity ERROR -File 'manifest.json' -Code 'MANIFEST_MISSING' -Message "Manifest not found at $ManifestPath"
}

$files = Get-ChildItem -LiteralPath $policyRoot -Filter '*.json' -Recurse -File |
    Where-Object { $_.Name -ne 'manifest.json' } |
    Sort-Object FullName

$seenNames = @{}

foreach ($file in $files) {
    $rel = ($file.FullName.Substring($policyRoot.Length).TrimStart('\', '/')) -replace '\\', '/'
    $raw = Get-Content -LiteralPath $file.FullName -Raw

    # Secret and tenant-identifier scan runs on raw text so it still works on malformed JSON
    if ($raw -match $guidPattern) {
        Add-Finding ERROR $rel 'GUID_FOUND' 'A GUID was found. Policy files must not contain tenant, object, group or application IDs.'
    }
    if ($raw -match '(?i)[a-z0-9\-]+\.onmicrosoft\.com') {
        Add-Finding ERROR $rel 'TENANT_DOMAIN' 'A tenant domain (onmicrosoft.com) was found.'
    }
    if ($raw -match '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}') {
        Add-Finding ERROR $rel 'EMAIL_FOUND' 'An email address was found.'
    }
    foreach ($pattern in $secretPatterns) {
        if ($raw -match $pattern) {
            Add-Finding ERROR $rel 'SECRET_PATTERN' "Secret-like content matched pattern: $pattern"
        }
    }

    try {
        $doc = $raw | ConvertFrom-Json -Depth 50
    }
    catch {
        Add-Finding ERROR $rel 'INVALID_JSON' "File is not valid JSON: $($_.Exception.Message)"
        continue
    }

    if ($doc -isnot [pscustomobject]) {
        Add-Finding ERROR $rel 'NOT_OBJECT' 'Top level must be a single JSON object.'
        continue
    }

    $props = $doc.PSObject.Properties.Name

    foreach ($required in @('@odata.type', 'displayName', 'description')) {
        if ($props -notcontains $required) {
            Add-Finding ERROR $rel 'MISSING_KEY' "Required key '$required' is missing."
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$doc.$required)) {
            Add-Finding ERROR $rel 'EMPTY_KEY' "Required key '$required' is empty."
        }
    }

    foreach ($key in $forbiddenKeys) {
        if ($props -contains $key) {
            Add-Finding ERROR $rel 'FORBIDDEN_KEY' "Key '$key' is read-only or tenant-specific and must not be in a portable policy file."
        }
    }

    $odataType = if ($props -contains '@odata.type') { [string]$doc.'@odata.type' } else { '' }
    if ($odataType -and $odataType -notmatch '^#microsoft\.graph\.[A-Za-z0-9]+$') {
        Add-Finding ERROR $rel 'BAD_ODATA_TYPE' "@odata.type '$odataType' must look like #microsoft.graph.<typeName>."
    }

    if ($props -contains 'displayName' -and -not [string]::IsNullOrWhiteSpace([string]$doc.displayName)) {
        $name = [string]$doc.displayName
        if ($name -cnotmatch $namePattern) {
            Add-Finding ERROR $rel 'BAD_NAME' "displayName '$name' does not match $namePattern"
        }
        if ($name -ne [System.IO.Path]::GetFileNameWithoutExtension($file.Name)) {
            Add-Finding ERROR $rel 'NAME_FILE_MISMATCH' "displayName '$name' does not match the file name."
        }
        if ($seenNames.ContainsKey($name)) {
            Add-Finding ERROR $rel 'DUPLICATE_NAME' "displayName '$name' is also used by $($seenNames[$name])."
        }
        else {
            $seenNames[$name] = $rel
        }
    }

    # Compliance policies: exactly one block action
    if ($complianceTypes -contains $odataType) {
        $blockCount = 0
        if ($props -contains 'scheduledActionsForRule') {
            foreach ($rule in @($doc.scheduledActionsForRule)) {
                foreach ($action in @($rule.scheduledActionConfigurations)) {
                    if ($action.actionType -eq 'block') { $blockCount++ }
                }
            }
        }
        if ($blockCount -ne 1) {
            Add-Finding ERROR $rel 'BLOCK_ACTION_COUNT' "Compliance policies must have exactly one 'block' scheduled action (found $blockCount)."
        }
    }

    # Manifest cross-checks
    if ($manifestEntries.ContainsKey($rel)) {
        $entry = $manifestEntries[$rel]
        if ($entry.odataType -ne $odataType) {
            Add-Finding ERROR $rel 'MANIFEST_TYPE_MISMATCH' "Manifest odataType '$($entry.odataType)' differs from file '$odataType'."
        }
        if ($allowedGraphVersions -notcontains $entry.graphVersion) {
            Add-Finding ERROR $rel 'MANIFEST_GRAPH_VERSION' "graphVersion '$($entry.graphVersion)' must be one of: $($allowedGraphVersions -join ', ')."
        }
        $expectedCollection = if ($complianceTypes -contains $odataType) { 'deviceManagement/deviceCompliancePolicies' } else { 'deviceManagement/deviceConfigurations' }
        if ($entry.collection -ne $expectedCollection) {
            Add-Finding ERROR $rel 'MANIFEST_COLLECTION' "Collection '$($entry.collection)' should be '$expectedCollection' for $odataType."
        }
    }
    elseif ($manifestEntries.Count -gt 0 -or (Test-Path -LiteralPath $ManifestPath)) {
        Add-Finding ERROR $rel 'NOT_IN_MANIFEST' 'File is not listed in manifest.json.'
    }
}

foreach ($listed in $manifestEntries.Keys) {
    if (-not (Test-Path -LiteralPath (Join-Path $policyRoot $listed) -PathType Leaf)) {
        Add-Finding ERROR $listed 'MANIFEST_FILE_MISSING' 'Manifest lists a file that does not exist.'
    }
}

foreach ($f in $findings) {
    Write-Output ('[{0}] {1}: {2} {3}' -f $f.Severity, $f.File, $f.Code, $f.Message)
}
$errorCount = @($findings | Where-Object Severity -eq 'ERROR').Count
$warnCount = @($findings | Where-Object Severity -eq 'WARN').Count
Write-Output ("Checked {0} policy file(s): {1} error(s), {2} warning(s)." -f @($files).Count, $errorCount, $warnCount)

if ($errorCount -gt 0) { exit 1 }
exit 0
