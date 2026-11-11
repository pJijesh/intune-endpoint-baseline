# Endpoint security standard: Windows 11 and macOS

Version 1.0 draft. Plain-English standard for laptops and desktops managed with Microsoft Intune.

## 1. Purpose and scope

This standard says what a managed Windows 11 or macOS device must look like before it is trusted
to reach organisational data, why each requirement exists, and how Intune enforces and checks it.

It covers Windows 11 and macOS. Phones and tablets, servers and Linux are out of scope.

This is a synthetic, generic baseline written for demonstration and reuse. It is not tied to any
real organisation, and every value is a starting point to be reviewed against your own risk assessment.

**What this standard is not.** Following it does not guarantee Cyber Essentials certification or
compliance with any other scheme. Certification is decided by a certification body assessing your
whole in-scope environment against the NCSC requirements. This document maps requirements to
Cyber Essentials themes to help you see where they relate, nothing more. Always check the current
NCSC "Requirements for IT infrastructure" document (version 3.3, April 2026, at the time of writing).

## 2. How to read each requirement

Each requirement has the same parts:

- **Requirement**: what must be true.
- **Why**: the risk it reduces.
- **Enforced by**: the policy file or specification in this repository, and the Intune mechanism.
- **Checked by**: how you can see the result.
- **Maps to**: the Cyber Essentials technical control theme, and a CIS-style category.

On the CIS-style category: the Center for Internet Security publishes its own benchmarks for Windows
and macOS under its own licence. This standard names the general category of control a benchmark would
cover (for example "host firewall" or "update management") so you can find the related section in a
benchmark you have licensed. It does not reproduce benchmark text, numbering or values, and it does not
claim to meet any benchmark profile.

## 3. Device ownership

| | Corporate-owned | Personally-owned (BYOD) |
|---|---|---|
| Enrolment | Full enrolment: Windows Autopilot, or macOS automated device enrolment through Apple Business Manager | Not enrolled for full management by default |
| Policies applied | Everything in this standard | Only what the organisation can enforce without taking control of a personal device |
| Access to organisational data | Allowed when compliant | Limited to browser-based access to approved services, or to a managed virtual desktop, with Conditional Access session controls |
| Wipe | Full device wipe permitted | Never a full wipe. Remove organisational data only |
| Cyber Essentials scope | In scope | In scope if the device can reach organisational data or services, according to the NCSC requirements |

If a personal device is allowed to enrol, it must meet the same compliance policy as a corporate one for
the controls that policy can measure, and the user must be told in plain language what the organisation
can and cannot see. Decide which path your organisation takes before rollout, and write it down.

## 4. Requirements

### R01 Managed and enrolled

**Requirement.** Every corporate device is enrolled in Intune through an automated path (Autopilot or
automated device enrolment), is owned by the organisation in the records, and has a named primary user.

**Why.** Unmanaged devices cannot be inspected, patched or wiped. Automated enrolment means devices are
configured before the first user touches them, and stops users setting up corporate devices as personal ones.

**Enforced by.** Autopilot deployment profile (Windows), automated device enrolment profile with locked
enrolment (macOS). See [enrolment-guide.md](enrolment-guide.md). Conditional Access treats devices with no
compliance policy as not compliant. See [compliance-and-conditional-access.md](compliance-and-conditional-access.md).

**Checked by.** Intune device inventory. `scripts/Test-WindowsReadiness.ps1` and `scripts/macos-readiness-check.sh` report enrolment state.

**Maps to.** Secure configuration. CIS-style category: asset inventory and device management.

### R02 Disk encryption

**Requirement.** The system drive is encrypted: BitLocker on Windows, FileVault on macOS. Recovery keys are escrowed and retrievable by authorised IT staff.

**Why.** A lost or stolen laptop is a common incident. Encryption turns it from a data breach into a hardware loss.

**Enforced by.**
- Windows: `EB-WIN-CMP-Baseline` requires `bitLockerEnabled` and `storageRequireEncryption`. `EB-WIN-CFG-EndpointProtection-Baseline` requires device encryption. Silent enablement and key escrow: [windows-disk-encryption.md](../policies/specs/windows-disk-encryption.md).
- macOS: `EB-MAC-CFG-EndpointProtection-Baseline` enables FileVault with a personal recovery key escrowed to Intune. `EB-MAC-CMP-Baseline` requires `storageRequireEncryption`.

