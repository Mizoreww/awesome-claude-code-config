#!/usr/bin/env python3
"""codex-mem: Codex-native persistent memory CLI.

A lightweight local memory layer inspired by claude-mem:
- Record observations (feature/bugfix/decision/discovery/...)
- Search memory by keyword and metadata
- Build timeline around an anchor observation
- Generate auto-loaded MEMORY.md context for Codex
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import textwrap
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence

DEFAULT_DB = Path("~/.codex/memory/codex_mem.db").expanduser()
DEFAULT_MEMORY_FILE = Path("~/.codex/MEMORY.md").expanduser()
DEFAULT_LESSONS_FILE = Path("~/.codex/lessons.md").expanduser()

OBS_TYPES = {
    "bugfix",
    "feature",
    "decision",
    "discovery",
    "change",
    "summary",
    "note",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def normalize_project(project: str | None) -> str:
    if project and project.strip():
        return project.strip()
    return str(Path.cwd().resolve())


def connect_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS sessions (
          session_id TEXT PRIMARY KEY,
          project TEXT NOT NULL,
          started_at TEXT NOT NULL,
          ended_at TEXT,
          summary TEXT NOT NULL DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS observations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          project TEXT NOT NULL,
          session_id TEXT,
          obs_type TEXT NOT NULL,
          title TEXT NOT NULL,
          details TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '',
          files TEXT NOT NULL DEFAULT '',
          importance INTEGER NOT NULL DEFAULT 3 CHECK(importance BETWEEN 1 AND 5),
          FOREIGN KEY (session_id) REFERENCES sessions(session_id)
        );

        CREATE INDEX IF NOT EXISTS idx_observations_project_time
        ON observations(project, created_at DESC, id DESC);

        CREATE INDEX IF NOT EXISTS idx_observations_type
        ON observations(obs_type);
        """
    )
    return conn


def parse_ids(raw_ids: Sequence[str]) -> list[int]:
    values: list[int] = []
    for chunk in raw_ids:
        for item in chunk.split(","):
            item = item.strip()
            if not item:
                continue
            try:
                values.append(int(item))
            except ValueError as exc:
                raise ValueError(f"Invalid observation id: {item}") from exc
    if not values:
        raise ValueError("At least one observation id is required")
    return values


