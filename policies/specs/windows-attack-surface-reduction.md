# Windows attack surface reduction rules and network protection

Covers requirement R04 (malware protection) in [the standard](../../docs/standard.md).

Intune location: Endpoint security > Attack surface reduction > Create policy > Windows > Attack surface reduction rules. Network protection is a separate setting in the same area. Search for "network protection" in the settings catalog if the menu has moved.

Name the profiles `EB-WIN-CFG-ASR-Baseline` and `EB-WIN-CFG-NetworkProtection-Baseline`.

## Where these values come from

Microsoft's Windows 11 v26H2 security baseline (Microsoft Security Compliance Toolkit, package v2) turns on 15 attack surface reduction rules. This file lists the same rules by their rule IDs, with rule names from the Microsoft Learn attack surface reduction rules reference. The rule IDs and modes were checked against the baseline's settings spreadsheet. Nothing is copied from the baseline package itself. Download it from Microsoft if you want to compare.

In the baseline, 14 rules are set to Block and one (the PSExec and WMI rule) is set to Audit.

## Rollout rule that matters most

Do not move straight to Block. Set every rule to Audit first, leave it for two to four weeks on the pilot ring, and review the Defender reports for legitimate software that would be stopped. Line-of-business applications, Office macros that finance or operations rely on, and remote administration tools are the usual causes. Switch a rule to Block only when its audit results are clean or the exceptions are agreed and documented.

## Rules

| Rule (Microsoft name) | Rule ID | Baseline v26H2 mode | Typical false positives to look for |
|---|---|---|---|
| Block abuse of exploited vulnerable signed drivers | 56a863a9-875e-4185-98a7-b882c64b5ce5 | Block | Old hardware drivers |
| Block credential stealing from the Windows local security authority subsystem | 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 | Block | Security and backup agents that read process memory |
| Block persistence through WMI event subscription | e6db77e5-3df2-4cf1-b95a-636979351e5b | Block | Management tools that use WMI subscriptions |
| Block Adobe Reader from creating child processes | 7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c | Block | PDF workflows that launch helper programs |
| Block all Office applications from creating child processes | d4f940ab-401b-4efc-aadc-ad5f3c50688a | Block | Macros and add-ins that start other programs |
| Block executable content from email client and webmail | be9ba2d9-53ea-4cdc-84e5-9b1eeee46550 | Block | Staff who receive installers by email |
| Block execution of potentially obfuscated scripts | 5beb7efe-fd9a-4556-801d-275e5ffc04cc | Block | Packaged or minified internal scripts |
| Block JavaScript or VBScript from launching downloaded executable content | d3e037e1-3eb8-44c8-a917-57927947596d | Block | Legacy web-based installers |
| Block Office applications from creating executable content | 3b576869-a4ec-4529-8536-b80a7769e899 | Block | Templates that write executables |
| Block Office applications from injecting code into other processes | 75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84 | Block | Older Office add-ins |
| Block Office communication application from creating child processes | 26190899-1602-49e8-8b27-eb1d0a1ce869 | Block | Outlook rules or add-ins that start programs |
| Block process creations originating from PSExec and WMI commands | d1e49aac-8f56-4280-b9ba-993a6d77406c | Audit | Remote management and deployment tools. Microsoft sets this one to Audit in the baseline, so treat Audit as the intended mode unless you have no such tools |
| Block untrusted and unsigned processes that run from USB | b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4 | Block | Engineers who run unsigned tools from USB drives |
| Use advanced protection against ransomware | c1db55ab-c21a-4637-bb3f-a12568109d35 | Block | Rarely used programs with no reputation data |
| Block Win32 API calls from Office macros | 92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b | Block | Macro-heavy spreadsheets |

## Network protection

| Setting | Recommended | Notes |
|---|---|---|
| Enable network protection (Microsoft's baseline wording: Prevent users and apps from accessing dangerous websites) | Enabled | The baseline spreadsheet lists the policy as Enabled without a visible mode. Test Audit mode on the pilot ring first, then Block. |

This repository's `EB-WIN-CFG-Defender-Baseline` turns on network inspection (`defenderRequireNetworkInspectionSystem`). That is a different Defender feature. Network protection blocks connections to dangerous sites for the whole device, and the baseline recommends it in addition.

## Verification status

- The 15 rule IDs and their modes (1 or 2) were read from the baseline's settings spreadsheet in November 2026.
- The rule names are from my reading of the Microsoft Learn reference and may be reworded there. Match on the ID.
- The mapping of the numbers (1 for Block, 2 for Audit) is the usual Defender convention. Confirm it in your pilot tenant.
- Not applied to a live tenant.