**Checked by.** Compliance state in Intune. Readiness scripts report BitLocker protection status and FileVault status.

**Maps to.** Secure configuration, loosely. Device encryption was not a named requirement in the summary of the NCSC text used while writing this repository, so treat it as good practice and check the current text. CIS-style category: data protection and encryption.

### R03 Host firewall

**Requirement.** The operating system firewall is on for every network profile, with inbound connections blocked by default. On macOS, stealth mode is on.

**Why.** Laptops leave the office network. A host firewall is the only firewall between the device and a hotel or cafe network.

**Enforced by.**
- Windows: `EB-WIN-CFG-EndpointProtection-Baseline` (domain, private and public profiles on, inbound blocked). `EB-WIN-CMP-Baseline` requires `activeFirewallRequired`.
- macOS: `EB-MAC-CFG-EndpointProtection-Baseline` and `EB-MAC-CMP-Baseline` (firewall and stealth mode).

**Checked by.** Compliance state; readiness scripts report each Windows profile and the macOS firewall and stealth mode state.

**Maps to.** Firewalls. CIS-style category: host firewall configuration.

### R04 Malware protection

**Requirement.** Anti-malware is on, in real-time mode, with current signatures. On Windows this is Microsoft Defender Antivirus, or another product that registers with Windows Security Centre. On macOS the minimum is Gatekeeper restricted to the App Store and identified developers, with user override disabled, plus the built-in protections. Microsoft Defender for Endpoint is an optional addition.

**Why.** Prevents the commonest class of endpoint compromise and gives a second line behind patching.

**Enforced by.**
- Windows: `EB-WIN-CFG-Defender-Baseline` (real-time, behaviour monitoring, network inspection, cloud block level, scan schedule, signature interval). `EB-WIN-CMP-Baseline` requires `defenderEnabled`, `rtpEnabled`, `antivirusRequired`, `antiSpywareRequired` and up-to-date signatures. SmartScreen overrides are blocked in `EB-WIN-CFG-EndpointProtection-Baseline`. Attack surface reduction rules and network protection add a further layer: [windows-attack-surface-reduction.md](../policies/specs/windows-attack-surface-reduction.md).
- macOS: Gatekeeper settings in `EB-MAC-CFG-EndpointProtection-Baseline`.

**Checked by.** Compliance state. The Windows readiness script reports Defender service, real-time protection and signature age.

**Maps to.** Malware protection. The NCSC requirements accept either anti-malware software or application allow listing, and accept a signed-application restriction for the allow-listing route. CIS-style category: antivirus and application control.

### R05 Update rings and deadlines

**Requirement.**
- Security updates rated high or critical, or with a vendor severity of CVSS v3 base score 7 or above, are installed within 14 days of release. The NCSC requirement is 14 days; this standard targets 12 days or fewer so there is margin.
- Windows quality updates move through three rings: Ring 0 (pilot), Ring 1 (early), Ring 2 (broad).
- Users cannot pause updates.

**Why.** Attackers weaponise published vulnerabilities quickly. Rings catch a bad update on a small group before it reaches everyone.

**Enforced by.** Windows update rings:

| Ring | Quality deferral (days) | Deadline (days) | Grace (days) | Worst-case total (days) |
|---|---|---|---|---|
| `EB-WIN-UPD-Ring0-Pilot` | 0 | 2 | 1 | 3 |
| `EB-WIN-UPD-Ring1-Early` | 3 | 2 | 1 | 6 |
| `EB-WIN-UPD-Ring2-Broad` | 7 | 3 | 2 | 12 |

The worst-case total is deferral plus deadline plus grace, for a device that is online when the deadline falls. A device that is switched off or offline will be later, which is what the compliance minimum-version rule catches.
Feature updates: [windows-feature-updates.md](../policies/specs/windows-feature-updates.md). macOS: [macos-software-updates.md](../policies/specs/macos-software-updates.md).

**Checked by.** Intune update reports; OS build against the compliance minimum; the readiness scripts report pending restarts (Windows) and pending updates (macOS, with `--check-updates`).

