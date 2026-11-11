"""Tests for scripts/Test-PolicyFiles.ps1. Skipped when PowerShell 7 is unavailable."""
import pytest

from conftest import FIXTURES, POLICIES, SCRIPTS, run_pwsh

LINTER = str(SCRIPTS / "Test-PolicyFiles.ps1")

# fixture folder -> error code the linter must report
BAD_FIXTURES = {
    "invalid-json": "INVALID_JSON",
    "missing-description": "MISSING_KEY",
    "bad-name": "BAD_NAME",
    "name-file-mismatch": "NAME_FILE_MISMATCH",
    "contains-guid": "GUID_FOUND",
    "contains-secret": "SECRET_PATTERN",
    "tenant-domain": "TENANT_DOMAIN",
    "email-address": "EMAIL_FOUND",
    "read-only-key": "FORBIDDEN_KEY",
    "not-in-manifest": "NOT_IN_MANIFEST",
    "manifest-type-mismatch": "MANIFEST_TYPE_MISMATCH",
    "manifest-bad-graph-version": "MANIFEST_GRAPH_VERSION",
    "manifest-wrong-collection": "MANIFEST_COLLECTION",
    "manifest-missing-file": "MANIFEST_FILE_MISSING",
    "no-block-action": "BLOCK_ACTION_COUNT",
    "two-block-actions": "BLOCK_ACTION_COUNT",
    "duplicate-name": "DUPLICATE_NAME",
    "top-level-array": "NOT_OBJECT",
}


def test_every_bad_fixture_is_covered():
    on_disk = {p.name for p in (FIXTURES).iterdir() if p.is_dir()} - {"good"}
    assert on_disk == set(BAD_FIXTURES), "add new fixtures to BAD_FIXTURES"


def test_linter_accepts_the_real_policies(pwsh):
    result = run_pwsh(["-File", LINTER, "-PolicyPath", str(POLICIES)])
    assert result.returncode == 0, result.stdout + result.stderr
    assert "0 error(s)" in result.stdout


def test_linter_accepts_the_good_fixture(pwsh):
    result = run_pwsh(["-File", LINTER, "-PolicyPath", str(FIXTURES / "good")])
    assert result.returncode == 0, result.stdout + result.stderr


@pytest.mark.parametrize("case,code", sorted(BAD_FIXTURES.items()))
def test_linter_rejects_bad_fixture(pwsh, case, code):
    result = run_pwsh(["-File", LINTER, "-PolicyPath", str(FIXTURES / case)])
    assert result.returncode == 1, f"{case} should fail:\n{result.stdout}"
    assert code in result.stdout, f"{case}: expected {code} in\n{result.stdout}"


def test_linter_reports_missing_folder(pwsh):
    result = run_pwsh(["-File", LINTER, "-PolicyPath", str(FIXTURES / "does-not-exist")])
    assert result.returncode == 2
