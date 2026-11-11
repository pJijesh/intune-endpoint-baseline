"""Static checks on every policy JSON file. Needs only Python, no PowerShell."""
import json
import re

import pytest

from conftest import POLICIES, REPO, policy_files

NAME_RE = re.compile(r"^EB-(WIN|MAC)-(CMP|CFG|UPD)-[A-Za-z0-9]+(-[A-Za-z0-9]+)*$")
GUID_RE = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")
REQUIRED_KEYS = ("@odata.type", "displayName", "description")
READ_ONLY_KEYS = ("id", "createdDateTime", "lastModifiedDateTime", "version", "assignments")
COMPLIANCE_TYPES = {"#microsoft.graph.windows10CompliancePolicy", "#microsoft.graph.macOSCompliancePolicy"}

FILES = policy_files()


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_policy_files_exist():
    assert len(FILES) >= 8, "expected the baseline policy set to be present"


@pytest.mark.parametrize("path", FILES, ids=lambda p: p.name)
def test_policy_parses_as_json_object(path):
    doc = load(path)
    assert isinstance(doc, dict)


@pytest.mark.parametrize("path", FILES, ids=lambda p: p.name)
def test_policy_has_required_keys(path):
    doc = load(path)
    for key in REQUIRED_KEYS:
        assert key in doc and str(doc[key]).strip(), f"{path.name}: missing or empty {key}"
    assert doc["@odata.type"].startswith("#microsoft.graph.")


@pytest.mark.parametrize("path", FILES, ids=lambda p: p.name)
def test_policy_name_convention_and_filename(path):
    doc = load(path)
    assert NAME_RE.match(doc["displayName"]), doc["displayName"]
    assert doc["displayName"] == path.stem


@pytest.mark.parametrize("path", FILES, ids=lambda p: p.name)
def test_policy_has_no_read_only_keys_guids_or_tenant_data(path):
    text = path.read_text(encoding="utf-8")
    doc = json.loads(text)
    for key in READ_ONLY_KEYS:
        assert key not in doc, f"{path.name}: {key} must not be present"
    assert not GUID_RE.search(text), "GUIDs (tenant, object or app IDs) must not appear in policy files"
    assert "onmicrosoft.com" not in text.lower()
    assert not re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", text)


def test_display_names_are_unique():
    names = [load(p)["displayName"] for p in FILES]
    assert len(names) == len(set(names))


def test_manifest_covers_every_file_and_nothing_else(manifest):
    listed = {e["file"] for e in manifest["policies"]}
    on_disk = {p.relative_to(POLICIES).as_posix() for p in FILES}
    assert listed == on_disk


def test_manifest_matches_file_types_and_collections(manifest):
    for entry in manifest["policies"]:
        doc = load(POLICIES / entry["file"])
        assert entry["odataType"] == doc["@odata.type"], entry["file"]
        assert entry["graphVersion"] in ("v1.0", "beta")
        expected = (
            "deviceManagement/deviceCompliancePolicies"
            if doc["@odata.type"] in COMPLIANCE_TYPES
            else "deviceManagement/deviceConfigurations"
        )
        assert entry["collection"] == expected, entry["file"]


def test_manifest_graph_version_matches_verified_schema(manifest, known_properties):
    """The version a file targets must be the version whose reference page was used to verify it."""
    for entry in manifest["policies"]:
        schema = known_properties["types"][entry["odataType"]]
        assert entry["graphVersion"] == schema["graphVersion"], entry["file"]


@pytest.mark.parametrize("path", FILES, ids=lambda p: p.name)
def test_properties_are_verified_schema_properties(path, known_properties):
    doc = load(path)
    schema = known_properties["types"].get(doc["@odata.type"])
    assert schema is not None, f"{path.name}: no verified schema for {doc['@odata.type']}"
    allowed = set(known_properties["common"]) | set(schema["properties"])
    unknown = set(doc) - allowed
    assert not unknown, f"{path.name}: properties not verified against Microsoft Learn: {sorted(unknown)}"


@pytest.mark.parametrize("path", FILES, ids=lambda p: p.name)
def test_enum_and_range_values_are_valid(path, known_properties):
    doc = load(path)
    schema = known_properties["types"][doc["@odata.type"]]
    for prop, allowed in schema.get("enums", {}).items():
        if prop in doc:
            assert doc[prop] in allowed, f"{path.name}: {prop}={doc[prop]!r} not in {allowed}"
    for prop, (low, high) in schema.get("ranges", {}).items():
        if prop in doc:
            assert low <= doc[prop] <= high, f"{path.name}: {prop}={doc[prop]} outside {low}..{high}"
    for nested in schema.get("nested", {}).values():
        for key in nested["keys"]:
            if key not in doc:
                continue
            obj = doc[key]
            assert set(obj) <= set(nested["properties"]), f"{path.name}: {key} has unverified properties"
            for prop, allowed in nested.get("enums", {}).items():
                if prop in obj:
                    assert obj[prop] in allowed


