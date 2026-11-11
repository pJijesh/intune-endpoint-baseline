# Policy specifications (settings catalog and other non-JSON settings)

Some baseline settings live in Intune's settings catalog or in endpoint security profiles, whose
Graph representation uses generated setting definition IDs and nested instance structures. Those
cannot be hand-written reliably from documentation alone, so this repository does not ship JSON for
them. Writing it by guesswork would produce files that look authoritative and then fail, or worse,
configure something different from what was intended.

Instead each specification below states the intent, the setting names as they appear in the Intune
admin centre, the recommended value, and the reason. To turn a specification into a policy:

1. Create the profile in the Intune admin centre in a pilot tenant.
2. Optionally export it with Graph (`GET /deviceManagement/configurationPolicies/{id}?$expand=settings`)
   and review the exported JSON before storing it in your own repository.
3. Name it with the convention used here, `EB-<WIN|MAC>-<CMP|CFG|UPD>-<Name>`.

Caveats that apply to every file in this folder:

- Menu paths and setting labels are given as they were understood at the time of writing. Microsoft
  renames and moves things regularly. Treat the setting name as the thing to search for.
- Values are recommendations, not Intune defaults. Where a value is an organisational choice
  (for example a PIN length above the minimum) the file says so.
- Nothing here has been applied to a live tenant by the author of this repository.

| Specification | Covers |
|---|---|
| [windows-disk-encryption.md](windows-disk-encryption.md) | Silent BitLocker enablement and recovery key escrow |
| [windows-feature-updates.md](windows-feature-updates.md) | Feature update policy that complements the quality update rings |
| [windows-accounts-and-signin.md](windows-accounts-and-signin.md) | Standard user, local administrator password management, Windows Hello for Business |
| [windows-attack-surface-reduction.md](windows-attack-surface-reduction.md) | Fifteen attack surface reduction rules with an audit-first rollout, and network protection |
| [windows-administrator-protection.md](windows-administrator-protection.md) | User Account Control and Administrator protection settings |
| [macos-software-updates.md](macos-software-updates.md) | Enforcing macOS updates and a patching deadline |
| [macos-screen-lock-and-accounts.md](macos-screen-lock-and-accounts.md) | Screen lock, login window and admin account handling |
