"""Behavioural tests for the PowerShell scripts. Skipped when PowerShell 7 is unavailable.

The Graph import script is exercised against an in-memory fake of Microsoft Graph
(tests/Invoke-ImportMockTest.ps1). That proves the script's own logic (dry run, create,
idempotency, drift update, paging, duplicates). It does not prove behaviour against a real tenant.
"""
import sys

import pytest

from conftest import REPO, SCRIPTS, run_pwsh


def test_import_script_mock_suite_passes(pwsh):
    result = run_pwsh(["-File", str(REPO / "tests" / "Invoke-ImportMockTest.ps1")])
    assert result.returncode == 0, result.stdout + result.stderr
    assert "All mock import checks passed." in result.stdout
    assert "FAIL" not in result.stdout


def test_import_script_offline_is_a_dry_run(pwsh):
    result = run_pwsh(["-File", str(SCRIPTS / "Import-IntunePolicies.ps1"), "-Offline", "-NamePrefix", "PILOT-"])
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Dry run only" in result.stdout
    assert "PILOT-EB-WIN-CMP-Baseline" in result.stdout
    assert "Created" not in result.stdout


def test_import_script_rejects_unsafe_prefix(pwsh):
    result = run_pwsh(["-File", str(SCRIPTS / "Import-IntunePolicies.ps1"), "-Offline", "-NamePrefix", "x;rm"])
    assert result.returncode != 0


@pytest.mark.skipif(sys.platform == "win32", reason="non-Windows behaviour")
def test_windows_readiness_declines_on_non_windows(pwsh):
    result = run_pwsh(["-File", str(SCRIPTS / "Test-WindowsReadiness.ps1")])
    assert result.returncode == 2
    assert "Windows only" in result.stdout


@pytest.mark.parametrize("script", ["Import-IntunePolicies.ps1", "Test-PolicyFiles.ps1", "Test-WindowsReadiness.ps1"])
def test_scripts_parse_without_errors(pwsh, script):
    cmd = (
        "$e=$null;$t=$null;"
        f"[System.Management.Automation.Language.Parser]::ParseFile('{SCRIPTS / script}',[ref]$t,[ref]$e)|Out-Null;"
        "if($e.Count){$e|%{$_.Message};exit 1}"
    )
    result = run_pwsh(["-Command", cmd])
    assert result.returncode == 0, result.stdout


def test_psscriptanalyzer_clean_if_installed(pwsh):
    probe = run_pwsh(["-Command", "if (Get-Module -ListAvailable PSScriptAnalyzer) { 'yes' } else { 'no' }"])
    if "yes" not in probe.stdout:
        pytest.skip("PSScriptAnalyzer not installed")
    cmd = (
        f"$r = @(Invoke-ScriptAnalyzer -Path '{SCRIPTS}' -Recurse -Severity Warning,Error);"
        f"$r += @(Invoke-ScriptAnalyzer -Path '{REPO / 'tests'}' -Recurse -Severity Warning,Error);"
        "$r | ForEach-Object { \"$($_.Severity) $($_.RuleName) $($_.ScriptName):$($_.Line)\" };"
        "if ($r) { exit 1 }"
    )
    result = run_pwsh(["-Command", cmd])
    assert result.returncode == 0, result.stdout
