# Alignment with Microsoft's security baselines

This page compares the repository's Windows settings with the baselines Microsoft publishes in the Security Compliance Toolkit. It shows where this repository agrees, where it goes further, and what the baselines add that this repository now covers in a specification.

## What was compared

Reviewed in November 2026:

- Windows 11 v26H2 security baseline, package v2
- Windows 11 v25H2 security baseline
- Microsoft Edge v151 security baseline
- Microsoft 365 Apps for Enterprise 2512 baseline

The comparison is a reading of the baselines' settings spreadsheets and release notes. No Microsoft files are copied into this repository, and none of the baseline packages' scripts were run. To check any row yourself, download the toolkit from Microsoft and open the spreadsheet for your Windows version.

Microsoft's baselines are written for domain-joined devices managed by Group Policy. This repository targets Intune. Settings that exist only as Group Policy objects or security templates need the settings catalog, or a custom profile, to apply through Intune. That is why most additions here are specifications and not JSON.

## Where this repository already agrees

| Area | Microsoft baseline (v26H2) | This repository |
|---|---|---|
| Real-time protection | Monitor file and program activity: Enabled. Turn off real-time protection: Disabled | `defenderRequireRealTimeMonitoring` true |
| Behaviour monitoring and scanning downloads | Scan all downloaded files and attachments: Enabled | `defenderRequireBehaviorMonitoring` and `defenderScanDownloads` true |
| Cloud protection level | High blocking level | `defenderCloudBlockLevel` is `high` |
| Network inspection | Convert warn verdict to block: Enabled | `defenderRequireNetworkInspectionSystem` true |
| SmartScreen warnings | Prevent bypassing SmartScreen warnings: Enabled | `smartScreenBlockOverrideForFiles` true, SmartScreen in shell on |

## What the baselines add, now covered here

| Area | Baseline setting | Where it is covered |
|---|---|---|
| Attack surface reduction | 15 rules enabled, 14 in Block mode and one (PSExec and WMI) in Audit | [windows-attack-surface-reduction.md](../policies/specs/windows-attack-surface-reduction.md), with an audit-first rollout |
| Network protection | Prevent users and apps from accessing dangerous websites: Enabled | Same specification |
| Administrator protection and UAC | Admin Approval Mode with Administrator protection, credential prompt on the secure desktop, standard users automatically denied elevation | [windows-administrator-protection.md](../policies/specs/windows-administrator-protection.md) |

## Differences worth knowing about

- **Rollout order.** Microsoft's baseline sets 14 ASR rules to Block directly. This repository recommends Audit first for every rule, because the false positives are specific to each organisation.
- **Group Policy only settings.** The baselines contain many settings with no direct Intune equivalent, for example some security template items. They are out of scope here.
- **Account lockout and password length.** The v26H2 baseline uses an account lockout threshold of 10 invalid attempts, a 10 minute lockout duration and reset counter, and a minimum password length of 14 characters. These apply to local accounts and sit alongside the guidance in R08 of [the standard](standard.md), which prefers Windows Hello for Business. Check your own policy against them if you still allow password sign-in.
- **Edge and Microsoft 365 Apps.** Their baselines are separate documents with their own settings. This repository does not yet include Edge or Office policies, which is the sensible next addition.
- **Versions move.** Microsoft publishes a new package for each Windows release and updates it between releases. Re-run this comparison when you move to a new Windows version.

## How to keep this current

1. Download the toolkit for your Windows version from Microsoft.
2. Compare its spreadsheet with the tables above.
3. Update the specification files and the standard together.
4. Re-run the repository tests (`python -m pytest tests`).

## Verification status

- The ASR rule IDs and modes, the Network protection and Administrator protection settings, and the lockout and password length values were read directly from the v26H2 package v2 spreadsheet.
- Release note statements are paraphrased.
- Nothing here has been applied to a live tenant.
