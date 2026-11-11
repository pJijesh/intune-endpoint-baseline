# Enrolment guide

How corporate devices get into Intune and receive the baseline. Windows uses Windows Autopilot. macOS uses
automated device enrolment (ADE) through Apple Business Manager (ABM).

Menu names in the Intune admin centre and in ABM change over time. Where this guide names a screen,
use it as a search term rather than a fixed path. Do the first run in a pilot tenant or with a small
pilot group, and keep the baseline policies unassigned until the enrolment path itself works.

For where this sits in the device lifecycle, see [device-lifecycle.md](device-lifecycle.md).

## Part A. Windows 11 with Autopilot

### Prerequisites

- Intune licences for every user, and Microsoft Entra ID licences that include automatic MDM enrolment.
- In Entra ID, MDM user scope set to include the pilot users (Devices > Mobility (MDM and MAM) > Microsoft Intune).
- Devices run Windows 11 and have a TPM 2.0 and UEFI with Secure Boot.
- A supplier or OEM that can register devices in Autopilot, or a process for collecting hardware hashes yourself.
- A named owner for the process, and a pilot group of devices and users.

### Steps

1. **Decide the deployment mode.** User-driven Microsoft Entra join is the normal choice for corporate laptops. Microsoft also offers Windows Autopilot device preparation as a newer alternative to classic deployment profiles. Choose one and record why. The steps below describe the classic profile route.
2. **Register the devices.** Ask the supplier to register devices into your tenant on purchase, or import hardware hash CSV files (Devices > Windows > Enrollment > Devices). Give pilot devices a group tag such as `Pilot` so they can be targeted.
3. **Create a device group.** A dynamic device group can select devices by group tag, for example with a rule on `device.devicePhysicalIds` containing the `[OrderID]` tag. Keep one group per ring (pilot, early, broad).
4. **Create the deployment profile.**
   - Deployment mode: user-driven.
   - Join type: Microsoft Entra joined.
   - User account type: Standard (see requirement R09 in [standard.md](standard.md)).
   - Hide licence terms and privacy settings pages as your policy allows.
   - Apply a device name template that carries no personal data.
5. **Create the Enrollment Status Page profile.** Block device use until required apps and policies are installed, with a sensible timeout. The baseline policies should be assigned before the ESP runs so a device is compliant on first use.
6. **Assign.** Assign the deployment profile and the ESP profile to the group for the ring you are rolling out.
7. **Assign the baseline policies to the pilot group.** Import with the script (dry run first), then assign in the admin centre:

   ```powershell
   ./scripts/Import-IntunePolicies.ps1 -NamePrefix 'PILOT-'          # dry run, changes nothing
   ./scripts/Import-IntunePolicies.ps1 -NamePrefix 'PILOT-' -Apply   # creates or updates
   ```

   The script never assigns policies. Assignment is a deliberate human step.
8. **Provision a pilot device.** Wipe or unbox, connect to the network, sign in with a pilot user. Watch the ESP complete.
9. **Verify.** On the device run `scripts/Test-WindowsReadiness.ps1` in an elevated session. In the admin centre confirm the device shows as compliant and that its BitLocker recovery key is present.
10. **Record the result** and move on to the next ring only when the exit criteria in [rollout-plan.md](rollout-plan.md) are met.

### Day-two operations

- Autopilot Reset returns a device to a business-ready state for reassignment. A full wipe plus re-enrolment is the alternative when you do not trust the device.
- Retire or delete records for devices that leave the organisation (see lifecycle).

## Part B. macOS with automated device enrolment

### Prerequisites

- An Apple Business Manager account for the organisation, with devices purchased through Apple or an authorised reseller and added to ABM.
- An Apple MDM push certificate configured in Intune (Devices > macOS > Enrollment). Renew it every year before it expires, using the same Apple Account that created it. An expired certificate stops management.
- Intune licences for every user.
- Company Portal for macOS and the Microsoft Enterprise SSO plug-in or equivalent single sign-on configuration, so that Conditional Access can see the device identity in the browser.

### Steps

1. **Connect ABM and Intune.** In Intune, add an Apple ABM token (Devices > macOS > Enrollment > Apple Business Manager). Download the public key from Intune, add a new MDM server in ABM, upload the key, download the server token from ABM, and upload that token to Intune.
2. **Assign devices to the MDM server** in ABM (default for new purchases, or per device).
3. **Create an enrolment profile** (Devices > macOS > Enrollment > Enrollment profiles):
   - User affinity: enrol with user affinity so that compliance and Conditional Access apply to a person.
   - Authentication method appropriate to your setup, with Setup Assistant.
   - Await final configuration, so the user cannot reach the desktop before policies land.
   - Locked enrolment, so the MDM profile cannot be removed by the user.
   - Account settings: make the primary account a standard user. Create a separate managed admin account only if IT needs one (requirement R09).
   - Skip Setup Assistant screens that are not needed.
4. **Assign the profile** to the pilot devices.
5. **Prepare apps and policies.** Deploy Company Portal, and any antivirus or other required apps. Create the baseline policies with the import script (dry run first). Assign them to the pilot group.
6. **Provision a pilot Mac.** Erase it (or use a new one), connect to the network, and walk through Setup Assistant as a pilot user. FileVault should prompt or enable as configured.
7. **Verify.** Run `scripts/macos-readiness-check.sh` as the user. In the admin centre confirm the device is compliant and that a FileVault recovery key is escrowed.
8. **Record the result** and proceed per the rollout plan.

### Day-two operations

- To reassign a Mac, erase it and re-enrol. Do not simply hand it on.
- If a Mac is not receiving policy, see [troubleshooting.md](troubleshooting.md).

## Part C. Personally-owned devices

Decide your approach before rollout. The options are: no personal desktops (access only through managed devices or a virtual desktop), browser-only access with Conditional Access session controls, or Company Portal enrolment with the same compliance policy. See section 3 of [standard.md](standard.md). Never wipe a personal device. Remove organisational data only.
