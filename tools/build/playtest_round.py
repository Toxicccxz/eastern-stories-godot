#!/usr/bin/env python3
"""The mechanical part of a playtest round (docs/production/BUILD.md「试玩一轮」).

A round is played on one pinned commit of main, not on the shared checkout, so that nothing merged
during the round changes the game or breaks its saves:

    python tools/build/playtest_round.py cut [--name playtest-YYYY-MM-DD] [--dry-run]
        tag origin/main (an annotated tag naming its world revision), push the tag, and run the CI
        workflow by hand on it (workflow_dispatch) for the Windows ZIP;
    python tools/build/playtest_round.py fetch <tag> [--no-source]
        download that run's Windows artifact into build/playtest/<tag>/ and unpack the ZIP there
        (the game to play), and check the tag out beside it as a detached worktree
        (build/playtest/<tag>/source: the same code, for the dev starts at chapter N);
    python tools/build/playtest_round.py status <tag>
        what main has merged since the tag, and whether main's world revision moved (a build of
        main would then need a New Game: the round's saves would not load).

Standard library only; git and the GitHub CLI (gh) do the work. Nothing is deleted.
"""

from __future__ import annotations

import argparse
import datetime
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
WORKFLOW = "ci.yml"
ARTIFACT = "eastern-stories-godot-windows-x86_64"
ZIP_NAME = "Eastern-Stories-Godot-windows-x86_64.zip"
REVISION_FILE = "game/core/persistence/world_content_revision.gd"
REVISION_PATTERN = re.compile(r"^const CURRENT_PUBLIC: Value = Value\.(\w+)", re.MULTILINE)
TAG_PATTERN = re.compile(r"^playtest-[0-9A-Za-z._-]+$")


def run(command: list[str], dry_run: bool = False, capture: bool = True) -> str:
    """Runs `command` in the repository (printed first); its stdout. Dry runs only print it."""
    print("$ " + " ".join(command))
    if dry_run:
        return ""
    result = subprocess.run(command, cwd=REPOSITORY, check=True, text=True, encoding="utf-8", capture_output=capture)
    return result.stdout if capture else ""


def revision_at(ref: str) -> str:
    """The world revision (WorldContentRevision.CURRENT_PUBLIC) at `ref`."""
    return parse_revision(run(["git", "show", f"{ref}:{REVISION_FILE}"]))


def parse_revision(text: str) -> str:
    match = REVISION_PATTERN.search(text)
    if match is None:
        raise ValueError(f"no CURRENT_PUBLIC in {REVISION_FILE}")
    return match.group(1)


def default_name(today: datetime.date | None = None) -> str:
    return "playtest-" + (today or datetime.date.today()).isoformat()


def cut(name: str, dry_run: bool) -> int:
    if not TAG_PATTERN.match(name):
        print(f"a round's tag is playtest-<something>: {name}", file=sys.stderr)
        return 2
    run(["git", "fetch", "origin", "main", "--tags"])
    if run(["git", "ls-remote", "--tags", "origin", f"refs/tags/{name}"]).strip():
        print(f"the tag {name} is on origin already: fetch it, or cut another name", file=sys.stderr)
        return 2
    commit = run(["git", "rev-parse", "origin/main"]).strip()
    revision = revision_at(commit)
    if run(["git", "tag", "--list", name]).strip():
        # Made here by a cut whose push or dispatch failed: go on with it if it is still main's commit.
        tagged = run(["git", "rev-parse", f"{name}^{{commit}}"]).strip()
        if tagged != commit:
            print(f"the local tag {name} is on {tagged[:10]}, not origin/main's {commit[:10]}: delete it by hand or cut another name", file=sys.stderr)
            return 2
        print(f"the local tag {name} was never pushed: pushing it now")
    else:
        message = f"试玩一轮 {name}: main {commit[:10]}, world revision {revision}"
        run(["git", "tag", "-a", name, commit, "-m", message], dry_run)
    run(["git", "push", "origin", f"refs/tags/{name}"], dry_run)
    run(["gh", "workflow", "run", WORKFLOW, "--ref", name], dry_run)
    print(f"{name} = {commit} ({revision}). When the run is done: python tools/build/playtest_round.py fetch {name}")
    return 0


def run_for(tag: str) -> dict:
    """The newest CI run on `tag`."""
    rows = json.loads(run(["gh", "run", "list", "--workflow", WORKFLOW, "--branch", tag, "--limit", "1",
                           "--json", "databaseId,status,conclusion,headSha,url"]))
    if not rows:
        raise LookupError(f"no {WORKFLOW} run on {tag}: cut it first")
    return rows[0]


def fetch(tag: str, source: bool) -> int:
    row = run_for(tag)
    if row["status"] != "completed" or row["conclusion"] != "success":
        print(f"the run on {tag} is {row['status']} / {row['conclusion']}: {row['url']}", file=sys.stderr)
        return 1
    folder = REPOSITORY / "build" / "playtest" / tag
    folder.mkdir(parents=True, exist_ok=True)
    archive = folder / ZIP_NAME
    if not archive.exists():
        run(["gh", "run", "download", str(row["databaseId"]), "--name", ARTIFACT, "--dir", str(folder)])
    game = folder / "game"
    if not game.exists():
        # Unpacked aside and renamed when whole, so a broken unpack is never taken for the game.
        partial = folder / "game.partial"
        if partial.exists():
            print(f"{partial} is left from an unpack that stopped: remove it and fetch again", file=sys.stderr)
            return 1
        with zipfile.ZipFile(archive) as packed:
            packed.extractall(partial)
        partial.rename(game)
    if source and not (folder / "source").exists():
        run(["git", "worktree", "add", "--detach", str(folder / "source"), tag], capture=False)
    print(f"play: {game}  (the commit: {row['headSha']})")
    if source:
        print(f"chapter starts: open {folder / 'source' / 'game'} in Godot 4.7.2, tests/dev/chapter_start.tscn, F6")
    return 0


def status(tag: str) -> int:
    run(["git", "fetch", "origin", "main", "--tags"])
    pinned = revision_at(tag)
    current = revision_at("origin/main")
    merged = run(["git", "log", "--merges", "--first-parent", "--format=%h %s", f"{tag}..origin/main"]).strip()
    print(f"{tag}: world revision {pinned}")
    print(f"origin/main: world revision {current}")
    print("merged since the tag:\n" + (merged or "(nothing)"))
    if pinned == current:
        print("same revision: a build of main still loads the round's saves.")
    else:
        print("the revision moved: a build of main needs a New Game (the round's saves will not load).")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    cut_parser = commands.add_parser("cut", help="tag origin/main, push the tag, run CI on it")
    cut_parser.add_argument("--name", default=default_name())
    cut_parser.add_argument("--dry-run", action="store_true", help="print the tag, push and dispatch, do none of them")
    fetch_parser = commands.add_parser("fetch", help="download and unpack the tag's Windows ZIP")
    fetch_parser.add_argument("tag")
    fetch_parser.add_argument("--no-source", action="store_true", help="no worktree of the tag beside the game")
    status_parser = commands.add_parser("status", help="what main merged since the tag; did the world revision move")
    status_parser.add_argument("tag")
    arguments = parser.parse_args(argv)
    if arguments.command == "cut":
        return cut(arguments.name, arguments.dry_run)
    if arguments.command == "fetch":
        return fetch(arguments.tag, not arguments.no_source)
    return status(arguments.tag)


if __name__ == "__main__":
    sys.exit(main())