@pytest.mark.parametrize("path", [p for p in FILES if load(p)["@odata.type"] in COMPLIANCE_TYPES], ids=lambda p: p.name)
def test_compliance_policies_have_exactly_one_block_action(path):
    doc = load(path)
    actions = [
        a
        for rule in doc["scheduledActionsForRule"]
        for a in rule["scheduledActionConfigurations"]
    ]
    assert sum(1 for a in actions if a["actionType"] == "block") == 1
    for a in actions:
        assert 0 <= a["gracePeriodHours"] <= 8760


def test_windows_compliance_requires_core_controls():
    doc = load(POLICIES / "windows" / "EB-WIN-CMP-Baseline.json")
    for key in ("bitLockerEnabled", "secureBootEnabled", "tpmRequired", "defenderEnabled", "rtpEnabled",
                "activeFirewallRequired", "storageRequireEncryption", "passwordRequired"):
        assert doc[key] is True, key


def test_macos_compliance_requires_core_controls():
    doc = load(POLICIES / "macos" / "EB-MAC-CMP-Baseline.json")
    for key in ("storageRequireEncryption", "firewallEnabled", "systemIntegrityProtectionEnabled", "passwordRequired"):
        assert doc[key] is True, key


def test_update_rings_fit_the_fourteen_day_patch_window():
    """Deferral + deadline + grace must stay inside 14 days, and rings must be ordered."""
    rings = {}
    for path in (POLICIES / "windows").glob("EB-WIN-UPD-Ring*.json"):
        d = load(path)
        rings[path.stem] = (
            d["qualityUpdatesDeferralPeriodInDays"],
            d["deadlineForQualityUpdatesInDays"],
            d["deadlineGracePeriodInDays"],
        )
    assert len(rings) == 3
    totals = [sum(v) for _, v in sorted(rings.items())]
    assert all(t <= 14 for t in totals), rings
    ordered = [rings[k] for k in sorted(rings)]
    assert ordered[0][0] <= ordered[1][0] <= ordered[2][0], "deferral must not shrink from pilot to broad"


def test_no_policy_is_assigned_or_targets_a_group():
    for path in FILES:
        assert "assignments" not in load(path)
        assert "target" not in path.read_text(encoding="utf-8").lower().replace("targets", "")


def test_documentation_mentions_every_policy():
    docs = "\n".join(p.read_text(encoding="utf-8") for p in REPO.rglob("*.md"))
    for path in FILES:
        assert path.stem in docs, f"{path.stem} is not mentioned in any markdown file"


def test_text_files_have_no_em_dashes():
    offenders = []
    for path in REPO.rglob("*"):
        if path.is_file() and ".git" not in path.parts and path.suffix in {".md", ".json", ".ps1", ".sh", ".py", ".yml", ".yaml", ".txt", ""}:
            if path.name.endswith((".svg", ".png")):
                continue
            try:
                if chr(0x2014) in path.read_text(encoding="utf-8"):
                    offenders.append(str(path.relative_to(REPO)))
            except UnicodeDecodeError:
                pass
    assert not offenders, offenders


def test_markdown_relative_links_resolve():
    link_re = re.compile(r"\]\((?!https?://|mailto:|#)([^)#\s]+)(?:#[^)]*)?\)")
    missing = []
    for md in REPO.rglob("*.md"):
        for target in link_re.findall(md.read_text(encoding="utf-8")):
            if not (md.parent / target).resolve().exists():
                missing.append(f"{md.relative_to(REPO)} -> {target}")
    assert not missing, missing


def test_lifecycle_diagram_source_matches_markdown_block():
    md = (REPO / "docs" / "device-lifecycle.md").read_text(encoding="utf-8")
    block = re.search(r"```mermaid\n(.*?)```", md, re.S).group(1).strip()
    source = (REPO / "docs" / "images" / "device-lifecycle.mmd").read_text(encoding="utf-8").strip()
    assert block == source, "docs/device-lifecycle.md and docs/images/device-lifecycle.mmd have drifted apart"
