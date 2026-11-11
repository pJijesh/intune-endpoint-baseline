# Troubleshooting

Common problems with enrolment, compliance, updates and the scripts in this repository, with what to
check first. These are the usual causes, not a guarantee of cause in your tenant.

## Quick triage

1. Is the device enrolled? Check the device record in Intune and, on Windows, `dsregcmd /status`.
2. When did it last check in? A device that has not checked in cannot report compliance.
3. Which policy rule fails? Open the device in Intune > Compliance and read the per-setting status.
4. Is it a conflict or a wrong assignment? Look at the device's configuration profile status.

## Windows

| Symptom | Likely cause | What to check or do |
|---|---|---|
| Device shows "not evaluated" or never reports compliance | Not enrolled, no policy assigned, or no recent check-in | Confirm enrolment and assignment. Trigger a sync from Settings > Accounts > Access work or school > Info > Sync. |
| BitLocker reported non-compliant on an encrypted device | The compliance rule relies on Device Health Attestation, which depends on TPM health, Secure Boot and a recent check-in | Run `scripts/Test-WindowsReadiness.ps1` elevated. Check TPM and Secure Boot. Sync, then wait for the next evaluation. |
| BitLocker prompts the user instead of encrypting silently | The silent encryption settings are not applied, or the user is a standard user without the standard-user encryption setting | See [windows-disk-encryption.md](../policies/specs/windows-disk-encryption.md). |
| Recovery key missing in Entra ID | Escrow setting not applied, or encryption started before the policy | Check the policy status. Rotating the recovery password forces a new escrow. |
| Secure Boot shows warning or unknown | Legacy BIOS mode, or the check lacked elevation | Confirm firmware mode with `msinfo32`. Legacy mode needs converting, which is a hardware change and not something to do blindly. |
| Defender rule fails because another antivirus is present | Another product is registered as primary | Decide on one product. The compliance rule `antivirusRequired` accepts any registered product, but `defenderEnabled` and `rtpEnabled` require Defender. Remove those rules if a third-party product is your standard. |
| Update ring not applied | Policy not assigned, or conflicting policy (group policy, a second ring, or a feature update policy) | Check for overlapping assignments. Use the device's profile status. Look at the `DeviceManagement-Enterprise-Diagnostics-Provider` event log. |
| Device stuck at the Enrollment Status Page | A required app or policy is failing, or a timeout | Check which item is pending in the ESP, review app install status and the same event log, and consider a longer timeout. |
| Autopilot profile not applied | Device not registered, wrong group tag, or group membership delay | Check Devices > Windows > Enrollment > Devices. Dynamic groups can take time to populate. |

Useful Windows commands (read-only):

```powershell
dsregcmd /status                 # join and MDM state
Get-Tpm                          # TPM state, elevated
Confirm-SecureBootUEFI           # Secure Boot, elevated
Get-BitLockerVolume              # BitLocker state, elevated
Get-MpComputerStatus             # Defender state
```

## macOS

| Symptom | Likely cause | What to check or do |
|---|---|---|
| Mac does not receive the enrolment profile at Setup Assistant | Device not assigned to the Intune MDM server in ABM, no profile assigned, or the ABM token expired | Check ABM device assignment, the profile assignment in Intune and the token status. |
| MDM profile missing after setup | Enrolment interrupted | Run `sudo profiles renew -type enrollment` or erase and re-enrol. |
| Devices stop being managed all at once | The Apple MDM push certificate expired | Renew it with the same Apple Account that created it. |
| FileVault not enabled | Policy not applied, user deferred the prompt, or the user ignored the prompt within the allowed number of times | Check policy status. The baseline allows deferral until sign-out and a limited number of ignores. |
| FileVault key not in Intune | Encryption started before the policy, or the key was not escrowed | Re-key by turning FileVault off and on again (needs the user and appropriate approval), or use the rotation options in Intune. |
| Compliant Mac blocked by Conditional Access | The browser is not passing the device identity | Check Company Portal, the Enterprise SSO plug-in, and (for Chrome) the Microsoft single sign-on extension. |
| Gatekeeper or SIP reported off | Tampering, or an unusual configuration | Treat as a security event. Do not just re-enable without understanding why. |

Useful macOS commands (read-only unless noted):

```bash
profiles status -type enrollment      # enrolment state
profiles list                         # installed profiles (may need sudo)
fdesetup status                       # FileVault
scripts/macos-readiness-check.sh      # this repository's read-only check
```

## Compliance and Conditional Access

| Symptom | Likely cause | What to check or do |
|---|---|---|
| Everyone is blocked after enabling the policy | The policy was enforced before report-only testing, or the "no policy" default flipped | Use an emergency access account, set the policy to report-only, review the sign-in log. |
| A device is compliant in Intune but blocked | Token not refreshed yet, or device identity not presented | Sign out and in, wait for the next check-in. On macOS see the Company Portal item above. |
| New devices cannot enrol | The Conditional Access policy applies to the enrolment app | Exclude the Microsoft Intune Enrollment app or narrow the policy. |
| Many devices stuck "in grace period" | Policy too strict for the estate, or a remediation that never ran | Look at which rule fails most often, and fix or relax that rule. |

## The scripts

| Symptom | Likely cause | What to check or do |
|---|---|---|
| `Invoke-MgGraphRequest not found` | Module missing | `Install-Module Microsoft.Graph.Authentication -Scope CurrentUser` |
| 403 Forbidden on a Graph call | The scope was not consented, or the account lacks an Intune role | Sign in with an account that can consent to `DeviceManagementConfiguration.ReadWrite.All` and holds an Intune role able to manage configuration. |
| 400 Bad Request on create | A property is unknown to the Graph version, or the version is wrong for that property | Check the property against Microsoft Learn for the version listed in `policies/manifest.json`. Beta resources can change. |
| "N existing policies share this name" | Duplicate display names in the tenant | Resolve in the admin centre. The script will not guess. |
| The script wants to update a policy every run | The service returns a different representation of a value | Compare the policy in the admin centre with the file. Idempotency is by name and settings. Report persistent differences. |
| The script reports Created for a policy you thought existed | The name differs by prefix or suffix, or the policy was renamed | Names are matched exactly after prefix and suffix. |
| Linter fails with `GUID_FOUND` | A tenant, group or application ID is in a policy file | Remove it. Policy files must be portable. Assignments are made separately. |

## Collecting information for support

Gather, without sensitive content: the device's OS build, the compliance rule that fails, the policy name and last check-in time, and the output of the readiness script (which prints no user names or tenant identifiers). Do not paste recovery keys, tokens or tenant IDs into tickets.
