# Device lifecycle

The path a corporate device takes from purchase to disposal, and where the baseline policies,
compliance evaluation and Conditional Access fit in.

```mermaid
flowchart TD
    A[Procure device] --> B{Platform}
    B -->|Windows 11| C[Register hardware hash in Autopilot]
    B -->|macOS| D[Assign device to MDM server in Apple Business Manager]
    C --> E[User powers on and signs in<br/>Autopilot and Enrollment Status Page]
    D --> F[Setup Assistant<br/>automated device enrolment]
    E --> G[Enrolled in Intune]
    F --> G
    G --> H[Baseline policies apply<br/>encryption, firewall, antivirus, updates, screen lock]
    H --> I{Compliance evaluation}
    I -->|Compliant| J[Conditional Access grants access]
    I -->|Not compliant| K[Grace period and user notification]
    K --> L{Fixed within grace period?}
    L -->|Yes| I
    L -->|No| M[Marked non-compliant<br/>Conditional Access blocks access]
    M --> N[User or IT remediates]
    N --> I
    J --> O[Normal use]
    O --> P[Monthly quality updates through rings<br/>Ring 0 pilot, Ring 1 early, Ring 2 broad]
    P --> I
    O --> Q{Lifecycle event}
    Q -->|Lost or stolen| R[Lock or wipe, revoke sessions,<br/>rotate credentials]
    Q -->|Reassign| S[Autopilot reset or macOS erase and re-enrol]
    Q -->|End of life| T[Retire or wipe, remove records,<br/>dispose with a disposal record]
    S --> G
    R --> T
```

A rendered copy is at [images/device-lifecycle.svg](images/device-lifecycle.svg). The source is
[images/device-lifecycle.mmd](images/device-lifecycle.mmd). To regenerate it:

```bash
npx @mermaid-js/mermaid-cli -i docs/images/device-lifecycle.mmd -o docs/images/device-lifecycle.svg
```

## Stage notes

| Stage | Detail | Where to read more |
|---|---|---|
| Register | Windows hardware hashes go to Autopilot. Macs are assigned to the Intune MDM server in Apple Business Manager. | [enrolment-guide.md](enrolment-guide.md) |
| Provision | The device is configured before first use. Policies should land during provisioning so the device is compliant on first sign-in. | [enrolment-guide.md](enrolment-guide.md) |
| Evaluate | Compliance rules run on every check-in. A short grace period avoids blocking someone over a transient state. | [compliance-and-conditional-access.md](compliance-and-conditional-access.md) |
| Patch | Quality updates reach devices ring by ring. A failing update is caught by the pilot ring first. | [rollout-plan.md](rollout-plan.md) |
| Lost or stolen | Lock or wipe the device, revoke the user's sessions, reset credentials, and confirm recovery keys are still escrowed. | [troubleshooting.md](troubleshooting.md) |
| Retire | Wipe, remove the Intune, Autopilot or ABM records as appropriate, and keep a disposal record. | [enrolment-guide.md](enrolment-guide.md) |
