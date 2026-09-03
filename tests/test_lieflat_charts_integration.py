from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.error
import urllib.request

import pytest


ROOT = Path(__file__).resolve().parents[1]

# lieflat-charts is fetched at install time, not vendored. Two facts drive that: the upstream
# repo is ~20 MB, and it is licensed PolyForm Noncommercial 1.0.0, which would make this MIT
# repo a redistributor of noncommercially-licensed code if it carried a copy.
UPSTREAM_URL = "https://github.com/larashero3-dotcom/lieflat-charts"
LICENSE_NAME = "PolyForm Noncommercial 1.0.0"
MARKER_FILE = ".lieflat-charts-installed"

# Cone-mode sparse checkout keeps every root file automatically; these are the extra
# directories. docs/ (18.7 MB of preview media) is deliberately excluded.
EXPECTED_SPARSE_DIRS = ["templates", "examples", "scripts", "agents"]
EXCLUDED_DIR = "docs"

# Root files and nested paths the fixture repo below mirrors from upstream's real layout.
FIXTURE_ROOT_FILES = [
    "SKILL.md",
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "catalog.md",
    "report-catalog.md",
    "README.md",
    "color-presets.js",
    "mono-tokens.js",
]
FIXTURE_NESTED = [
    "templates/lupi-gallery.html",
    "templates/color/lupi-palm.html",
    "templates/reports/report-01.zh.html",
    "examples/lenny.html",
    "examples/reports/r04.html",
    "scripts/validate.mjs",
    "agents/openai.yaml",
    f"{EXCLUDED_DIR}/assets/reports/report-01.png",
    # A hidden top-level directory: cone mode never materialises it, so the fallback
    # path must trim it too or the two paths diverge.
    ".github/workflows/ci.yml",
]


def _bash() -> str:
    return (ROOT / "install.sh").read_text(encoding="utf-8")


def _powershell() -> str:
    return (ROOT / "install.ps1").read_text(encoding="utf-8")


