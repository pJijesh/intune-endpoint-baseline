# Windows User Account Control and Administrator protection

Covers requirement R09 (local administrator rights) in [the standard](../../docs/standard.md).

Intune location: settings catalog, Local Policies Security Options. Search for the setting names below. Name the profile `EB-WIN-CFG-UAC-Baseline`.

## Where these values come from

Microsoft's Windows 11 security baselines for versions 24H2, 25H2 and 26H2 include settings that enable Administrator protection. The 26H2 package v2 release notes say Administrator protection is now generally available and can be enabled through Intune or Group Policy. They also say organisations should review and test the configuration before relying on it.

## Settings

| Setting (as named in the baseline) | Recommended value |
|---|---|
| User Account Control: Configure type of Admin Approval Mode | Admin Approval Mode with Administrator protection |
| User Account Control: Behavior of the elevation prompt for administrators running with Administrator protection | Prompt for credentials on the secure desktop |
| User Account Control: Run all administrators in Admin Approval Mode | Enabled |
| User Account Control: Admin Approval Mode for the Built-in Administrator account | Enabled |
| User Account Control: Behavior of the elevation prompt for administrators in Admin Approval Mode | Prompt for consent on the secure desktop |
| User Account Control: Behavior of the elevation prompt for standard users | Automatically deny elevation requests |

## Why

R09 says daily work is done as a standard user and administrator rights are separate. These settings make the operating system enforce that separation, so a prompt for administrative rights needs a credential and cannot be answered by malware clicking a button.

## Rollout notes

- Pilot first. Installers, developer tools and remote support software are the usual sources of friction.
- Standard users who need to install software will be denied rather than prompted. Tell the service desk before the change, and decide how approved installs are delivered (for example, through the Company Portal or a managed deployment).
- Administrator protection needs a Windows 11 build that supports it. Check the build numbers on your ring 0 devices before assigning the policy to a wider group.
- Keep Windows LAPS in place for local administrator account passwords. The two controls do different jobs.

## Verification status

- Setting names and values were read from the published Microsoft baseline documentation in November 2026.
- The exact menu labels in the settings catalog may differ from the names above. Search for the setting name.
- Not applied to a live tenant.
