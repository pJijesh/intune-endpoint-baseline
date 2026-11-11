# Contributing

Thanks for taking an interest. Issues and pull requests are welcome.

## Ground rules

- **Everything must stay synthetic and generic.** Do not add real tenant names, tenant IDs, group IDs, user names, device names, email addresses, or anything from a real organisation. The linter rejects GUIDs, tenant domains and email addresses in policy files.
- **No secrets.** Never commit tokens, client secrets, certificates or recovery keys.
- **Do not copy benchmark text.** CIS benchmarks and similar documents are published under their own licences. Describe categories in your own words.
- **No guarantees of compliance.** Do not add wording that says using this repository makes anyone certified or compliant.
- **British English**, plain and professional tone, no hype. Do not invent statistics.

## Changing or adding a policy

1. Find the resource on Microsoft Learn (Graph reference) for the version you intend to target, and confirm every property name and enum value. If a setting needs the settings catalog and you cannot reproduce its JSON from documentation, write a specification in `policies/specs/` instead.
2. Add the JSON file under `policies/windows/` or `policies/macos/`. Use a `displayName` of the form `EB-<WIN|MAC>-<CMP|CFG|UPD>-<Name>` and name the file `<displayName>.json`. Include `@odata.type`, `displayName` and `description`. Leave out `id`, `version`, timestamps and assignments.
3. Add an entry to `policies/manifest.json` with the Graph version and collection.
4. Add any newly verified properties to `tests/schemas/known_properties.json`, with enum values and ranges where Learn gives them.
5. Mention the policy in the documentation (the tests check that every policy appears in some markdown file).
6. Run the checks below.

## Running the checks

```bash
pip install pytest
python -m pytest tests                      # needs PowerShell 7 on PATH for the linter and script tests
pwsh ./scripts/Test-PolicyFiles.ps1
```

If `pwsh` is not on your PATH, set `PWSH_PATH` to its location. Tests that need PowerShell are skipped when it is missing.

For PowerShell changes, run PSScriptAnalyzer:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path ./scripts, ./tests -Recurse -Severity Warning, Error
```

For shell changes, run `shellcheck scripts/macos-readiness-check.sh`.

If you change the lifecycle diagram, edit `docs/images/device-lifecycle.mmd`, copy the same text into the
Mermaid block of `docs/device-lifecycle.md`, and regenerate the SVG with Mermaid CLI.

## Scripts

- Import and device check scripts must be safe by default. Anything that writes must be opt-in and must support `-WhatIf` or an equivalent dry run.
- Readiness checks must stay read-only and must not print user names, tenant identifiers or secrets.

## Pull requests

Keep them small and explain what changed and how you tested it. State plainly what you could not test.
