# Rollout plan: pilot ring to broad

A phased plan for introducing the baseline without surprising users or locking people out. Durations
below are suggested starting points. Adjust them to your organisation. Nothing in this plan comes from
measured data.

## Principles

- **Pilot tenant first.** Rehearse the whole thing, including rollback, in a non-production tenant or a clearly separated pilot group.
- **Report before enforce.** Compliance policies and Conditional Access run in reporting mode (or with long grace periods) before they block anyone.
- **Small groups, then wider.** Each ring is larger than the last and has a go or no-go decision between them.
- **Nothing is assigned by script.** `scripts/Import-IntunePolicies.ps1` creates policies and never assigns them. A person assigns each one.
- **Keep a way back.** Every step has a defined rollback.

## Rings

| Ring | Who | Purpose | Suggested duration |
|---|---|---|---|
| Ring 0: Pilot | IT staff and a few willing volunteers, mixed hardware, both platforms | Prove enrolment, policy application and rollback | 1 to 2 weeks |
| Ring 1: Early | A cross-section of departments, including heavy and light users | Find application and workflow problems | 2 weeks |
| Ring 2: Broad | Everyone else | Full rollout | Staged by department or site |

The same ring names are used by the Windows update rings (`EB-WIN-UPD-Ring0-Pilot`, `EB-WIN-UPD-Ring1-Early`, `EB-WIN-UPD-Ring2-Broad`), so one device group per ring can drive both device rollout and patching.

## Stages

### Stage 0: Preparation

1. Agree the standard ([standard.md](standard.md)) and the exceptions process. Decide the corporate and personal device approach.
2. Stand up the pilot tenant or pilot groups. Create one device group per ring.
3. Run the offline checks: `python -m pytest tests` and `pwsh scripts/Test-PolicyFiles.ps1`.
4. Dry-run the import: `./scripts/Import-IntunePolicies.ps1 -NamePrefix 'PILOT-'`. Read the plan.
5. Set "mark devices with no compliance policy as" to Not compliant only after the policies are assigned to everyone who needs them. Until then leave it as it is.
6. Prepare communications (see below) and brief the service desk.

Exit criteria: owner named, groups ready, dry run reviewed, service desk briefed, rollback tested on paper.

### Stage 1: Ring 0 (pilot)

1. Apply with `-Apply` and a `PILOT-` prefix. Assign compliance and configuration policies to Ring 0 devices.
2. Keep Conditional Access in report-only mode.
3. Enrol or re-enrol at least one device of every hardware model you support. Run the readiness scripts on each.
4. Deliberately break something on a test device (turn the firewall off) and watch the compliance state change.
5. Practise the rollback (below).

Exit criteria: every pilot device reaches compliant or has a recorded, understood reason it does not. Recovery keys are present for every encrypted device. No unresolved blocking issue. Service desk has handled at least one simulated ticket from the troubleshooting guide.

### Stage 2: Ring 1 (early)

1. Assign the same policies to Ring 1.
2. Send the pre-notification (below) a week ahead.
3. Review sign-in logs for the Conditional Access report-only policy. Decide whether any application needs an exclusion or a fix.
4. Switch the Conditional Access policy from report-only to on for Ring 1 users only, if your design allows scoping by group.

Exit criteria: the number of open tickets caused by the baseline is falling, not rising. No data-loss or lock-out incident. Compliance rate stabilised and the remaining non-compliant devices are explained.

### Stage 3: Ring 2 (broad)

1. Roll out department by department or site by site, not all at once.
2. Between waves, review the same exit criteria.
3. After the last wave, remove the `PILOT-` prefix by re-running the import without it, moving assignments, and deleting the pilot copies. Names are matched exactly, so this creates new policies, and the old ones stay until you delete them.
4. Switch "mark devices with no compliance policy as" to Not compliant, and enforce Conditional Access for everyone with the documented exceptions.

### Stage 4: Steady state

- Monthly: confirm update ring behaviour, review non-compliant devices, review exceptions.
- At each feature release of Windows or macOS: update the minimum OS values and the feature update policy, rehearsed through the rings.
- Annually: review the standard ([standard.md](standard.md)), the Graph versions used, and the NCSC requirements.

## Communications

Send in plain language, from a named person, and tell people what to do and where to get help.

| When | Audience | Message |
|---|---|---|
| One week before | Ring users | What is changing and why (protecting laptops and company data). What they might notice: restarts for updates, a prompt to encrypt or sign in again. The date. Who to contact. |
| On the day | Ring users and the service desk | The change is live. Link to a short how-to. Known issues and workarounds. |
| One week after | Ring users | Thank them. What was fixed. What is next. |
| Before each later ring | Next ring | Same as the first message, adjusted for what was learned. |

A short template:

> Subject: Laptop security update from IT, starting {date}
>
> From {date} we are applying a standard set of security settings to company laptops: disk encryption, a firewall, antivirus, automatic updates and a screen lock. You may be asked to restart your laptop more than usual during the first few weeks, and to sign in again once. Nothing is installed that reads your personal files. If your laptop stops working as expected, contact the service desk on {contact} and mention "laptop baseline".

Adapt it to match what your policies actually do. Do not promise things about monitoring or privacy that you have not checked.

## Rollback

| What went wrong | Rollback |
|---|---|
| A configuration policy causes a problem | Remove the assignment of that policy from the ring group. Devices stop receiving it at their next check-in. Policy settings applied to a device generally revert when the policy is removed, but some settings persist (encryption, for example), so test. |
| Compliance policy marks too many devices non-compliant | Increase the grace period, or remove the assignment. If Conditional Access is blocking people, set it to report-only or exclude the affected group, then fix the root cause. |
| Conditional Access locks users out | Use an emergency access account to disable the policy. This is why those accounts exist. Then set it to report-only. |
| A Windows quality update causes problems | Pause the affected ring from the update ring settings, or uninstall the update through Intune's quality update rollback options where available, and hold later rings. Feature update rollback is possible only inside the rollback window (see Microsoft's documentation). |
| A bad policy was created by the script | The script never deletes. Delete the policy in the admin centre. Policies it created carry your chosen prefix so they are easy to find. |
| Encryption problem | Do not decrypt as a rollback. Confirm recovery keys are escrowed, then fix the underlying cause. |

## Roles

| Role | Responsibility |
|---|---|
| Owner | Accountable for the rollout and for go or no-go between rings |
| Endpoint engineer | Builds policies, runs the scripts, monitors reports |
| Service desk lead | Prepares the desk, tracks tickets by cause |
| Security or compliance lead | Owns the standard and the exceptions process |
| Communications | Sends the notices |

In a small organisation one person may hold several of these roles. Even so, write down who is making the go or no-go decision.
