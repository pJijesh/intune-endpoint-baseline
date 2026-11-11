# EB-MAC-UPD-SoftwareUpdates (specification)

Target: macOS, corporate-owned, enrolled through automated device enrolment.
Intune location: Devices > macOS > Manage updates (Apple updates). Intune offers more than one
mechanism for macOS updates, including declarative device management based software update
settings and older MDM update policies. Labels and availability depend on your Intune release
and the macOS versions in your estate, so check the current Microsoft documentation before choosing.

## Why this is a specification and not JSON

There is no stable `deviceConfiguration` resource for macOS software update enforcement that this
repository could verify. The mechanisms are settings catalog and declarative based.

## Intent

| Requirement | Recommended configuration |
|---|---|
| Security updates installed within 14 days of release | Enforce updates with a deadline. A deadline of 7 days after release leaves a margin for devices that were off or travelling. |
| Users cannot ignore updates indefinitely | Limit deferrals and show notifications ahead of forced install. |
| Major upgrades are controlled | Do not auto-upgrade to a new major version until your applications are validated. Do set a date after which the oldest major version in the estate is no longer permitted. |
| Updates are staged | Pilot group first, then broad, matching the rollout plan. |

## Minimum version

The compliance policy `EB-MAC-CMP-Baseline` sets `osMinimumVersion`. The value in the file is an example.
Set it to the oldest macOS major version that is still receiving security updates from Apple.
Apple does not publish a formal support schedule, so confirm against Apple's security release notes.

## Verification

`scripts/macos-readiness-check.sh --check-updates` lists pending updates (it queries Apple and does
not install anything). The Intune device report shows the OS version.
