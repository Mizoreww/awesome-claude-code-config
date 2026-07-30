from __future__ import annotations

import ast
import hashlib
import os
from pathlib import Path
import re
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]
SKILL_DIR = ROOT / "skills" / "storage-analyzer"

# Baseline this vendored copy forked from. Unlike neat-freak, the runtime is NOT
# byte-for-byte upstream: Linux support and security hardening were added here and
# submitted back as KKKKhazix/khazix-skills#50. So we assert provenance is declared,
# not that the files match upstream.
UPSTREAM_COMMIT = "fcba3adcf5def1ccd4bb688de93060227471b129"
UPSTREAM_URL = (
    "https://github.com/KKKKhazix/khazix-skills/tree/"
    f"{UPSTREAM_COMMIT}/storage-analyzer"
)
UPSTREAM_PR_URL = "https://github.com/KKKKhazix/khazix-skills/pull/50"

# Same MIT file neat-freak vendors — both come from the same upstream repository.
UPSTREAM_LICENSE_SHA256 = (
    "b7f53d07ea4ae2eef26a4f8b28cb7d4df95586e2aa713df408f1ffde9f5a0fea"
)

EXPECTED_FILES = {
    "SKILL.md",
    "UPSTREAM.md",
    "LICENSE",
    "assets/report_template.html",
    "references/linux.md",
    "references/macos.md",
    "references/windows.md",
    "scripts/build_report.py",
    "scripts/scan.py",
    "scripts/server.py",
}


def _sha256(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest()


def test_vendored_package_contains_exactly_the_runtime_and_provenance() -> None:
    actual = {
        file.relative_to(SKILL_DIR).as_posix()
        for file in SKILL_DIR.rglob("*")
        if file.is_file()
    }
    assert actual == EXPECTED_FILES
    # Compiled artefacts must never be vendored.
    assert not list(SKILL_DIR.rglob("__pycache__"))
    assert not list(SKILL_DIR.rglob("*.pyc"))


def test_upstream_license_is_preserved() -> None:
    assert _sha256(SKILL_DIR / "LICENSE") == UPSTREAM_LICENSE_SHA256


def test_provenance_and_local_modifications_are_declared() -> None:
    upstream = (SKILL_DIR / "UPSTREAM.md").read_text(encoding="utf-8")
    # Where it came from, and that the fork point is pinned.
    assert UPSTREAM_URL in upstream
    # Where the changes went back to.
    assert UPSTREAM_PR_URL in upstream
    # The three substantive change areas must stay documented.
    for topic in ("Linux 支持", "安全模型", "对账"):
        assert topic in upstream, f"UPSTREAM.md no longer documents: {topic}"

    # SKILL.md must point at UPSTREAM.md so an agent reading only the skill
    # still learns this is a modified copy.
    skill = (SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
    assert "UPSTREAM.md" in skill
    assert "KKKKhazix/khazix-skills" in skill


def test_scripts_are_stdlib_only_and_compile() -> None:
    # The skill advertises zero third-party dependencies; a stray import would
    # break it on a bare Python install.
    stdlib_ok = {
        "json", "os", "re", "shutil", "stat", "subprocess", "sys", "time",
        "secrets", "webbrowser", "http.server", "ctypes", "platform", "string",
        "urllib.parse", "socket",
    }
    for script in sorted((SKILL_DIR / "scripts").glob("*.py")):
        tree = ast.parse(script.read_text(encoding="utf-8"), filename=str(script))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom):
                names = [node.module or ""]
            else:
                continue
            for name in names:
                root = name.split(".")[0]
                assert name in stdlib_ok or root in stdlib_ok, (
                    f"{script.name} imports non-stdlib module: {name}"
                )
        compile(script.read_text(encoding="utf-8"), str(script), "exec")


def test_scanner_never_mutates_the_filesystem() -> None:
    # The skill's first iron rule is that scanning is strictly read-only.
    source = (SKILL_DIR / "scripts" / "scan.py").read_text(encoding="utf-8")
    forbidden = (
        r"\bos\.remove\b", r"\bos\.unlink\b", r"\bos\.rmdir\b", r"\bos\.rename\b",
        r"\bos\.makedirs\b", r"\bos\.mkdir\b", r"\bshutil\.move\b",
        r"\bshutil\.rmtree\b", r"\bshutil\.copy",
    )
    for pattern in forbidden:
        assert not re.search(pattern, source), (
            f"scan.py must stay read-only, found: {pattern}"
        )
    # And it must not shell out to a mutating command.
    assert not re.search(r'"(rm|mv|rmdir|chmod)"', source)


def test_destructive_allowlist_rejects_privileged_and_out_of_home_paths() -> None:
    # These five guards are the skill's safety model; losing any one of them
    # silently widens what the delete endpoint will act on.
    source = (SKILL_DIR / "scripts" / "server.py").read_text(encoding="utf-8")
    assert "def destructive_ok" in source
    assert 'item.get("needs_sudo")' in source          # privileged items barred
    assert "rp.startswith(HOME + os.sep)" in source    # strict descendants only
    assert "_crosses_mount(rp)" in source              # bind-mount escape barred
    assert "_same_fs_as_trash(rp)" in source           # cross-filesystem barred
    assert "dir_fd=parent_fd" in source                # fd-anchored execution


def test_claude_installers_register_default_off_storage_skill() -> None:
    bash = (ROOT / "install.sh").read_text(encoding="utf-8")
    powershell = (ROOT / "install.ps1").read_text(encoding="utf-8")

    assert 'GROUP_LABELS+=("Storage")' in bash
    assert 'GROUP_HINTS+=("disk usage analysis · default off")' in bash
    item = re.search(
        r'GROUP_ITEMS\+=\("storage-analyzer\|([^|]*)\|(\d)\|(skill-storage-analyzer)"\)',
        bash,
    )
    assert item, "storage-analyzer entry not found in install.sh"
    assert item.group(2) == "0", "storage-analyzer must default to OFF"
    assert "KKKKhazix/khazix-skills" in item.group(1), "attribution missing from the menu label"
    assert (
        'skill-storage-analyzer) INSTALL_SKILLS=true; '
        'SELECTED_SKILLS+=("storage-analyzer") ;;'
    ) in bash

    assert '@{ Label = "Storage"; Hint = "disk usage analysis | default off"' in powershell
    assert 'Default = $false; Id = "skill-storage-analyzer"' in powershell
    assert (
        '"skill-storage-analyzer" { $result.Skills = $true; '
        '$result.SelectedSkills += "storage-analyzer" }'
    ) in powershell


def test_readmes_document_the_upstream_and_default_off() -> None:
    for readme_name in ("README.md", "README.zh-CN.md"):
        readme = (ROOT / readme_name).read_text(encoding="utf-8")
        assert UPSTREAM_URL in readme, f"{readme_name} must link the pinned upstream"
        assert "storage-analyzer" in readme


@pytest.mark.integration
def test_bash_installer_copies_the_skill_in_all_mode(tmp_path: Path) -> None:
    installer = ROOT / "install.sh"
    syntax = subprocess.run(
        ["bash", "-n", str(installer)], capture_output=True, text=True, check=False
    )
    assert syntax.returncode == 0, syntax.stderr

    dry_home = tmp_path / "dry-home"
    dry_home.mkdir()
    result = subprocess.run(
        ["bash", str(installer), "--dry-run", "--all"],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ | {"HOME": str(dry_home)},
        cwd=str(ROOT),
    )
    assert result.returncode == 0, result.stderr
    assert "skills/storage-analyzer/" in result.stdout
