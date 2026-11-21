#!/usr/bin/env python3
"""Check a translation (game/locale/<code>.po) against the template.

Godot loads the .po as it is, so a slip shows up only in play: a {slot} the game fills that
the translation lost, a translation of text the game no longer has, an ES2 token spelled
wrong. This catches them. Rules (docs/production/english_style.md):

* every msgid is in the template (with its msgctxt);
* the game's slots survive: %s and %d in the same number; $N $n $l $w $RESPECT $SELF when
  the source has them. A {name} slot may move or, where the language has no use for it,
  be left out (the template's header says so), but a translation may not invent one;
* English grammar marks ({N:a|b}, {n:his} …, MessageGrammar) are well formed, and an ES2
  pronoun token ($P, $p) is not used: English writes {N:his} / {n:him} instead;
* no text starts a sentence with $RESPECT or {respect}: the forms of address are lower case.

`python tools/l10n/check_po.py [game/locale/en.po ...]` prints the problems; exit 1 if any.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
POT = REPOSITORY / "game/locale/eastern_stories.pot"
PRINTF = re.compile(r"%[sd]")
TOKENS = ("$RESPECT", "$SELF", "$N", "$n", "$l", "$w")
SLOT = re.compile(r"\{([a-z_]+)\}")
GRAMMAR = re.compile(r"\{([Nn]):([^{}]*)\}")
PRONOUNS = {"he", "him", "his", "himself"}


def _unquote(chunks: list[str]) -> str:
    text = "".join(chunks)
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def parse(path: Path) -> list[tuple[str, str, str]]:
    """(msgctxt, msgid, msgstr) for each entry but the header."""
    entries = []
    field = None
    parts: dict[str, list[str]] = {}

    def flush():
        if "msgid" in parts:
            msgid = _unquote(parts["msgid"])
            if msgid:
                entries.append((_unquote(parts.get("msgctxt", [])), msgid, _unquote(parts.get("msgstr", []))))
        parts.clear()

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            if not line and parts:
                flush()
                field = None
            continue
        match = re.match(r'^(msgctxt|msgid|msgstr)\s+"(.*)"$', line)
        if match:
            if match.group(1) in ("msgctxt",) or (match.group(1) == "msgid" and "msgid" in parts):
                flush()
            field = match.group(1)
            parts[field] = [match.group(2)]
        elif line.startswith('"') and field:
            parts[field].append(line[1:-1])
    flush()
    return entries


def _count(text: str, token: str) -> int:
    # $n must not count the n of $N's neighbours: tokens are case-sensitive substrings.
    if token == "$n":
        return len(re.findall(r"\$n(?![a-zA-Z])", text))
    return text.count(token)


def problems_in(po: Path, pot: Path = POT) -> list[str]:
    known = {(ctx, msgid) for ctx, msgid, _ in parse(pot)}
    problems = []
    for ctx, msgid, msgstr in parse(po):
        where = f"{po.name}: {msgid[:40]!r}"
        if (ctx, msgid) not in known:
            problems.append(f"{where}: not in the template (gone or changed)")
            continue
        if not msgstr:
            continue
        if sorted(PRINTF.findall(msgid)) != sorted(PRINTF.findall(msgstr)):
            problems.append(f"{where}: %s/%d slots differ")
        for token in TOKENS:
            if _count(msgid, token) and not _count(msgstr, token):
                problems.append(f"{where}: lost {token}")
        if "$P" in msgstr or re.search(r"\$p(?![a-zA-Z])", msgstr):
            problems.append(f"{where}: $P/$p in a translation: write {{N:his}} / {{n:him}}")
        source_slots = set(SLOT.findall(msgid))
        for slot in SLOT.findall(GRAMMAR.sub("", msgstr)):
            if slot not in source_slots:
                problems.append(f"{where}: invents the slot {{{slot}}}")
        for role, body in GRAMMAR.findall(msgstr):
            if "|" in body:
                if body.count("|") != 1 or not all(body.split("|")):
                    problems.append(f"{where}: bad form {{{role}:{body}}}")
            elif body not in PRONOUNS:
                problems.append(f"{where}: unknown pronoun {{{role}:{body}}}")
            if role == "n" and _count(msgid, "$n") == 0 and not re.search(r"\$p(?![a-zA-Z])", msgid):
                problems.append(f"{where}: {{n:…}} in a line with no $n (nor $p)")
        if re.search(r"(^|[.!?]\s+|[“\"]\s*)(\$RESPECT|\{respect\})", msgstr):
            problems.append(f"{where}: a sentence opens with a form of address (it is lower case)")
    return problems


def main(argv: list[str]) -> int:
    paths = [Path(arg) for arg in argv] or sorted((REPOSITORY / "game/locale").glob("*.po"))
    found = []
    for path in paths:
        found.extend(problems_in(path))
    for problem in found:
        print(problem)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