def rows_to_dicts(rows: Iterable[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(r) for r in rows]


def print_json(data: Any) -> None:
    print(json.dumps(data, ensure_ascii=False, indent=2))


def format_table(rows: Sequence[dict[str, Any]], columns: Sequence[str]) -> str:
    if not rows:
        return "(no rows)"

    widths: dict[str, int] = {c: len(c) for c in columns}
    for row in rows:
        for col in columns:
            widths[col] = max(widths[col], len(str(row.get(col, ""))))

    header = " | ".join(col.ljust(widths[col]) for col in columns)
    sep = "-+-".join("-" * widths[col] for col in columns)
    lines = [header, sep]
    for row in rows:
        lines.append(" | ".join(str(row.get(col, "")).ljust(widths[col]) for col in columns))
    return "\n".join(lines)


def ensure_session(conn: sqlite3.Connection, session_id: str, project: str) -> None:
    exists = conn.execute(
        "SELECT 1 FROM sessions WHERE session_id = ? LIMIT 1", (session_id,)
    ).fetchone()
    if exists:
        return
    conn.execute(
        "INSERT INTO sessions(session_id, project, started_at) VALUES(?, ?, ?)",
        (session_id, project, utc_now()),
    )


def cmd_init(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    conn = connect_db(db_path)
    conn.close()
    print(f"Initialized codex-mem database: {db_path}")
    return 0


def cmd_start_session(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    project = normalize_project(args.project)
    conn = connect_db(db_path)

    session_id = args.session_id or f"codex-{int(time.time())}"
    conn.execute(
        """
        INSERT INTO sessions(session_id, project, started_at)
        VALUES(?, ?, ?)
        ON CONFLICT(session_id)
        DO UPDATE SET project=excluded.project
        """,
        (session_id, project, utc_now()),
    )
    conn.commit()
    conn.close()

    payload = {"session_id": session_id, "project": project}
    if args.json:
        print_json(payload)
    else:
        print(f"session_id={session_id} project={project}")
    return 0


def cmd_end_session(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    conn = connect_db(db_path)

    row = conn.execute(
        "SELECT session_id, project FROM sessions WHERE session_id = ?", (args.session_id,)
    ).fetchone()
    if not row:
        project = normalize_project(args.project)
        conn.execute(
            "INSERT INTO sessions(session_id, project, started_at, ended_at, summary) VALUES(?, ?, ?, ?, ?)",
            (args.session_id, project, utc_now(), utc_now(), args.summary or ""),
        )
    else:
        conn.execute(
            "UPDATE sessions SET ended_at = ?, summary = COALESCE(?, summary) WHERE session_id = ?",
            (utc_now(), args.summary, args.session_id),
        )

    conn.commit()
    conn.close()
    print(f"Ended session: {args.session_id}")
    return 0


def cmd_note(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    project = normalize_project(args.project)
    obs_type = args.obs_type.strip().lower()
    if obs_type not in OBS_TYPES:
        raise ValueError(f"Unsupported type '{obs_type}'. Allowed: {', '.join(sorted(OBS_TYPES))}")

    conn = connect_db(db_path)
    if args.session_id:
        ensure_session(conn, args.session_id, project)

    cur = conn.execute(
        """
        INSERT INTO observations(created_at, project, session_id, obs_type, title, details, tags, files, importance)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            utc_now(),
            project,
            args.session_id,
            obs_type,
            args.title.strip(),
            args.details.strip(),
            args.tags.strip(),
            args.files.strip(),
            args.importance,
        ),
    )
    conn.commit()
    inserted_id = int(cur.lastrowid)
    conn.close()

    payload = {
        "id": inserted_id,
        "project": project,
        "type": obs_type,
        "title": args.title.strip(),
    }
    if args.json:
        print_json(payload)
    else:
        print(f"Recorded observation #{inserted_id}: {args.title.strip()}")
    return 0


def build_where_clause(args: argparse.Namespace) -> tuple[str, list[Any]]:
    clauses = ["1=1"]
    params: list[Any] = []

    if args.project:
        clauses.append("project = ?")
        params.append(args.project.strip())

    if getattr(args, "obs_type", None):
        clauses.append("obs_type = ?")
        params.append(args.obs_type.strip().lower())

    if getattr(args, "query", None):
        pattern = f"%{args.query.strip()}%"
        clauses.append("(title LIKE ? OR details LIKE ? OR tags LIKE ? OR files LIKE ?)")
        params.extend([pattern, pattern, pattern, pattern])

    return " AND ".join(clauses), params


def cmd_search(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    conn = connect_db(db_path)

    where, params = build_where_clause(args)
    params.extend([args.limit, args.offset])

    rows = conn.execute(
        f"""
        SELECT id, created_at, project, obs_type, importance, title, tags, files
        FROM observations
        WHERE {where}
        ORDER BY created_at DESC, id DESC
        LIMIT ? OFFSET ?
        """,
        params,
    ).fetchall()
    conn.close()

    data = rows_to_dicts(rows)
    if args.json:
        print_json(data)
    else:
        print(
            format_table(
                data,
                ["id", "created_at", "obs_type", "importance", "title", "project"],
            )
        )
    return 0


def cmd_get(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    ids = parse_ids(args.ids)
    placeholders = ",".join("?" for _ in ids)

    conn = connect_db(db_path)
    rows = conn.execute(
        f"""
        SELECT id, created_at, project, session_id, obs_type, importance, title, details, tags, files
        FROM observations
        WHERE id IN ({placeholders})
        ORDER BY created_at DESC, id DESC
        """,
        ids,
    ).fetchall()
    conn.close()

    data = rows_to_dicts(rows)
    if args.json:
        print_json(data)
    else:
        for row in data:
            print(f"# {row['id']} | {row['obs_type']} | {row['created_at']} | project={row['project']}")
            print(f"title: {row['title']}")
            if row.get("tags"):
                print(f"tags: {row['tags']}")
            if row.get("files"):
                print(f"files: {row['files']}")
            print("details:")
            print(textwrap.indent(str(row["details"]), prefix="  "))
            print()
    return 0


def pick_anchor(conn: sqlite3.Connection, args: argparse.Namespace) -> sqlite3.Row | None:
    if args.anchor_id is not None:
        if args.project:
            return conn.execute(
                "SELECT * FROM observations WHERE id = ? AND project = ?",
                (args.anchor_id, args.project.strip()),
            ).fetchone()
        return conn.execute(
            "SELECT * FROM observations WHERE id = ?",
            (args.anchor_id,),
        ).fetchone()

    if args.query:
        where, params = build_where_clause(args)
        params.extend([1, 0])
        return conn.execute(
            f"""
            SELECT * FROM observations
            WHERE {where}
            ORDER BY created_at DESC, id DESC
            LIMIT ? OFFSET ?
            """,
            params,
        ).fetchone()

    return None


def cmd_timeline(args: argparse.Namespace) -> int:
    if args.anchor_id is None and not args.query:
        raise ValueError("timeline requires --anchor-id or --query")

    db_path = Path(args.db).expanduser()
    conn = connect_db(db_path)
    anchor = pick_anchor(conn, args)
    if not anchor:
        conn.close()
        if args.json:
            print_json({"anchor": None, "timeline": []})
        else:
            print("No anchor observation found.")
        return 0

    project = str(anchor["project"])
    created_at = str(anchor["created_at"])
    anchor_id = int(anchor["id"])

    before = conn.execute(
        """
        SELECT id, created_at, project, obs_type, importance, title
        FROM observations
        WHERE project = ?
          AND (created_at < ? OR (created_at = ? AND id < ?))
        ORDER BY created_at DESC, id DESC
        LIMIT ?
        """,
        (project, created_at, created_at, anchor_id, args.depth_before),
    ).fetchall()

    after = conn.execute(
        """
        SELECT id, created_at, project, obs_type, importance, title
        FROM observations
        WHERE project = ?
          AND (created_at > ? OR (created_at = ? AND id > ?))
        ORDER BY created_at ASC, id ASC
        LIMIT ?
        """,
        (project, created_at, created_at, anchor_id, args.depth_after),
    ).fetchall()

    conn.close()

    before_rows = list(reversed(rows_to_dicts(before)))
    anchor_row = {
        "id": anchor_id,
        "created_at": created_at,
        "project": project,
        "obs_type": str(anchor["obs_type"]),
        "importance": int(anchor["importance"]),
        "title": str(anchor["title"]),
        "anchor": True,
    }
    after_rows = rows_to_dicts(after)
    timeline = before_rows + [anchor_row] + after_rows

    if args.json:
        print_json({"anchor": anchor_id, "timeline": timeline})
    else:
        print(f"anchor={anchor_id} project={project}")
        print(format_table(timeline, ["id", "created_at", "obs_type", "importance", "title"]))
    return 0


def cmd_recent(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    conn = connect_db(db_path)

    if args.project:
        rows = conn.execute(
            """
            SELECT id, created_at, project, obs_type, importance, title
            FROM observations
            WHERE project = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            (args.project.strip(), args.limit),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT id, created_at, project, obs_type, importance, title
            FROM observations
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            (args.limit,),
        ).fetchall()
    conn.close()

    data = rows_to_dicts(rows)
    if args.json:
        print_json(data)
    else:
        print(format_table(data, ["id", "created_at", "obs_type", "importance", "title", "project"]))
    return 0


def load_lesson_excerpt(lessons_file: Path, max_lines: int = 120) -> str:
    if not lessons_file.exists():
        return "_No lessons file found._"

    lines = lessons_file.read_text(encoding="utf-8").splitlines()
    meaningful = [ln.rstrip() for ln in lines if ln.strip() and not ln.strip().startswith("<!--")]
    if not meaningful:
        return "_Lessons file is empty._"

    return "\n".join(meaningful[-max_lines:])


def render_observation_markdown(row: dict[str, Any]) -> str:
    head = f"- **#{row['id']} [{row['obs_type']}] {row['title']}** (importance={row['importance']}, {row['created_at']})"
    detail = textwrap.shorten(str(row["details"]).replace("\n", " "), width=320, placeholder="…")
    lines = [head, f"  - project: `{row['project']}`", f"  - detail: {detail}"]
    if row.get("files"):
        lines.append(f"  - files: {row['files']}")
    if row.get("tags"):
        lines.append(f"  - tags: {row['tags']}")
    return "\n".join(lines)


def cmd_build_context(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    output = Path(args.output).expanduser()
    lessons_file = Path(args.lessons).expanduser()

    project = args.project.strip() if args.project else None

    conn = connect_db(db_path)

    if project:
        obs_rows = conn.execute(
            """
            SELECT id, created_at, project, obs_type, importance, title, details, tags, files
            FROM observations
            WHERE project = ?
            ORDER BY importance DESC, created_at DESC, id DESC
            LIMIT ?
            """,
            (project, args.obs_limit),
        ).fetchall()
        sess_rows = conn.execute(
            """
            SELECT session_id, project, started_at, ended_at, summary
            FROM sessions
            WHERE project = ? AND summary <> ''
            ORDER BY COALESCE(ended_at, started_at) DESC
            LIMIT ?
            """,
            (project, args.session_limit),
        ).fetchall()
    else:
        obs_rows = conn.execute(
            """
            SELECT id, created_at, project, obs_type, importance, title, details, tags, files
            FROM observations
            ORDER BY importance DESC, created_at DESC, id DESC
            LIMIT ?
            """,
            (args.obs_limit,),
        ).fetchall()
        sess_rows = conn.execute(
            """
            SELECT session_id, project, started_at, ended_at, summary
            FROM sessions
            WHERE summary <> ''
            ORDER BY COALESCE(ended_at, started_at) DESC
            LIMIT ?
            """,
            (args.session_limit,),
        ).fetchall()

    conn.close()

    lessons_excerpt = load_lesson_excerpt(lessons_file)
    obs = rows_to_dicts(obs_rows)
    sessions = rows_to_dicts(sess_rows)

    lines: list[str] = []
    lines.append("# MEMORY")
    lines.append("")
    lines.append("> Auto-generated by `codex-mem build-context`. Do not edit manually; update lessons/observations instead.")
    lines.append("")
    lines.append(f"- Generated at: `{utc_now()}`")
    lines.append(f"- Scope: `{project or 'global'}`")
    lines.append("")

    lines.append("## Active Lessons")
    lines.append("")
    lines.append(lessons_excerpt)
    lines.append("")

    lines.append("## Recent Session Summaries")
    lines.append("")
    if sessions:
        for row in sessions:
            summary = textwrap.shorten(str(row["summary"]).replace("\n", " "), width=240, placeholder="…")
            end_at = row.get("ended_at") or row.get("started_at")
            lines.append(
                f"- `{end_at}` [{row['project']}] `{row['session_id']}` — {summary}"
            )
    else:
        lines.append("_No session summaries yet._")
    lines.append("")

    lines.append("## High-Signal Observations")
    lines.append("")
    if obs:
        for row in obs:
            lines.append(render_observation_markdown(row))
    else:
        lines.append("_No observations yet._")
    lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")

    if args.json:
        print_json({"output": str(output), "observations": len(obs), "sessions": len(sessions)})
    else:
        print(f"Wrote context file: {output}")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    db_path = Path(args.db).expanduser()
    conn = connect_db(db_path)

    observation_count = int(conn.execute("SELECT COUNT(1) FROM observations").fetchone()[0])
    session_count = int(conn.execute("SELECT COUNT(1) FROM sessions").fetchone()[0])
    project_count = int(
        conn.execute("SELECT COUNT(DISTINCT project) FROM observations").fetchone()[0]
    )
    conn.close()

    payload = {
        "db": str(db_path),
        "observations": observation_count,
        "sessions": session_count,
        "projects": project_count,
    }
    if args.json:
        print_json(payload)
    else:
        for k, v in payload.items():
            print(f"{k}: {v}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="codex-mem",
        description="Codex-native persistent memory CLI",
    )
    parser.add_argument(
        "--db",
        default=str(DEFAULT_DB),
        help=f"SQLite path (default: {DEFAULT_DB})",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    sp = subparsers.add_parser("init", help="Initialize the memory database")
    sp.set_defaults(func=cmd_init)

    sp = subparsers.add_parser("start-session", help="Create/update a session entry")
    sp.add_argument("--session-id", help="Explicit session id")
    sp.add_argument("--project", help="Project scope (default: current absolute path)")
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_start_session)

    sp = subparsers.add_parser("end-session", help="End session and optionally save summary")
    sp.add_argument("--session-id", required=True, help="Session id")
    sp.add_argument("--summary", help="Session summary")
    sp.add_argument("--project", help="Project scope fallback when session does not exist")
    sp.set_defaults(func=cmd_end_session)

    sp = subparsers.add_parser("note", help="Record an observation")
    sp.add_argument("--project", help="Project scope (default: current absolute path)")
    sp.add_argument("--session-id", help="Optional session id")
    sp.add_argument(
        "--type",
        dest="obs_type",
        default="note",
        help=f"Observation type ({', '.join(sorted(OBS_TYPES))})",
    )
    sp.add_argument("--title", required=True, help="Short title")
    sp.add_argument("--details", required=True, help="Detailed note")
    sp.add_argument("--tags", default="", help="Comma-separated tags")
    sp.add_argument("--files", default="", help="Comma-separated file paths")
    sp.add_argument("--importance", type=int, choices=[1, 2, 3, 4, 5], default=3)
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_note)

    sp = subparsers.add_parser("search", help="Search observations")
    sp.add_argument("--project", help="Project filter")
    sp.add_argument("--type", dest="obs_type", help="Type filter")
    sp.add_argument("--query", required=True, help="Keyword query")
    sp.add_argument("--limit", type=int, default=20)
    sp.add_argument("--offset", type=int, default=0)
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_search)

    sp = subparsers.add_parser("get", help="Get full observations by ids")
    sp.add_argument("--ids", nargs="+", required=True, help="IDs (comma-separated or multiple args)")
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_get)

    sp = subparsers.add_parser("timeline", help="Show timeline around an anchor")
    sp.add_argument("--project", help="Project filter")
    sp.add_argument("--anchor-id", type=int, help="Anchor observation id")
    sp.add_argument("--query", help="Pick anchor automatically from search")
    sp.add_argument("--type", dest="obs_type", help="Type filter when using --query")
    sp.add_argument("--depth-before", type=int, default=5)
    sp.add_argument("--depth-after", type=int, default=5)
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_timeline)

    sp = subparsers.add_parser("recent", help="List recent observations")
    sp.add_argument("--project", help="Project filter")
    sp.add_argument("--limit", type=int, default=20)
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_recent)

    sp = subparsers.add_parser("build-context", help="Generate MEMORY.md for model_instructions_file")
    sp.add_argument("--project", help="Project filter (default: global)")
    sp.add_argument("--output", default=str(DEFAULT_MEMORY_FILE), help=f"Output file (default: {DEFAULT_MEMORY_FILE})")
    sp.add_argument("--lessons", default=str(DEFAULT_LESSONS_FILE), help=f"Lessons file (default: {DEFAULT_LESSONS_FILE})")
    sp.add_argument("--obs-limit", type=int, default=20)
    sp.add_argument("--session-limit", type=int, default=10)
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_build_context)

    sp = subparsers.add_parser("status", help="Show database summary")
    sp.add_argument("--json", action="store_true", help="Output JSON")
    sp.set_defaults(func=cmd_status)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # Defensive bound checks
    if hasattr(args, "limit") and args.limit is not None:
        args.limit = max(1, min(500, args.limit))
    if hasattr(args, "offset") and args.offset is not None:
        args.offset = max(0, args.offset)
    if hasattr(args, "depth_before") and args.depth_before is not None:
        args.depth_before = max(0, min(50, args.depth_before))
    if hasattr(args, "depth_after") and args.depth_after is not None:
        args.depth_after = max(0, min(50, args.depth_after))

    try:
        return int(args.func(args))
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
