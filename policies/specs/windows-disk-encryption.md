# EB-WIN-CFG-DiskEncryption (specification)

Target: Windows 11, corporate-owned, Microsoft Entra joined.
Intune location: Endpoint security > Disk encryption > Create policy > Windows > BitLocker
(profile type naming varies between "BitLocker" and the settings catalog).

## Why this is a specification and not JSON

`policies/windows/EB-WIN-CFG-EndpointProtection-Baseline.json` sets `bitLockerEncryptDevice`, which
requires encryption but prompts the user. Silent enablement, cipher selection and recovery key
escrow are controlled by the BitLocker configuration service provider settings exposed through the
endpoint security disk encryption profile. Those are settings catalog items and are not part of
the `windows10EndpointProtectionConfiguration` resource.

## Settings

| Setting (as labelled in the admin centre) | Recommended value | Reason |
|---|---|---|
| Require Device Encryption | Enabled | Encryption at rest is the control that limits impact of a lost or stolen laptop. |
| Allow Warning For Other Disk Encryption | Disabled | Required for silent enablement. Without it the user sees a prompt and some devices never encrypt. |
| Allow Standard User Encryption | Enabled | Standard users are the baseline (see the standard, requirement on local admin rights). Silent encryption must work for them. |
| Configure Recovery Password Rotation | Refresh on devices joined to Microsoft Entra ID | Limits how long a disclosed recovery password stays useful. |
| Save BitLocker recovery information to Microsoft Entra ID (operating system drives) | Enabled | Recovery keys must be retrievable by IT. Check that keys appear against the device record in a test. |
| Do not enable BitLocker until recovery information is stored | Enabled | Prevents encrypting a drive whose key was never escrowed. |
| Encryption method for operating system drives | XTS-AES 256-bit or XTS-AES 128-bit | An organisational choice. Pick one, record it, apply it consistently. |
| Require additional authentication at startup | TPM only unless your risk assessment says otherwise | Pre-boot PIN improves protection against physical attack but raises support cost. Record the decision. |

## Hardware prerequisites for silent encryption

Devices need a TPM and UEFI with Secure Boot, and must be running a supported Windows 11 build.
The readiness script (`scripts/Test-WindowsReadiness.ps1`) reports TPM, Secure Boot and BitLocker state.

## Assignment and verification

- Assign to the pilot device group first. Do not assign to devices that are already encrypted with a
  different method until you have tested what the policy does to them.
- Verify in the admin centre that the recovery key is present for a pilot device
  (Devices > the device > Recovery keys) and that the compliance policy `EB-WIN-CMP-Baseline` reports it compliant.
- Restrict who can read recovery keys. Reading a key is a privileged action and should be audited.

## Rollback

Remove the assignment. Do not decrypt devices as a rollback step. Leaving drives encrypted is safe
as long as recovery keys remain escrowed.