# --- fixtures ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def fixture_repo(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """A local git repo mirroring upstream's top-level shape, served over file://.

    Lets the install path be exercised for real -- sparse checkout, fallback, allow-list,
    .git stripping, marker -- with no network.
    """
    repo = tmp_path_factory.mktemp("lieflat-upstream")
    for name in FIXTURE_ROOT_FILES:
        (repo / name).write_text(f"{name}\n", encoding="utf-8")
    for rel in FIXTURE_NESTED:
        path = repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"{rel}\n", encoding="utf-8")

    run = lambda *args: subprocess.run(  # noqa: E731 - terse local helper
        args, cwd=repo, check=True, capture_output=True, text=True
    )
    run("git", "init", "-q", "-b", "main", ".")
    run("git", "add", "-A")
    run(
        "git",
        "-c",
        "user.email=fixture@test",
        "-c",
        "user.name=fixture",
        "commit",
        "-qm",
        "init",
    )
    # file:// remotes reject --filter unless the server side opts in.
    run("git", "config", "uploadpack.allowFilter", "true")
    return repo


@pytest.fixture(scope="module")
def driver(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """install.sh with its entrypoint neutralised, so one function can be called directly."""
    script = _bash()
    entrypoint = '\nmain "$@"\n'
    assert script.endswith(entrypoint), "install.sh no longer ends with its main entrypoint"
    path = tmp_path_factory.mktemp("driver") / "driver.sh"
    path.write_text(
        script[: -len(entrypoint)] + "\n: # entrypoint disabled for tests\n",
        encoding="utf-8",
    )
    return path


def _install(
    driver: Path, repo: Path, home: Path, *, no_partial_clone: bool = False
) -> subprocess.CompletedProcess[str]:
    """Run install_lieflat_charts against the fixture repo in an isolated HOME."""
    home.mkdir(parents=True, exist_ok=True)
    env = os.environ | {"HOME": str(home)}
    if no_partial_clone:
        # A git shim that refuses partial/sparse clone, forcing the fallback branch the way
        # an old git or a mirror without filter support would.
        shim = home / "shim"
        shim.mkdir(exist_ok=True)
        (shim / "git").write_text(
            "#!/usr/bin/env bash\n"
            'for a in "$@"; do [[ "$a" == "--sparse" || "$a" == "--filter=blob:none" ]] '
            "&& exit 128; done\n"
            f'exec {shutil.which("git")} "$@"\n',
            encoding="utf-8",
        )
        (shim / "git").chmod(0o755)
        env["PATH"] = f"{shim}:{env['PATH']}"

    # Production calls this as `install_lieflat_charts || true`, which disables errexit for
    # the whole function body. Reproduce that here -- calling it under `set -e` would let
    # `set -e` catch failures the real installer silently continues past.
    script = (
        f'source "{driver}"; LIEFLAT_REPO_URL="file://{repo}"; '
        "set +e; install_lieflat_charts; rc=$?; set -e; echo \"__RC__=$rc\""
    )
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
        env=env,
        cwd=str(ROOT),
        timeout=180,
    )
    match = re.search(r"__RC__=(\d+)", result.stdout)
    assert match, f"harness did not report a return code:\n{result.stdout}\n{result.stderr}"
    # Surface the function's own status, not the wrapper shell's.
    result.returncode = int(match.group(1))
    return result


def _assert_installed_tree(home: Path) -> Path:
    skill = home / ".claude" / "skills" / "lieflat-charts"
    for name in FIXTURE_ROOT_FILES:
        assert (skill / name).is_file(), f"cone mode must keep root file {name}"
    for rel in FIXTURE_NESTED:
        if rel.split("/", 1)[0] not in EXPECTED_SPARSE_DIRS:
            continue  # docs/ and .github/ are trimmed, asserted below
        assert (skill / rel).is_file(), f"allow-listed path missing: {rel}"
    assert not (skill / EXCLUDED_DIR).exists(), "docs/ preview media must not be installed"
    assert not (skill / ".github").exists(), "hidden upstream directories must not be installed"
    # A partial clone's .git is bound to a promisor remote; it must not land in ~/.claude.
    assert not (skill / ".git").exists()
    assert (home / ".claude" / MARKER_FILE).is_file()
    return skill


# --- structural checks ------------------------------------------------------------------


def test_the_skill_is_fetched_not_vendored() -> None:
    # The whole design rests on this repo never carrying a copy: shipping one would attach
    # PolyForm's redistribution obligations and add ~1.4 MB (or 20 MB unfiltered) to a
    # skills/ tree that is currently ~650 KB in total.
    assert not (ROOT / "skills" / "lieflat-charts").exists()

    bash = _bash()
    assert f'LIEFLAT_REPO_URL="{UPSTREAM_URL}"' in bash
    assert (
        "LIEFLAT_SPARSE_DIRS=(" + " ".join(f'"{d}"' for d in EXPECTED_SPARSE_DIRS) + ")"
    ) in bash

    powershell = _powershell()
    assert f'$LIEFLAT_REPO_URL = "{UPSTREAM_URL}"' in powershell
    assert (
        "$LIEFLAT_SPARSE_DIRS = @("
        + ", ".join(f'"{d}"' for d in EXPECTED_SPARSE_DIRS)
        + ")"
    ) in powershell


def test_claude_installers_register_default_off_design_item() -> None:
    bash = _bash()
    assert (
        "lieflat-charts|HTML chart & report templates "
        "(larashero3, PolyForm-NC · noncommercial)|0|lieflat-charts"
    ) in bash
    assert "lieflat-charts)         INSTALL_LIEFLAT=true ;;" in bash

    powershell = _powershell()
    assert (
        '@{ Label = "lieflat-charts";  Desc = "HTML chart & report templates '
        '(larashero3, PolyForm-NC | noncommercial)"; Default = $false; '
        'Id = "lieflat-charts" }'
    ) in powershell
    assert '"lieflat-charts"     { $result.Lieflat = $true }' in powershell

    # The item must sit in Design & Content, not in its own group.
    design_block = re.search(
        r'GROUP_LABELS\+=\("Design & Content"\).*?GROUP_ITEMS\+=\("(.*?)"\)', bash, re.S
    )
    assert design_block, "Design & Content group not found in install.sh"
    assert "lieflat-charts" in design_block.group(1)


def test_both_installers_pin_the_clone_to_the_main_branch() -> None:
    # The licence URL and the drift test both name main. Following the remote's default
    # branch instead would silently install something else if upstream renamed it.
    # Count clone invocations, not comment prose that happens to mention the flag.
    for source in (_bash(), _powershell()):
        clones = [
            line
            for line in source.splitlines()
            if "git clone" in line and "--branch main" in line
        ]
        assert len(clones) == 2, clones  # sparse attempt + full-clone fallback


def test_license_notice_is_announced_before_any_work() -> None:
    bash = _bash()
    assert LICENSE_NAME in bash
    # Both installers interpolate the repo URL rather than repeating it literally; the
    # expanded form is asserted against real output in the dry-run test below.
    assert "$LIEFLAT_REPO_URL/blob/main/LICENSE" in bash
    # The notice lives in its own function called from the pre-install phase, not inside
    # the installer, so a --all run cannot do substantial work before showing it.
    assert "announce_lieflat_license() {" in bash
    assert bash.index("if $INSTALL_LIEFLAT; then\n        announce_lieflat_license") < bash.index(
        "$INSTALL_DEEPXIV && install_deepxiv"
    )

    powershell = _powershell()
    assert LICENSE_NAME in powershell
    assert "function Show-LieflatLicenseNotice {" in powershell
    assert powershell.index("Show-LieflatLicenseNotice\n") < powershell.index(
        "if ($doLieflat) { Install-LieflatCharts }"
    )

    # --all keeps meaning "everything", so it must still select the item.
    assert "INSTALL_LIEFLAT=true\n            INSTALL_RESEARCHSTUDIO=true" in bash
    assert "$doLieflat = $true" in powershell


def test_powershell_never_pipes_native_git_stderr() -> None:
    # Under $ErrorActionPreference = "Stop", Windows PowerShell 5.1 can turn a native
    # command's stderr into a terminating NativeCommandError. Piping git through Out-Null
    # would abort the run on a routine progress line instead of reaching the fallback.
    powershell = _powershell()
    lieflat = powershell[powershell.index("function Install-LieflatCharts {") :]
    lieflat = lieflat[: lieflat.index("\n# Install ResearchStudio")]
    assert "2>&1 | Out-Null" not in lieflat
    assert "$LASTEXITCODE" in lieflat


def test_bash_uninstall_keeps_a_skill_it_failed_to_remove() -> None:
    # Making rm -rf fail needs an unwritable parent, which would break the rest of the
    # sweep too, so this invariant is pinned at source level: a failed managed removal must
    # set lieflat_keep, or the fallback sweep deletes what was just reported as kept.
    bash = _bash()
    block = bash[bash.index("# lieflat-charts is settled BEFORE") :]
    block = block[: block.index("# Only remove skills that ship with this repo")]
    failure_branch = block[block.index("Could not remove $CLAUDE_DIR/skills/lieflat-charts") :]
    assert "lieflat_keep=true" in failure_branch
    # Marker clearing goes through the checked helper, never a bare rm -f, and happens
    # BEFORE the directory removal: a marker outliving a failed clear would make the next
    # uninstall delete a hand-installed replacement.
    assert 'rm -f "$CLAUDE_DIR/$LIEFLAT_MARKER_FILE"' not in block
    # Removal is gated on the clear SUCCEEDING, not merely ordered after it: deleting the
    # skill while its marker survives would make the next uninstall delete a hand-installed
    # replacement.
    assert "if ! lieflat_clear_marker; then" in block
    assert block.index("if ! lieflat_clear_marker; then") < block.index(
        'rm -rf "$CLAUDE_DIR/skills/lieflat-charts"'
    )


def test_powershell_mirrors_the_bash_safety_invariants() -> None:
    # pwsh is not installed in this repo's CI or on the author's machine, so the PowerShell
    # branch cannot be executed. These assertions pin the invariants the Bash side proves
    # behaviourally, so the two implementations cannot drift apart unnoticed.
    powershell = _powershell()
    body = powershell[powershell.index("function Install-LieflatCharts {") :]
    body = body[: body.index("\n# Install ResearchStudio")]

    # A dry run must not create directories.
    assert body.index("if ($DryRun) {") < body.index(
        "New-Item -ItemType Directory -Path $skillsDir"
    )
    # Staging lives outside skills\ (so a partial copy is never loaded as a skill) and is
    # PID-suffixed (so concurrent installers cannot collide).
    assert '$scratch = Join-Path $CLAUDE_DIR ".lieflat-charts.scratch.$scratchId"' in body
    assert '$staged = Join-Path $scratch "incoming"' in body
    assert '$retired = Join-Path $scratch "retired"' in body
    # Retire-then-move, never delete-then-move: the latter drops the staged tree *inside*
    # the destination if the delete fails.
    assert body.index("Move-Item $dst $retired -Force") < body.index(
        "Move-Item $staged $dst -Force"
    )
    # A failed trim must warn, not terminate an -All run over one optional skill.
    assert "Invoke-LieflatAllowList -Root $src\n        } catch {" in body
    # The swap result is verified, so a lost race cannot report a success that did not happen.
    assert 'throw "$dst looks corrupted after install' in body
    # A failed rollback must leave the retired copy on disk -- it may be the only one left.
    assert "move it back manually" in body
    assert body.index("Move-Item $retired $dst -Force -ErrorAction SilentlyContinue") < body.index(
        "move it back manually"
    )
    # Checking SKILL.md alone is not enough: a competing installer supplies one, so the
    # nested staging directory is what actually proves the rename went wrong.
    assert '$nested = Join-Path $dst "incoming"' in body
    # The retired copy is cleared only after the marker is written, and outside the swap's
    # try -- otherwise a failure to delete it would skip the marker on a valid install.
    assert body.index("New-Item -ItemType File -Path $marker") < body.index(
        "if (Test-Path $scratch) { Remove-Item $scratch -Recurse -Force -ErrorAction SilentlyContinue }"
    )
    # No scratch reaper, and no PID-derived scratch names: a rerun in the same session
    # reuses $PID, so either would delete the backup the failed-rollback path preserves.
    assert "Get-Process -Id" not in body
    assert "$scratchId = [System.IO.Path]::GetRandomFileName()" in body
    for pid_named in (".scratch.$PID", ".incoming.$PID", ".retired.$PID"):
        assert pid_named not in body
    # Random names never collide, so no scratch path is ever pre-deleted.
    assert "Remove-Item $staged -Recurse -Force }\n        Copy-Item" not in body
    # A rollback that leaves nothing at the canonical path must clear the marker.
    assert "Remove-LieflatMarker -Marker $marker" in body

    # Uninstall: a failed removal must keep the skill out of the generic sweep, and the
    # marker must never be dropped silently.
    assert "function Remove-LieflatMarker {" in powershell
    uninstall = powershell[powershell.index("$lieflatMarker = Join-Path $CLAUDE_DIR") :]
    uninstall = uninstall[: uninstall.index("# Remove DeepXiv skills")]
    assert "$lieflatKeep = $true" in uninstall
    assert "Remove-Item $lieflatMarker -Force -ErrorAction SilentlyContinue" not in uninstall
    assert "Test-Path $lieflatMarker -PathType Leaf" in uninstall
    # Marker cleared BEFORE the directory: a marker outliving a failed clear would make the
    # next uninstall delete a hand-installed replacement.
    assert "if (-not (Remove-LieflatMarker -Marker $lieflatMarker)) {" in uninstall
    assert uninstall.index("if (-not (Remove-LieflatMarker -Marker $lieflatMarker)) {") < uninstall.index(
        "Remove-Item $lieflatDir -Recurse -Force"
    )


def test_readmes_disclose_the_license_and_the_group_size() -> None:
    # Derive the Design & Content size from install.sh so adding or removing an item there
    # does not silently rot the README.
    bash = _bash()
    design_block = re.search(
        r'GROUP_LABELS\+=\("Design & Content"\).*?GROUP_ITEMS\+=\("(.*?)"\)', bash, re.S
    )
    assert design_block
    items = [line for line in design_block.group(1).splitlines() if line.count("|") == 3]
    total = len(items)
    selected = sum(1 for line in items if line.split("|")[2] == "1")

    for readme_name in ("README.md", "README.zh-CN.md"):
        readme = (ROOT / readme_name).read_text(encoding="utf-8")
        assert f"[{selected}/{total}] Design & Content" in readme
        assert f"**Design & Content ({total})**" in readme
        assert UPSTREAM_URL in readme
        # The licence must be named in the License section, not only in the table.
        license_section = readme.split("## License", 1)[1]
        assert LICENSE_NAME in license_section
        assert f"{UPSTREAM_URL}/blob/main/LICENSE" in license_section


def test_readme_sync_check_still_passes() -> None:
    result = subprocess.run(
        ["bash", str(ROOT / "scripts" / "check-readme-sync.sh")],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr


# --- behavioural checks against a local fixture repo -------------------------------------


@pytest.mark.integration
def test_sparse_install_produces_the_trimmed_tree(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    result = _install(driver, fixture_repo, tmp_path / "home")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "sparse, docs/ excluded" in result.stdout
    _assert_installed_tree(tmp_path / "home")


@pytest.mark.integration
def test_fallback_install_produces_an_identical_tree(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    # The fallback trims by allow-list, not by deleting docs/, so the two paths cannot
    # diverge when upstream adds a top-level directory.
    sparse_home = tmp_path / "sparse"
    fallback_home = tmp_path / "fallback"
    assert _install(driver, fixture_repo, sparse_home).returncode == 0
    result = _install(driver, fixture_repo, fallback_home, no_partial_clone=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Partial clone unavailable" in result.stdout

    sparse_tree = _assert_installed_tree(sparse_home)
    fallback_tree = _assert_installed_tree(fallback_home)
    listing = lambda root: sorted(  # noqa: E731 - terse local helper
        p.relative_to(root).as_posix() for p in root.rglob("*")
    )
    assert listing(sparse_tree) == listing(fallback_tree)


@pytest.mark.integration
def test_clone_retry_recovers_from_a_dirty_destination(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    # git leaves a partial directory behind when interrupted mid-transfer, and a second
    # clone into a non-empty path fails immediately. The retry wrapper therefore clears the
    # destination on every attempt; without that, attempt 2 could never succeed.
    home = tmp_path / "home"
    home.mkdir(parents=True)
    shim = home / "shim"
    shim.mkdir()
    counter = home / "attempts"
    (shim / "git").write_text(
        "#!/usr/bin/env bash\n"
        'for a in "$@"; do [[ "$a" == "--sparse" || "$a" == "--filter=blob:none" ]] '
        "&& exit 128; done\n"
        f'n=$(cat "{counter}" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "{counter}"\n'
        'if [[ "$n" -eq 1 ]]; then\n'
        '  dest="${@: -1}"\n'
        '  mkdir -p "$dest" && echo partial > "$dest/PARTIAL"\n'
        "  exit 1\n"
        "fi\n"
        f'exec {shutil.which("git")} "$@"\n',
        encoding="utf-8",
    )
    (shim / "git").chmod(0o755)

    result = subprocess.run(
        [
            "bash",
            "-c",
            f'source "{driver}"; LIEFLAT_REPO_URL="file://{fixture_repo}"; '
            "set +e; install_lieflat_charts; rc=$?; set -e; echo \"__RC__=$rc\"",
        ],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ | {"HOME": str(home), "PATH": f"{shim}:{os.environ['PATH']}"},
        cwd=str(ROOT),
        timeout=180,
    )
    assert "__RC__=0" in result.stdout, result.stdout + result.stderr
    assert int(counter.read_text().strip()) >= 2, "the first clone attempt must have failed"
    skill = _assert_installed_tree(home)
    assert not (skill / "PARTIAL").exists(), "the dirty first attempt must not survive"


@pytest.mark.integration
def test_install_overwrites_an_existing_directory(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    home = tmp_path / "home"
    stale = home / ".claude" / "skills" / "lieflat-charts"
    stale.mkdir(parents=True)
    (stale / "STALE.md").write_text("old\n", encoding="utf-8")

    assert _install(driver, fixture_repo, home).returncode == 0
    skill = _assert_installed_tree(home)
    assert not (skill / "STALE.md").exists()
    # No staging or retired scratch directory may be left behind anywhere under ~/.claude,
    # and staging must never sit inside skills/ where a partial copy could be loaded.
    leftovers = sorted(
        p.name
        for p in (home / ".claude").iterdir()
        if p.name.startswith(".lieflat-charts.scratch")
    )
    assert leftovers == [], leftovers
    assert not any(
        p.name.startswith(".lieflat-charts.")
        for p in (home / ".claude" / "skills").iterdir()
    )


def _shimmed_install(
    driver: Path, repo: Path, home: Path, name: str, body: str
) -> subprocess.CompletedProcess[str]:
    """Run the installer with one coreutil replaced, to force a mid-install failure."""
    home.mkdir(parents=True, exist_ok=True)
    shim = home / "shim"
    shim.mkdir(exist_ok=True)
    (shim / name).write_text(body, encoding="utf-8")
    (shim / name).chmod(0o755)
    return subprocess.run(
        [
            "bash",
            "-c",
            f'source "{driver}"; LIEFLAT_REPO_URL="file://{repo}"; '
            "set +e; install_lieflat_charts; rc=$?; set -e; echo \"__RC__=$rc\"",
        ],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ | {"HOME": str(home), "PATH": f"{shim}:{os.environ['PATH']}"},
        cwd=str(ROOT),
        timeout=180,
    )


@pytest.mark.integration
def test_failed_staging_copy_leaves_the_existing_install_untouched(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    home = tmp_path / "home"
    existing = home / ".claude" / "skills" / "lieflat-charts"
    existing.mkdir(parents=True)
    (existing / "SKILL.md").write_text("OLD\n", encoding="utf-8")

    result = _shimmed_install(
        driver, fixture_repo, home, "cp", "#!/usr/bin/env bash\nexit 1\n"
    )
    assert "__RC__=0" not in result.stdout, result.stdout
    # Staging before deleting is the whole point: the previous install must still be there.
    assert (existing / "SKILL.md").read_text(encoding="utf-8") == "OLD\n"
    assert not (home / ".claude" / MARKER_FILE).exists()
    assert not any(
        p.name.startswith(".lieflat-charts.") for p in (home / ".claude").iterdir()
    )


@pytest.mark.integration
def test_failed_swap_restores_the_retired_install(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    # The swap is retire -> move-in -> delete-retired. If the move-in fails, the retired
    # tree must come back; otherwise the user is left with no skill at all.
    home = tmp_path / "home"
    existing = home / ".claude" / "skills" / "lieflat-charts"
    existing.mkdir(parents=True)
    (existing / "SKILL.md").write_text("OLD\n", encoding="utf-8")
    counter = home / "mv-calls"

    result = _shimmed_install(
        driver,
        fixture_repo,
        home,
        "mv",
        "#!/usr/bin/env bash\n"
        f'n=$(cat "{counter}" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "{counter}"\n'
        "# 1st mv retires the old tree; fail the 2nd, which moves staging into place.\n"
        '[[ "$n" -eq 2 ]] && exit 1\n'
        f'exec {shutil.which("mv")} "$@"\n',
    )
    assert "__RC__=0" not in result.stdout, result.stdout
    assert (existing / "SKILL.md").read_text(encoding="utf-8") == "OLD\n"
    assert not (home / ".claude" / MARKER_FILE).exists()


@pytest.mark.integration
def test_failed_rollback_preserves_the_retired_copy(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    # If the move-in fails AND the rollback fails, the retired tree is the user's only
    # surviving copy. It must be left on disk and its path reported -- never cleaned up.
    home = tmp_path / "home"
    existing = home / ".claude" / "skills" / "lieflat-charts"
    existing.mkdir(parents=True)
    (existing / "SKILL.md").write_text("OLD\n", encoding="utf-8")
    counter = home / "mv-calls"

    result = _shimmed_install(
        driver,
        fixture_repo,
        home,
        "mv",
        "#!/usr/bin/env bash\n"
        f'n=$(cat "{counter}" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "{counter}"\n'
        "# 1 retires the old tree; 2 moves staging in; 3 is the rollback. Fail 2 and 3.\n"
        '[[ "$n" -ge 2 ]] && exit 1\n'
        f'exec {shutil.which("mv")} "$@"\n',
    )
    assert "__RC__=0" not in result.stdout, result.stdout
    output = result.stdout + result.stderr
    assert "move it back manually" in output, output
    scratch = [
        d for d in (home / ".claude").iterdir()
        if d.is_dir() and d.name.startswith(".lieflat-charts.scratch.")
    ]
    assert len(scratch) == 1, "the retired copy must survive a failed rollback"
    assert (scratch[0] / "retired" / "SKILL.md").read_text(encoding="utf-8") == "OLD\n"
    assert not (home / ".claude" / MARKER_FILE).exists()


@pytest.mark.integration
def test_a_preserved_backup_survives_a_retry_in_the_same_shell(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    # The recovery sequence: rollback fails and leaves a backup as the only copy, then the
    # user retries. Both runs happen in ONE shell here, so $$ is identical -- that is the
    # case a PID-derived scratch name would collide on, deleting the very copy it preserved.
    home = tmp_path / "home"
    existing = home / ".claude" / "skills" / "lieflat-charts"
    existing.mkdir(parents=True)
    (existing / "SKILL.md").write_text("OLD\n", encoding="utf-8")
    # Managed upgrade: the marker is already present before the failing run.
    (home / ".claude" / MARKER_FILE).touch()

    shim = home / "shim"
    shim.mkdir()
    counter = home / "mv-calls"
    (shim / "mv").write_text(
        "#!/usr/bin/env bash\n"
        f'n=$(cat "{counter}" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "{counter}"\n'
        "# Run 1: 1 retires, 2 moves staging in, 3 rolls back. Fail 2 and 3 only, so the\n"
        "# retry that follows in the same shell succeeds.\n"
        '[[ "$n" -eq 2 || "$n" -eq 3 ]] && exit 1\n'
        f'exec {shutil.which("mv")} "$@"\n',
        encoding="utf-8",
    )
    (shim / "mv").chmod(0o755)

    result = subprocess.run(
        [
            "bash",
            "-c",
            f'source "{driver}"; LIEFLAT_REPO_URL="file://{fixture_repo}"; set +e; '
            'install_lieflat_charts; echo "__RUN1__=$?"; '
            'install_lieflat_charts; echo "__RUN2__=$?"',
        ],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ | {"HOME": str(home), "PATH": f"{shim}:{os.environ['PATH']}"},
        cwd=str(ROOT),
        timeout=180,
    )
    assert "__RUN1__=1" in result.stdout, result.stdout + result.stderr
    assert "__RUN2__=0" in result.stdout, result.stdout + result.stderr

    backups = [
        d / "retired"
        for d in (home / ".claude").iterdir()
        if d.is_dir() and d.name.startswith(".lieflat-charts.scratch.")
        and (d / "retired" / "SKILL.md").exists()
    ]
    assert len(backups) == 1, f"the preserved backup must survive the retry: {backups}"
    assert backups[0].joinpath("SKILL.md").read_text(encoding="utf-8") == "OLD\n"
    # The retry itself succeeded, so the canonical install and its marker are back.
    _assert_installed_tree(home)


@pytest.mark.integration
def test_failed_rollback_clears_a_stale_ownership_marker(
    driver: Path, fixture_repo: Path, tmp_path: Path
) -> None:
    # Upgrading a managed install: the marker already exists. If both the move-in and the
    # rollback fail, nothing managed is left at the canonical path, so the marker must go --
    # otherwise uninstall would later delete a replacement the user installed by hand.
    home = tmp_path / "home"
    existing = home / ".claude" / "skills" / "lieflat-charts"
    existing.mkdir(parents=True)
    (existing / "SKILL.md").write_text("OLD\n", encoding="utf-8")
    marker = home / ".claude" / MARKER_FILE
    marker.touch()
    counter = home / "mv-calls"

    result = _shimmed_install(
        driver,
        fixture_repo,
        home,
        "mv",
        "#!/usr/bin/env bash\n"
        f'n=$(cat "{counter}" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "{counter}"\n'
        '[[ "$n" -ge 2 ]] && exit 1\n'
        f'exec {shutil.which("mv")} "$@"\n',
    )
    assert "__RC__=0" not in result.stdout, result.stdout
    assert not existing.exists(), "precondition: the canonical path must be empty"
    assert not marker.exists(), "a marker with no managed tree behind it must be cleared"


@pytest.mark.integration
def test_failed_clone_leaves_no_marker_and_no_partial_install(
    driver: Path, tmp_path: Path
) -> None:
    # install_lieflat_charts is called as `... || true`, which disables errexit for the
    # whole function body. Every destructive step must therefore check its own status
    # rather than assume `set -e` will stop a failed install from reporting success.
    home = tmp_path / "home"
    result = _install(driver, tmp_path / "does-not-exist", home)
    assert result.returncode != 0
    assert "Failed to clone lieflat-charts" in (result.stdout + result.stderr)
    assert not (home / ".claude" / "skills" / "lieflat-charts").exists()
    assert not (home / ".claude" / MARKER_FILE).exists()


@pytest.mark.integration
@pytest.mark.parametrize("installer_managed", [True, False])
def test_uninstall_removes_only_what_the_installer_created(
    tmp_path: Path, installer_managed: bool
) -> None:
    home = tmp_path / ("managed" if installer_managed else "hand-installed")
    skill = home / ".claude" / "skills" / "lieflat-charts"
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text("fixture\n", encoding="utf-8")
    marker = home / ".claude" / MARKER_FILE
    if installer_managed:
        marker.touch()

    result = subprocess.run(
        ["bash", str(ROOT / "install.sh"), "--uninstall", "--force"],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ | {"HOME": str(home)},
        cwd=str(ROOT),
        timeout=180,
    )
    assert result.returncode == 0, result.stderr

    if installer_managed:
        assert not skill.exists()
        assert not marker.exists()
    else:
        # A copy the user cloned by hand must survive an uninstall.
        assert (skill / "SKILL.md").read_text(encoding="utf-8") == "fixture\n"
        assert "not installed by this installer" in result.stdout


@pytest.mark.integration
def test_uninstall_keeps_the_skill_when_the_marker_cannot_be_cleared(tmp_path: Path) -> None:
    # ~/.claude read-only but skills/ writable: clearing the marker fails while deleting the
    # skill would succeed. Uninstall must decline to delete, or it leaves a marker with
    # nothing behind it and the next uninstall eats a hand-installed replacement.
    home = tmp_path / "home"
    claude = home / ".claude"
    skill = claude / "skills" / "lieflat-charts"
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text("managed\n", encoding="utf-8")
    marker = claude / MARKER_FILE
    marker.touch()
    claude.chmod(0o555)
    try:
        result = subprocess.run(
            ["bash", str(ROOT / "install.sh"), "--uninstall", "--force"],
            capture_output=True,
            text=True,
            check=False,
            env=os.environ | {"HOME": str(home)},
            cwd=str(ROOT),
            timeout=180,
        )
        assert result.returncode == 0, result.stderr
        assert marker.exists(), "precondition: the marker must have resisted removal"
        assert (skill / "SKILL.md").read_text(encoding="utf-8") == "managed\n"
        assert "could not be cleared" in result.stdout
    finally:
        claude.chmod(0o755)


@pytest.mark.integration
def test_uninstall_from_a_sourceless_checkout_still_spares_a_hand_install(
    tmp_path: Path,
) -> None:
    # When install.sh cannot see its own skills/ directory, uninstall falls back to removing
    # the whole skills/ tree. That sweep must not swallow the hand-installed copy the marker
    # guard exists to protect. detect_script_dir normally makes this branch unreachable --
    # it either finds a local clone or downloads a tarball -- so the fixture below supplies
    # a CLAUDE.md (marking a local clone) with no skills/ beside it.
    workdir = tmp_path / "sourceless"
    workdir.mkdir()
    shutil.copy2(ROOT / "install.sh", workdir / "install.sh")
    (workdir / "CLAUDE.md").write_text("# fixture clone\n", encoding="utf-8")
    assert not (workdir / "skills").exists()

    home = tmp_path / "home"
    skill = home / ".claude" / "skills" / "lieflat-charts"
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text("hand\n", encoding="utf-8")
    other = home / ".claude" / "skills" / "some-other-skill"
    other.mkdir(parents=True)
    (other / "SKILL.md").write_text("other\n", encoding="utf-8")

    result = subprocess.run(
        ["bash", str(workdir / "install.sh"), "--uninstall", "--force"],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ | {"HOME": str(home)},
        cwd=str(workdir),
        timeout=180,
    )
    assert result.returncode == 0, result.stderr
    assert (skill / "SKILL.md").read_text(encoding="utf-8") == "hand\n"
    assert not other.exists(), "the sweep must still remove everything else"


@pytest.mark.integration
def test_bash_installer_dry_run_all_announces_license_and_target(tmp_path: Path) -> None:
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
        timeout=180,
    )
    assert result.returncode == 0, result.stderr
    assert LICENSE_NAME in result.stdout
    assert f"{UPSTREAM_URL}/blob/main/LICENSE" in result.stdout
    assert "Would install skill: lieflat-charts" in result.stdout
    assert MARKER_FILE in result.stdout
    # The notice must precede the install line, not trail it.
    assert result.stdout.index(LICENSE_NAME) < result.stdout.index(
        "Would install skill: lieflat-charts"
    )
    # A dry run must not touch the filesystem.
    assert not (dry_home / ".claude" / "skills" / "lieflat-charts").exists()
    assert not (dry_home / ".claude" / MARKER_FILE).exists()


@pytest.mark.integration
def test_powershell_installer_parses() -> None:
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


@pytest.mark.integration
@pytest.mark.skipif(
    not os.environ.get("LIEFLAT_REQUIRE_NETWORK"),
    reason="set LIEFLAT_REQUIRE_NETWORK=1 to check the sparse allow-list against upstream",
)
def test_sparse_allowlist_covers_every_upstream_top_level_directory() -> None:
    # The sparse checkout is an allow-list, so a new top-level directory upstream would be
    # skipped silently. No offline test can see that; this one can.
    #
    # No `recursive` parameter: GitHub treats any value as truthy, so passing recursive=0
    # would return the whole tree and drown the top-level comparison.
    api = "https://api.github.com/repos/larashero3-dotcom/lieflat-charts/git/trees/main"
    request = urllib.request.Request(
        api, headers={"Accept": "application/vnd.github+json"}
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            tree = json.load(response)
    except urllib.error.HTTPError as exc:  # rate limit or outage, not a code defect
        pytest.skip(f"GitHub API unavailable: {exc}")
    except urllib.error.URLError as exc:
        pytest.skip(f"network unavailable: {exc}")

    upstream_dirs = {entry["path"] for entry in tree["tree"] if entry["type"] == "tree"}
    unclassified = upstream_dirs - set(EXPECTED_SPARSE_DIRS) - {EXCLUDED_DIR}
    assert not unclassified, (
        "upstream's top-level layout changed: "
        f"{sorted(unclassified)} is neither allow-listed nor the known-excluded "
        f"'{EXCLUDED_DIR}'. Decide whether each belongs in LIEFLAT_SPARSE_DIRS (runtime "
        "content) or in the exclusion set (docs, CI, website), then update both installers "
        "and this test."
    )
