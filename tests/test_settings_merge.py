"""Regression tests for the Bash settings.json smart-merge.

These cover two bugs that shipped undetected because nothing exercised the real
merge end-to-end:

1. Tombstoned plugins (``PLUGINS_REMOVED``) were deleted *before* the final
   ``($base * $over) * {...}`` merge. Because jq's ``*`` is a recursive merge, the
   user's existing ``enabledPlugins`` re-introduced every deleted key — so on
   Linux/macOS no tombstone had ever actually taken effect.

2. ``($base.env // {}) * ($over.env // {}) as $env`` was missing its outer
   parentheses. ``as`` binds looser than ``*``, so the rest of the filter was
   swallowed into the multiplication and the env keys were also written to the
   top level of settings.json.

The tests drive the real ``install_settings`` function out of install.sh rather
than re-implementing the filter, so they fail if the shipped merge regresses.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]

# Plugins removed in 3.0.0, tombstoned via PLUGINS_REMOVED.
TOMBSTONED = (
    "feature-dev@claude-plugins-official",
    "ralph-loop@claude-plugins-official",
    "commit-commands@claude-plugins-official",
    "github@claude-plugins-official",
    "pua@pua-skills",
)

THIRD_PARTY = "some-third-party@randomguy"


def _run_install_settings(home: Path) -> dict:
    """Source install.sh (without running main) and invoke install_settings."""
    script = f"""
        set -euo pipefail
        # Load install.sh definitions without executing main()
        eval "$(sed '/^main "$@"/d; /^main$/d' {ROOT / "install.sh"})"
        SCRIPT_DIR={ROOT}
        CLAUDE_DIR="$HOME/.claude"
        INSTALL_PLUGINS=true
        INSTALL_STATUSLINE=true
        INSTALL_LESSONS=true
        DRY_RUN=false
        USE_AUTO_MODE=true
        SELECTED_PLUGINS=("context7@claude-plugins-official")
        PLUGIN_GROUPS=()
        install_settings
    """
    env = dict(os.environ, HOME=str(home))
    proc = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
        env=env,
        timeout=120,
    )
    assert proc.returncode == 0, f"install_settings failed:\n{proc.stdout}\n{proc.stderr}"
    return json.loads((home / ".claude" / "settings.json").read_text(encoding="utf-8"))


@pytest.fixture
def upgraded_settings(tmp_path: Path) -> dict:
    """Simulate upgrading a user who has all five removed plugins enabled."""
    home = tmp_path / "home"
    (home / ".claude").mkdir(parents=True)
    existing = {
        "model": "sonnet",
        "env": {"MY_OWN_VAR": "keepme"},
        "enabledPlugins": {
            **{name: True for name in TOMBSTONED if name != "pua@pua-skills"},
            "pua@pua-skills": False,
            "context7@claude-plugins-official": True,
            THIRD_PARTY: True,
        },
    }
    (home / ".claude" / "settings.json").write_text(
        json.dumps(existing, indent=2), encoding="utf-8"
    )
    return _run_install_settings(home)


@pytest.mark.skipif(shutil.which("jq") is None, reason="jq required for smart merge")
@pytest.mark.integration
class TestTombstoneStripping:
    def test_removed_plugins_are_stripped_on_upgrade(self, upgraded_settings: dict) -> None:
        plugins = upgraded_settings["enabledPlugins"]
        still_present = [name for name in TOMBSTONED if name in plugins]
        assert not still_present, (
            "tombstoned plugins survived the merge — the strip must run on the "
            f"final merged object, after the recursive `*`: {still_present}"
        )

    def test_third_party_plugin_is_preserved(self, upgraded_settings: dict) -> None:
        # The installer promises never to silently disable plugins it doesn't own.
        assert upgraded_settings["enabledPlugins"].get(THIRD_PARTY) is True

    def test_selected_plugin_stays_enabled(self, upgraded_settings: dict) -> None:
        assert upgraded_settings["enabledPlugins"]["context7@claude-plugins-official"] is True


@pytest.mark.skipif(shutil.which("jq") is None, reason="jq required for smart merge")
@pytest.mark.integration
class TestEnvMerge:
    def test_user_env_is_preserved(self, upgraded_settings: dict) -> None:
        assert upgraded_settings["env"]["MY_OWN_VAR"] == "keepme"

    def test_shipped_env_defaults_are_applied(self, upgraded_settings: dict) -> None:
        shipped = json.loads((ROOT / "settings.json").read_text(encoding="utf-8"))
        for key, value in shipped.get("env", {}).items():
            assert upgraded_settings["env"][key] == value

    def test_env_keys_do_not_leak_to_top_level(self, upgraded_settings: dict) -> None:
        # Regression: missing parens around the env merge hoisted these to the root.
        leaked = [key for key in upgraded_settings["env"] if key in upgraded_settings]
        assert not leaked, f"env keys leaked to the top level of settings.json: {leaked}"


@pytest.mark.skipif(shutil.which("jq") is None, reason="jq required for smart merge")
@pytest.mark.integration
def test_tombstones_cover_every_plugin_removed_from_settings(tmp_path: Path) -> None:
    """Any plugin dropped from the shipped settings.json must be tombstoned.

    Otherwise upgrading users keep the orphaned key forever, since the merge
    preserves keys it does not recognise.
    """
    bash = (ROOT / "install.sh").read_text(encoding="utf-8")
    removed_block = bash.split("PLUGINS_REMOVED=(", 1)[1].split(")", 1)[0]
    tombstones = set(part.strip('"') for part in removed_block.split() if "@" in part)
    assert set(TOMBSTONED) <= tombstones, (
        f"missing tombstones: {set(TOMBSTONED) - tombstones}"
    )

    shipped = json.loads((ROOT / "settings.json").read_text(encoding="utf-8"))
    for name in TOMBSTONED:
        assert name not in shipped.get("enabledPlugins", {}), (
            f"{name} is tombstoned but still shipped in settings.json"
        )
