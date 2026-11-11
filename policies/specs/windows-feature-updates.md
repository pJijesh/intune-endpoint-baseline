# EB-WIN-UPD-FeatureUpdate (specification)

Target: Windows 11, corporate-owned.
Intune location: Devices > Windows > Windows updates > Feature updates (Manage updates).

## Why this is a specification and not JSON

The Graph resource for feature update profiles (`windowsFeatureUpdateProfile`) was only confirmed in
the beta reference at the time of writing, and the exact string format of its `featureUpdateVersion`
value has changed across Windows generations. Guessing it is how a policy ends up deploying the
wrong version, so the settings are described here.

## How it fits with the update rings

| Concern | Controlled by |
|---|---|
| Monthly quality updates, deadlines, grace periods, restart behaviour | The ring files `EB-WIN-UPD-Ring0-Pilot`, `EB-WIN-UPD-Ring1-Early`, `EB-WIN-UPD-Ring2-Broad` |
| Which feature update version devices move to, and when | A feature update policy (this specification) |

The ring files set `featureUpdatesDeferralPeriodInDays` to 0 so that feature update timing is decided by
the feature update policy rather than by two competing mechanisms.

## Settings

| Setting | Recommended value | Reason |
|---|---|---|
| Feature update to deploy | The current Windows 11 release your estate has validated | Pinning a version prevents surprise upgrades and gives a controlled target. |
| Rollout options | Make update available gradually, starting with the pilot group | Matches the pilot, early, broad structure of the rollout plan. |
| First group availability | Pilot ring start date | Pilot first. |
| Final group availability | Several weeks after the first group, ending before the installed version loses vendor support | Check Microsoft's lifecycle page for the real end of support date of the version you run. |
| Days between groups | Chosen to match the rollout plan | Gives time to observe problems. |

## Assignment

Create one feature update policy per ring, or one policy with gradual rollout across ring groups,
whichever your operations team can reason about more easily. Do not leave devices on an unsupported
version: the Cyber Essentials requirements ask for supported software.

## Verification

Check the update status report for the policy, and the device's OS build against the compliance
policy minimum (`osMinimumVersion` in `EB-WIN-CMP-Baseline`). Raise that minimum when you retire a version.
