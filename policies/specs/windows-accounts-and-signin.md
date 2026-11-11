# EB-WIN-CFG-AccountsAndSignIn (specification)

Target: Windows 11, corporate-owned, Microsoft Entra joined.
Covers three things: standard user by default, local administrator password management, and
Windows Hello for Business.

## 1. Standard user by default

| Where | Setting | Recommended value |
|---|---|---|
| Autopilot deployment profile | User account type | Standard |
| Microsoft Entra ID > Devices > Device settings | Additional local administrators on Microsoft Entra joined devices | Leave empty unless an exception is documented. Note that the Global Administrator role and device administrators have local admin by design. |
| Endpoint security > Account protection > Local user group membership | Administrators group | Replace (not add) with an explicit list, for example the managed local administrator account only. |

## 2. Windows LAPS (local administrator password solution)

Intune location: Endpoint security > Account protection > Create policy > Windows LAPS.
A tenant-level switch in Microsoft Entra ID (Devices > Device settings, enable Windows LAPS)
must also be on for backup to Entra ID to work.

| Setting | Recommended value | Reason |
|---|---|---|
| Backup directory | Backup to Microsoft Entra ID | Cloud-joined devices have no on-premises directory. |
| Password age (days) | 30 or less | Limits the life of a disclosed password. The exact figure is an organisational choice. |
| Administrator account name | A named managed account, if you use one | Avoids relying on the built-in account name. |
| Password complexity | Large letters, small letters, numbers, special characters | Machine-generated, so complexity costs nothing. |
| Password length | 14 or more | Machine-generated, so length costs nothing. |
| Post-authentication actions | Reset the password and sign out the managed account | Makes each retrieved password single-use. |

Restrict who can read LAPS passwords and review the audit log of reads.

## 3. Windows Hello for Business

Intune location: Endpoint security > Account protection > Create policy > Windows Hello for Business,
or tenant-wide under Devices > Enrollment > Windows Enrollment.

| Setting | Recommended value | Reason |
|---|---|---|
| Configure Windows Hello for Business | Enabled | Replaces typed passwords on the device with a key bound to the hardware. |
| Use a Trusted Platform Module | Required | Binds the credential to the device and gives hardware-backed lockout after repeated failures. |
| Minimum PIN length | 6 is the floor in the Cyber Essentials requirements for unlock-only PINs; 8 or more is a reasonable organisational choice | Record your decision. |
| Allow biometric authentication | Enabled | Fingerprint and face unlock are acceptable credentials for device unlock. |
| Enable PIN recovery | Enabled | Reduces help desk load without weakening the credential. |

Do not set password expiry. Current NCSC guidance does not recommend forced periodic expiry.

## Why `EB-WIN-CMP-Baseline` does not set a password length

The compliance policy requires a password or equivalent to unlock and a lock after inactivity, but
omits length and complexity. On Entra joined devices sign-in strength is delivered by Windows Hello for
Business (this specification) and by multi-factor authentication, so a local-password rule in the
compliance policy would measure the wrong thing.

## Verification

Run `scripts/Test-WindowsReadiness.ps1`, which counts members of the local Administrators group
(count only, no names) and warns above a threshold.
