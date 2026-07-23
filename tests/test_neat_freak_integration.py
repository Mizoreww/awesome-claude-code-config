from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL_DIR = ROOT / "skills" / "neat-freak"
UPSTREAM_COMMIT = "2b4a645cfdc894156ae347d897723562f719ce95"
UPSTREAM_URL = (
    "https://github.com/KKKKhazix/khazix-skills/tree/"
    f"{UPSTREAM_COMMIT}/neat-freak"
)

RUNTIME_SHA256 = {
    "SKILL.md": "6c0ca2236d3518ccaad710f6db8e9c4aa7af67b685dc699ad347ae42186951e1",
    "references/agent-paths.md": (
        "8210a3cc1211283f71f068de99fd17e62fb9ce269ca6e693879ce6c30e31aff6"
    ),
    "references/governance.md": (
        "6bf4bbf171864f2c82a5f8b8cf441df043362e8790c69ddca38f207c38bb5f72"
    ),
    "references/sync-matrix.md": (
        "5c771ba2695a0d0dc54ef636531d61c916ed7f0f39db39827bbb330268f7648d"
    ),
    "references/verification.md": (
        "cd3f4bf5cdc59c3aa51db868801f7461563a4b4a58b72799a6753c1f863c4126"
    ),
    "scripts/audit-inventory.sh": (
        "260315d659f19e63a12065f9cadd9b57f9c1ddc867457f6c0f6fd87c003a7325"
    ),
}
UPSTREAM_LICENSE_SHA256 = (
    "b7f53d07ea4ae2eef26a4f8b28cb7d4df95586e2aa713df408f1ffde9f5a0fea"
)


def _sha256(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


def test_runtime_snapshot_matches_pinned_upstream() -> None:
    for relative, expected_hash in RUNTIME_SHA256.items():
        file = SKILL_DIR / relative
        assert file.is_file(), f"missing vendored runtime file: {relative}"
        assert _sha256(file) == expected_hash, f"upstream drift: {relative}"


def test_vendored_package_contains_only_runtime_and_license() -> None:
    actual = {
        file.relative_to(SKILL_DIR).as_posix()
        for file in SKILL_DIR.rglob("*")
        if file.is_file()
    }
    assert actual == set(RUNTIME_SHA256) | {"LICENSE"}
    assert not (SKILL_DIR / "evals").exists()


def test_upstream_license_and_script_mode_are_preserved() -> None:
    assert _sha256(SKILL_DIR / "LICENSE") == UPSTREAM_LICENSE_SHA256
    assert (SKILL_DIR / "scripts" / "audit-inventory.sh").stat().st_mode & 0o111


def test_claude_installers_register_default_on_workflow_skill() -> None:
    bash = (ROOT / "install.sh").read_text(encoding="utf-8")
    powershell = (ROOT / "install.ps1").read_text(encoding="utf-8")

    assert 'CLAUDE_DIR="$HOME/.claude"' in bash
    assert (
        "neat-freak|Knowledge and governance closeout "
        "(KKKKhazix/khazix-skills)|1|skill-neat-freak"
    ) in bash
    assert (
        'skill-neat-freak)       INSTALL_SKILLS=true; '
        'SELECTED_SKILLS+=("neat-freak") ;;'
    ) in bash

    assert 'Join-Path $env:USERPROFILE ".claude"' in powershell
    assert (
        '@{ Label = "neat-freak";     Desc = "Knowledge and governance closeout '
        '(KKKKhazix/khazix-skills)"; Default = $true; Id = "skill-neat-freak" }'
    ) in powershell
    assert (
        '"skill-neat-freak"     { $result.Skills = $true; '
        '$result.SelectedSkills += "neat-freak" }'
    ) in powershell


def test_readmes_document_the_pinned_upstream_and_default() -> None:
    for readme_name in ("README.md", "README.zh-CN.md"):
        readme = (ROOT / readme_name).read_text(encoding="utf-8")
        assert UPSTREAM_URL in readme
        assert "[8/9] Workflow" in readme
        assert "**Workflow (9)**" in readme
