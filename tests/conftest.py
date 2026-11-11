"""Shared helpers for the test suite."""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
POLICIES = REPO / "policies"
SCRIPTS = REPO / "scripts"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def find_pwsh():
    """Locate PowerShell 7. Honour PWSH_PATH, then PATH."""
    candidate = os.environ.get("PWSH_PATH")
    if candidate and Path(candidate).exists():
        return candidate
    return shutil.which("pwsh")


def run_pwsh(args, timeout=300):
    pwsh = find_pwsh()
    env = dict(os.environ)
    # Containers without ICU libraries need invariant globalization; harmless elsewhere.
    env.setdefault("DOTNET_SYSTEM_GLOBALIZATION_INVARIANT", "1")
    return subprocess.run(
        [pwsh, "-NoProfile", "-NonInteractive", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )


@pytest.fixture(scope="session")
def pwsh():
    path = find_pwsh()
    if not path:
        pytest.skip("PowerShell 7 (pwsh) not available; set PWSH_PATH or install it")
    return path


@pytest.fixture(scope="session")
def manifest():
    return json.loads((POLICIES / "manifest.json").read_text(encoding="utf-8"))


@pytest.fixture(scope="session")
def known_properties():
    return json.loads((Path(__file__).parent / "schemas" / "known_properties.json").read_text(encoding="utf-8"))


def policy_files():
    return sorted(p for p in POLICIES.rglob("*.json") if p.name != "manifest.json")
