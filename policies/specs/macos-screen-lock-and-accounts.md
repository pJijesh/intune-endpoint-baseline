# EB-MAC-CFG-ScreenLockAndAccounts (specification)

Target: macOS, corporate-owned, enrolled through automated device enrolment.

## Why this is a specification and not JSON

Screen saver, login window and password policy payloads are delivered through the settings catalog or
custom profiles, not through a `deviceConfiguration` resource this repository can verify. Verify the
exact payload keys against Apple's Device Management documentation for the macOS versions you run, since
Apple has changed which keys are honoured between releases.

## Screen lock

| Requirement | Recommended value | Reason |
|---|---|---|
| Idle time before screen saver or display sleep | 5 minutes or less | Limits exposure when a user walks away. |
| Password required after sleep or screen saver | Yes, with a delay of 5 seconds or less | A long grace delay defeats the lock. |
| Compliance check | `passwordMinutesOfInactivityBeforeLock` in `EB-MAC-CMP-Baseline` is 15 | 15 minutes is a compliance ceiling that is looser than the 5 minutes configured above, so ordinary drift is not reported as non-compliance. Tighten it once you have data. |

## Login window and accounts

| Requirement | Recommended value | Reason |
|---|---|---|
| Show user list at login window | Disabled (name and password fields) | Avoids disclosing account names on a lost device. |
| Guest account | Disabled | No anonymous access. |
| Primary account type | Standard | Standard users are the baseline. |
| Admin account | Created by the automated device enrolment profile (Account settings step) as a separate managed admin account, if IT needs one | Keeps day to day work off an admin account. Check current Intune documentation for password rotation support for this account. |
| FileVault | Enabled through `EB-MAC-CFG-EndpointProtection-Baseline` | See the standard. |

## Verification

`scripts/macos-readiness-check.sh` reports screen lock status for the user running it, FileVault,
firewall, Gatekeeper, SIP, enrolment state, and whether that user is a local admin.
