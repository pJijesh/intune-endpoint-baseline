"""Tests for scripts/macos-readiness-check.sh using stubbed system commands.

Real macOS is not required: stub executables placed first on PATH imitate the output formats of
fdesetup, spctl, csrutil and friends. The stub output formats are written from knowledge of macOS
tool output and have not been checked on a Mac, so treat these as logic tests, not a certification
that the script is correct on every macOS release.
"""
import json
import os
import shutil
import stat
import subprocess
import sys

import pytest

from conftest import SCRIPTS

SCRIPT = str(SCRIPTS / "macos-readiness-check.sh")
pytestmark = pytest.mark.skipif(sys.platform == "win32", reason="needs bash")


def make_stubs(tmp_path, *, os_version="15.1", filevault="FileVault is On.", firewall="Firewall is enabled. (State = 1)",
               stealth="Firewall stealth mode is on", gatekeeper="assessments enabled",
               sip="System Integrity Protection status: enabled.",
               screenlock="screenLock delay is immediate",
               enrol="Enrolled via DEP: Yes\nMDM enrollment: Yes (User Approved)", groups="staff everyone"):
    bindir = tmp_path / "bin"
    bindir.mkdir(parents=True)

    def stub(name, body):
        p = bindir / name
        p.write_text("#!/bin/sh\n" + body + "\n")
        p.chmod(p.stat().st_mode | stat.S_IEXEC)

    stub("uname", 'echo Darwin')
    stub("sw_vers", f'echo "{os_version}"')
    stub("fdesetup", f'echo "{filevault}"')
    stub("socketfilterfw", f'case "$1" in --getglobalstate) echo "{firewall}";; --getstealthmode) echo "{stealth}";; esac')
    stub("spctl", f'echo "{gatekeeper}"')
    stub("csrutil", f'echo "{sip}"')
    stub("sysadminctl", f'echo "{screenlock}"')
    stub("profiles", f'printf "{enrol}\\n"')
    stub("id", f'echo "{groups}"')
    return bindir


def run(tmp_path, args=(), **kw):
    bindir = make_stubs(tmp_path, **kw)
    env = dict(os.environ)
    env["PATH"] = f"{bindir}{os.pathsep}{env['PATH']}"
    env["SOCKETFILTERFW"] = str(bindir / "socketfilterfw")
    return subprocess.run(["bash", SCRIPT, *args], capture_output=True, text=True, env=env, timeout=60)


def test_script_is_syntactically_valid_bash():
    assert subprocess.run(["bash", "-n", SCRIPT]).returncode == 0


@pytest.mark.skipif(shutil.which("shellcheck") is None, reason="shellcheck not installed")
def test_shellcheck_clean():
    result = subprocess.run(["shellcheck", SCRIPT], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout


def test_help_exits_zero():
    result = subprocess.run(["bash", SCRIPT, "--help"], capture_output=True, text=True)
    assert result.returncode == 0
    assert "Usage" in result.stdout


def test_bad_argument_exits_two():
    result = subprocess.run(["bash", SCRIPT, "--nope"], capture_output=True, text=True)
    assert result.returncode == 2


@pytest.mark.skipif(sys.platform == "darwin", reason="would run the real check")
def test_declines_on_non_macos():
    result = subprocess.run(["bash", SCRIPT], capture_output=True, text=True)
    assert result.returncode == 2
    assert "macOS only" in result.stdout


def test_compliant_mac_passes(tmp_path):
    result = run(tmp_path)
    assert result.returncode == 0, result.stdout
    assert "0 FAIL" in result.stdout
    assert "FileVault" in result.stdout


def test_filevault_off_fails(tmp_path):
    result = run(tmp_path, filevault="FileVault is Off.")
    assert result.returncode == 1
    assert "FAIL   FileVault" in result.stdout


def test_firewall_disabled_fails(tmp_path):
    result = run(tmp_path, firewall="Firewall is disabled. (State = 0)")
    assert result.returncode == 1
    assert "FAIL   Application firewall" in result.stdout


def test_gatekeeper_and_sip_disabled_fail(tmp_path):
    result = run(tmp_path, gatekeeper="assessments disabled", sip="System Integrity Protection status: disabled.")
    assert result.returncode == 1
    assert "FAIL   Gatekeeper" in result.stdout
    assert "FAIL   System Integrity Protection" in result.stdout


def test_old_os_fails_and_min_os_is_configurable(tmp_path):
    assert run(tmp_path / "a", os_version="13.6.1").returncode == 1
    assert run(tmp_path / "b", os_version="13.6.1", args=("--min-os", "13")).returncode == 0


def test_admin_user_warns_but_does_not_fail(tmp_path):
    result = run(tmp_path, groups="staff admin everyone")
    assert result.returncode == 0
    assert "WARN   Current user is local admin" in result.stdout


def test_json_output_is_valid_and_has_no_personal_data(tmp_path):
    result = run(tmp_path, args=("--json",))
    data = json.loads(result.stdout)
    assert data["failCount"] == 0
    assert any(r["check"] == "FileVault" and r["status"] == "PASS" for r in data["results"])
    assert os.environ.get("USER", "\0") not in result.stdout or os.environ.get("USER") in (None, "", "root")


def test_script_contains_no_state_changing_commands():
    text = open(SCRIPT, encoding="utf-8").read()
    for forbidden in ("fdesetup enable", "fdesetup disable", "--setglobalstate", "--setstealthmode", "spctl --master",
                      "csrutil disable", "csrutil enable", "sudo ", "rm -", "defaults write", "softwareupdate --install"):
        assert forbidden not in text, forbidden
