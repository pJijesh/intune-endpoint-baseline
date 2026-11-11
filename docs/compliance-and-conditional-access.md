# Compliance and Conditional Access

A compliance policy on its own only reports. Conditional Access is what turns "this device is not
compliant" into "this device cannot reach the data". This page explains how the two connect.

## 1. The flow

1. A compliance policy (for example `EB-WIN-CMP-Baseline`) is assigned to a group of devices or users.
2. The device checks in to Intune on a schedule. Microsoft documents the refresh cycle and it differs by platform and by situation (just enrolled, policy changed, steady state), so check the current figures in Microsoft's documentation rather than relying on a number from this repository.
3. Intune evaluates every rule and sets the device's compliance state: compliant, in grace period, or not compliant.
4. Intune writes that state to the device object in Microsoft Entra ID.
5. When a user signs in to a cloud app, Conditional Access evaluates its policies. A policy with the grant control **Require device to be marked as compliant** reads the state from step 4.
6. Compliant (or in grace period): access granted. Not compliant: access blocked, with a message telling the user how to fix it.

Two facts follow from this and cause most surprises:

- The decision is made at sign-in and token refresh, not instantly. After a device is fixed there is a delay before access returns.
- The device must present its identity. On Windows that happens when it is Microsoft Entra joined or registered. On macOS it needs Company Portal and the Microsoft Enterprise SSO plug-in (or Platform SSO), and in some browsers an extension. Without that, a compliant Mac can still be blocked.

## 2. Compliance policy settings that matter for this flow

| Setting | Where | Recommendation | Reason |
|---|---|---|---|
| Mark devices with no compliance policy assigned as | Intune > Devices > Compliance > Compliance policy settings | Not compliant | The default is Compliant. A device that missed its policy assignment would otherwise pass. |
| Grace period (`gracePeriodHours`) on the `block` action | `scheduledActionsForRule` in each compliance file | 24 hours in the baseline | Gives a user or an automatic fix time to act. Devices in grace period count as compliant for Conditional Access. Use 0 for rules where no grace is acceptable. |
| Notification action | Intune message template | Add one, to the user, before the block action | Avoids the first sign of a problem being a blocked sign-in. The baseline files omit it because it needs a message template ID that is specific to a tenant. |
| One block action | Compliance policy | Exactly one | Intune requires one and only one block scheduled action per policy. The linter checks this. |

## 3. A Conditional Access policy to pair with the baseline

This repository does not ship a Conditional Access JSON file, because a usable one needs tenant-specific
group IDs. The design is described here.

**Name (example):** `EB-CA-RequireCompliantDevice`

| Element | Setting |
|---|---|
| Users | All users, excluding emergency access accounts and a documented exception group |
| Target resources | Office 365 and other business-critical cloud apps. Be careful with "All cloud apps" (see the warnings below) |
| Conditions: device platforms | Windows and macOS |
| Grant | Require device to be marked as compliant |
| Session | Defaults |
| State | **Report-only** first |

Warnings:

- **Emergency access accounts.** Exclude at least two break-glass accounts that are protected separately and monitored. A Conditional Access mistake without them can lock the whole tenant out.
- **Enrolment.** If the policy targets all cloud apps, a new device may be unable to enrol because it is not yet compliant. Exclude the Microsoft Intune Enrollment cloud app, or limit the policy to named apps. Test enrolling a fresh device before switching the policy on.
- **Report-only.** Run in report-only mode and read the sign-in log results for the affected users for at least one full patch cycle before enforcing.
- **Multi-factor authentication.** Requiring a compliant device does not replace MFA. Keep MFA for cloud services as a separate policy. The NCSC requirements ask for MFA on cloud services.

## 4. Personal devices and Conditional Access

If you allow personal devices, scope Conditional Access to the controls you can realistically apply: browser-only access with session controls, or a managed virtual desktop. Do not demand a compliant-device grant of an unmanaged personal device. See section 3 of [standard.md](standard.md).

## 5. Testing checklist

1. A compliant pilot device signs in successfully.
2. Turn off a monitored control on a test device (for example, disable the firewall). Confirm the device moves to in grace period, then non-compliant after the grace period, and that access is blocked.
3. Fix the control. Confirm the device returns to compliant and that access returns after the next check-in and token refresh.
4. A brand new device can complete enrolment.
5. Break-glass accounts can still sign in.

## 6. Monitoring

Watch the compliance reports in Intune, the sign-in logs for Conditional Access results, and the count of devices stuck in grace period. A growing in-grace-period count usually points to a policy that is too strict or a rollout that is ahead of the fix. See [troubleshooting.md](troubleshooting.md).