**Maps to.** Security update management. CIS-style category: update management.

### R06 Supported operating system versions

**Requirement.** Only vendor-supported OS versions are allowed. The compliance policies set a minimum OS version. Unsupported software must be removed, or the device isolated from the internet.

**Why.** Unsupported systems receive no security fixes.

**Enforced by.** `osMinimumVersion` in `EB-WIN-CMP-Baseline` (a Windows 11 build number) and `EB-MAC-CMP-Baseline` (a macOS version). The values in the files are examples. Review them whenever a version leaves support. The process is in the [rollout plan](rollout-plan.md).

**Checked by.** Compliance state.

**Maps to.** Security update management (supported software). CIS-style category: update management.

### R07 Screen lock

**Requirement.** Devices lock after a short period of inactivity and need the user's credential to unlock.

**Why.** Limits exposure when a device is unattended.

**Enforced by.** `passwordRequiredToUnlockFromIdle` and `passwordMinutesOfInactivityBeforeLock` (15 minutes ceiling) in `EB-WIN-CMP-Baseline`; `passwordRequired` and `passwordMinutesOfInactivityBeforeLock` in `EB-MAC-CMP-Baseline`. The configured lock time on macOS is in [macos-screen-lock-and-accounts.md](../policies/specs/macos-screen-lock-and-accounts.md). The compliance ceiling is deliberately looser than the target configuration.

**Checked by.** Compliance state. The macOS readiness script reports the current user's screen lock setting.

**Maps to.** User access control (device locking). CIS-style category: session and lock settings.

### R08 Sign-in credentials

**Requirement.**
- Windows: Windows Hello for Business (biometric or PIN bound to the TPM). Where a password is used, multi-factor authentication is applied, or the password is at least 12 characters, or at least 8 characters with a blocklist of common passwords.
- macOS: a local password of at least 12 characters; simple passwords blocked.
- No forced periodic password expiry. Change a password when compromise is suspected.
- Device unlock credentials must resist guessing: the NCSC requirement is no more than 10 guesses in 5 minutes, or a lockout after no more than 10 failures, and an unlock-only PIN of at least 6 characters.

**Why.** Guessable credentials undermine every other control. Forced expiry produces weaker passwords.

**Enforced by.** [windows-accounts-and-signin.md](../policies/specs/windows-accounts-and-signin.md) for Hello for Business. `passwordMinimumLength` and `passwordBlockSimple` in `EB-MAC-CMP-Baseline`. Multi-factor authentication for cloud services is enforced in Entra Conditional Access, not in this repository; see [compliance-and-conditional-access.md](compliance-and-conditional-access.md).

**Checked by.** Compliance state; Entra sign-in logs for MFA.

**Maps to.** User access control. CIS-style category: account and password policy.

### R09 Local administrator rights

**Requirement.** Daily work is done as a standard user. Administrator rights are separate, granted for a reason, and not used for email or web browsing. Local administrator passwords, where an admin account exists, are unique per device and rotated.

**Why.** Malware running as an admin can disable every other control.

**Enforced by.** Autopilot profile (standard user), Windows LAPS, local group membership policy, and Hello for Business: [windows-accounts-and-signin.md](../policies/specs/windows-accounts-and-signin.md). User Account Control with Administrator protection makes the operating system require a credential for elevation: [windows-administrator-protection.md](../policies/specs/windows-administrator-protection.md). macOS: standard primary account and a separate managed admin account if needed: [macos-screen-lock-and-accounts.md](../policies/specs/macos-screen-lock-and-accounts.md).

**Checked by.** Readiness scripts report the number of local admins (Windows) and whether the current user is an admin (macOS). They never print account names.

**Maps to.** User access control. CIS-style category: user rights and privileged access.

### R10 Platform integrity

**Requirement.** Windows devices have a TPM, Secure Boot on, and code integrity enabled. macOS devices have System Integrity Protection enabled and Gatekeeper on.

**Why.** These features make it far harder for malware to persist below the operating system. A device with them disabled has been tampered with, or is unsupported hardware.

