from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest


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


def _assert_package_copy_matches(destination: Path) -> None:
    expected_files = {
        file.relative_to(SKILL_DIR).as_posix(): _sha256(file)
        for file in SKILL_DIR.rglob("*")
        if file.is_file()
    }
    actual_files = {
        file.relative_to(destination).as_posix(): _sha256(file)
        for file in destination.rglob("*")
        if file.is_file()
    }
    assert actual_files == expected_files


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
    # Derive the expected Workflow size from install.sh rather than hard-coding it,
    # so adding or removing a Workflow item does not silently rot this test.
    bash = (ROOT / "install.sh").read_text(encoding="utf-8")
    workflow_block = re.search(
        r'GROUP_LABELS\+=\("Workflow"\).*?GROUP_ITEMS\+=\("(.*?)"\)', bash, re.S
    )
    assert workflow_block, "Workflow group not found in install.sh"
    workflow_items = [
        line for line in workflow_block.group(1).splitlines() if line.count("|") == 3
    ]
    selected = sum(1 for line in workflow_items if line.split("|")[2] == "1")
    total = len(workflow_items)

    for readme_name in ("README.md", "README.zh-CN.md"):
        readme = (ROOT / readme_name).read_text(encoding="utf-8")
        assert UPSTREAM_URL in readme
        assert f"[{selected}/{total}] Workflow" in readme
        assert f"**Workflow ({total})**" in readme


@pytest.mark.integration
def test_bash_installer_dry_run_and_recursive_copy(tmp_path: Path) -> None:
    installer = ROOT / "install.sh"
    syntax = subprocess.run(
        ["bash", "-n", str(installer)], capture_output=True, text=True, check=False
    )
    assert syntax.returncode == 0, syntax.stderr

    dry_home = tmp_path / "dry-home"
    dry_home.mkdir()
    dry_env = os.environ | {"HOME": str(dry_home)}
    dry_run = subprocess.run(
        ["bash", str(installer), "--all", "--dry-run", "--force"],
        cwd=ROOT,
        env=dry_env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert dry_run.returncode == 0, dry_run.stdout + dry_run.stderr
    assert "Would copy: skills/neat-freak/ ->" in dry_run.stdout
    assert not (dry_home / ".claude" / "skills" / "neat-freak").exists()

    source = installer.read_text(encoding="utf-8")
    suffix = '\nmain "$@"\n'
    assert source.endswith(suffix)
    loader = tmp_path / "install-functions.sh"
    loader.write_text(source[: -len(suffix)] + "\n", encoding="utf-8")

    actual_home = tmp_path / "actual-home"
    actual_home.mkdir()
    harness = "\n".join(
        (
            "set -euo pipefail",
            f'source "{loader}"',
            f'SCRIPT_DIR="{ROOT}"',
            f'CLAUDE_DIR="{actual_home / ".claude"}"',
            "DRY_RUN=false",
            'SELECTED_SKILLS=("neat-freak")',
            "install_skills",
        )
    )
    copied = subprocess.run(
        ["bash", "-c", harness], capture_output=True, text=True, check=False
    )
    assert copied.returncode == 0, copied.stdout + copied.stderr
    _assert_package_copy_matches(
        actual_home / ".claude" / "skills" / "neat-freak"
    )


@pytest.mark.integration
def test_powershell_installer_dry_run_and_recursive_copy(tmp_path: Path) -> None:
    pwsh = os.environ.get("PWSH") or shutil.which("pwsh")
    if not pwsh:
        pytest.skip("PowerShell is not available")

    installer = ROOT / "install.ps1"
    parse_command = (
        "$tokens=$null; $errors=$null; "
        f"[System.Management.Automation.Language.Parser]::ParseFile('{installer}', "
        "[ref]$tokens, [ref]$errors) > $null; "
        "if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }"
    )
    syntax = subprocess.run(
        [pwsh, "-NoLogo", "-NoProfile", "-Command", parse_command],
        capture_output=True,
        text=True,
        check=False,
    )
    assert syntax.returncode == 0, syntax.stdout + syntax.stderr

    dry_home = tmp_path / "ps-dry-home"
    dry_home.mkdir()
    dry_cache = tmp_path / "ps-cache"
    dry_env = os.environ | {
        "HOME": str(dry_home),
        "USERPROFILE": str(dry_home),
        "LOCALAPPDATA": str(dry_home / ".local"),
        "XDG_CACHE_HOME": str(dry_cache),
        "POWERSHELL_TELEMETRY_OPTOUT": "1",
    }
    dry_run = subprocess.run(
        [pwsh, "-NoLogo", "-NoProfile", "-File", str(installer), "-All", "-DryRun", "-Force"],
        cwd=ROOT,
        env=dry_env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert dry_run.returncode == 0, dry_run.stdout + dry_run.stderr
    assert "Would copy: skills\\neat-freak\\" in dry_run.stdout
    assert not (dry_home / ".claude" / "skills" / "neat-freak").exists()

    source = installer.read_text(encoding="utf-8")
    assert "& {\n" in source
    suffix = "\nMain\n} @_safeArgs\n"
    assert source.endswith(suffix)
    loader_source = source.replace("& {\n", ". {\n", 1)
    loader_source = loader_source[: -len(suffix)] + "\n}\n"
    actual_home = tmp_path / "ps-actual-home"
    actual_home.mkdir()
    loader_source += "\n".join(
        (
            f"$script:SCRIPT_DIR = '{ROOT}'",
            f"$script:CLAUDE_DIR = '{actual_home / '.claude'}'",
            "$script:DryRun = $false",
            "Install-Skills -SelectedSkills @('neat-freak')",
            "",
        )
    )
    loader = tmp_path / "install-functions.ps1"
    loader.write_text(loader_source, encoding="utf-8")
    copied = subprocess.run(
        [pwsh, "-NoLogo", "-NoProfile", "-File", str(loader)],
        env=dry_env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert copied.returncode == 0, copied.stdout + copied.stderr
    _assert_package_copy_matches(
        actual_home / ".claude" / "skills" / "neat-freak"
    )