**Enforced by.** `tpmRequired`, `secureBootEnabled`, `codeIntegrityEnabled`, `earlyLaunchAntiMalwareDriverEnabled` in `EB-WIN-CMP-Baseline`. `systemIntegrityProtectionEnabled` in `EB-MAC-CMP-Baseline`. Several of the Windows values rely on Device Health Attestation reports.

**Checked by.** Compliance state; readiness scripts.

**Maps to.** Secure configuration. CIS-style category: boot and platform security.

### R11 Jailbreak and tamper equivalents on desktops

**Requirement.** Devices showing signs of tampering are treated as non-compliant.

**Why.** "Jailbreak detection" is a mobile compliance feature. Windows and macOS have no jailbreak concept, so the equivalent signals are the platform integrity controls in R10: Secure Boot disabled, code integrity disabled, System Integrity Protection disabled, or a security product turned off. Intune's device threat protection setting (an optional connection to a mobile threat defence or Defender for Endpoint service) can add a risk-level signal. It is not set in the baseline files because it needs a connector to be configured first.

**Enforced by.** The R10 compliance rules. Optionally `deviceThreatProtectionEnabled` and `deviceThreatProtectionRequiredSecurityLevel` once a connector exists.

**Maps to.** Secure configuration, malware protection. CIS-style category: boot and platform security.

### R12 Compliance evaluation and consequences

**Requirement.** Compliance is evaluated automatically. A device that fails is given a short grace period, then marked non-compliant, and Conditional Access blocks it from organisational data until it is fixed.

**Why.** A standard that is checked but has no consequence is advice.

**Enforced by.** The `scheduledActionsForRule` block in each compliance file (mark non-compliant after a 24 hour grace period). Conditional Access policy requiring a compliant device. See [compliance-and-conditional-access.md](compliance-and-conditional-access.md).

**Checked by.** Intune compliance reports.

**Maps to.** Secure configuration, user access control. CIS-style category: governance and monitoring.

## 5. Mapping summary

| Requirement | Cyber Essentials theme | CIS-style category (descriptive) |
|---|---|---|
| R01 Managed and enrolled | Secure configuration | Asset inventory and device management |
| R02 Disk encryption | Secure configuration | Data protection and encryption |
| R03 Host firewall | Firewalls | Host firewall configuration |
| R04 Malware protection | Malware protection | Antivirus and application control |
| R05 Update rings and deadlines | Security update management | Update management |
| R06 Supported OS versions | Security update management | Update management |
| R07 Screen lock | User access control | Session and lock settings |
| R08 Sign-in credentials | User access control | Account and password policy |
| R09 Local administrator rights | User access control | User rights and privileged access |
| R10 Platform integrity | Secure configuration | Boot and platform security |
| R11 Tamper equivalents | Secure configuration, malware protection | Boot and platform security |
| R12 Compliance consequences | Secure configuration, user access control | Governance and monitoring |

The five Cyber Essentials technical control themes are Firewalls, Secure Configuration, Security Update Management, User Access Control and Malware Protection. Cyber Essentials also covers things this repository does not: boundary devices, cloud service configuration, user accounts in directories, and so on.

## 6. Exceptions

An exception to any requirement must be recorded with an owner, a reason, compensating controls and an expiry date. Exempt devices belong in a separate Entra group with its own, narrower, compliance policy. Never exclude a device from the baseline informally.

## 7. Review

Review this standard at least annually, and when a Windows or macOS version leaves support, when Microsoft changes a Graph resource used here, and when the NCSC requirements change.

## 8. Sources used while writing this standard

- Microsoft Learn: Microsoft Graph reference pages for windows10CompliancePolicy, macOSCompliancePolicy, windowsUpdateForBusinessConfiguration, windows10EndpointProtectionConfiguration, windows10GeneralConfiguration and macOSEndpointProtectionConfiguration.
- NCSC: Cyber Essentials requirements for IT infrastructure (v3.3, April 2026 at the time of writing). Summarised in the author's words.
- Microsoft Security Compliance Toolkit: Windows 11 v26H2 and v25H2 security baselines, Microsoft Edge v151 and Microsoft 365 Apps 2512 baselines, used for the comparison in [microsoft-baseline-alignment.md](microsoft-baseline-alignment.md). Settings are referenced and paraphrased, not copied.
- Microsoft Learn: attack surface reduction rules reference.
