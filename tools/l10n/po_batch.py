#!/usr/bin/env python3
"""Add a batch of translations to a language's .po without touching the rest of it.

The .po (game/locale/<code>.po) is the one home of a translation: Poedit or a hand edit may
change any entry, and this tool keeps every line it is not told to change (comments, flags,
references, the order, wrapping). It only

* `todo`  lists what the template has and the .po does not translate yet (none, empty or
  fuzzy), one line each: `<key>\\t<source>\\t<where>  <notes>`; `--from data/oldpine` keeps the
  messages used there (a substring of a `#:` reference), `--limit N` the first N;
* `apply` reads a batch, one line each: `<key>\\t<translation>` (or `=<source>\\t<translation>`
  for a message by its text, every context of it), and sets those msgstr: an entry already
  there is changed in place and loses its fuzzy flag, a new one is added at the end;
* `sync`  turns an entry the template no longer has into an obsolete one (`#~`, as msgmerge and
  Poedit do), so a changed source line can be translated again from `todo`.

A key is the first 8 hex digits of sha1(msgctxt + "\\x04" + msgid): the same message has the
same key in every listing. In both files `\\n` stands for a line break; `#` lines and blank
lines in a batch are skipped. `check_po.py` checks the result.

    python tools/l10n/po_batch.py todo  game/locale/en.po --from data/oldpine > build/l10n/todo.tsv
    python tools/l10n/po_batch.py apply game/locale/en.po build/l10n/batch.tsv
    python tools/l10n/po_batch.py sync  game/locale/en.po
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_po import POT, _unquote  # noqa: E402

FIELD = re.compile(r'^(msgctxt|msgid|msgstr)\s+"(.*)"\s*$')


@dataclass
class Block:
    """One entry of a .po as written: its lines, and what they say."""

    lines: list[str]
    ctx: str = ""
    msgid: str | None = None
    msgstr: str = ""
    refs: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    fuzzy: bool = False
    changed: bool = False

    @property
    def is_message(self) -> bool:
        return bool(self.msgid)


def key_of(ctx: str, msgid: str) -> str:
    return hashlib.sha1((ctx + "\x04" + msgid).encode("utf-8")).hexdigest()[:8]


def _read(lines: list[str]) -> Block:
    block = Block(lines)
    parts: dict[str, list[str]] = {}
    current = None
    for raw in lines:
        line = raw.strip()
        if line.startswith("#:"):
            block.refs += line[2:].split()
        elif line.startswith("#."):
            block.notes.append(line[2:].strip())
        elif line.startswith("#,"):
            block.fuzzy = "fuzzy" in [flag.strip() for flag in line[2:].split(",")]
        elif line.startswith("#"):
            continue
        elif match := FIELD.match(line):
            current = match.group(1)
            parts[current] = [match.group(2)]
        elif line.startswith('"') and current:
            parts[current].append(line[1:-1])
    if "msgid" in parts:
        block.ctx = _unquote(parts.get("msgctxt", []))
        block.msgid = _unquote(parts["msgid"])
        block.msgstr = _unquote(parts.get("msgstr", []))
    return block


def parse(text: str) -> list[Block]:
    blocks, lines = [], []
    for raw in text.splitlines():
        if raw.strip():
            lines.append(raw)
        elif lines:
            blocks.append(_read(lines))
            lines = []
    if lines:
        blocks.append(_read(lines))
    return blocks


def quote(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t").replace("\n", "\\n") + '"'


def _rewrite(block: Block) -> list[str]:
    """The block's lines with its new msgstr: comments kept, fuzzy and the old source (#|) gone."""
    out = []
    in_msgstr = False
    for raw in block.lines:
        line = raw.strip()
        if line.startswith("#|"):
            continue
        if line.startswith("#,"):
            flags = [flag.strip() for flag in line[2:].split(",") if flag.strip() and flag.strip() != "fuzzy"]
            if flags:
                out.append("#, " + ", ".join(flags))
            continue
        if line.startswith("msgstr"):
            in_msgstr = True
            out.append("msgstr " + quote(block.msgstr))
            continue
        if in_msgstr and line.startswith('"'):
            continue
        in_msgstr = False
        out.append(raw)
    return out


def write(blocks: list[Block]) -> str:
    chunks = ["\n".join(_rewrite(b) if b.changed else b.lines) for b in blocks]
    return "\n\n".join(chunks) + "\n"


def _escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")


def _unescape(text: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), text)


def _template() -> list[Block]:
    return [b for b in parse(POT.read_text(encoding="utf-8")) if b.is_message]


def todo(po: list[Block], template: list[Block], where: list[str], limit: int) -> list[str]:
    done = {(b.ctx, b.msgid) for b in po if b.is_message and b.msgstr and not b.fuzzy}
    out = []
    for entry in template:
        if (entry.ctx, entry.msgid) in done:
            continue
        if where and not any(w in ref for w in where for ref in entry.refs):
            continue
        place = " ".join(entry.refs[:2]) + (" …" if len(entry.refs) > 2 else "")
        if entry.ctx:
            place = f"[{entry.ctx}] {place}"
        notes = " / ".join(entry.notes)
        out.append(f"{key_of(entry.ctx, entry.msgid)}\t{_escape(entry.msgid)}\t{place}" + (f"  # {notes}" if notes else ""))
        if limit and len(out) >= limit:
            break
    return out


def apply(po: list[Block], template: list[Block], batch: str) -> tuple[int, int, list[str]]:
    by_key = {key_of(b.ctx, b.msgid): b for b in template}
    by_text: dict[str, list[Block]] = {}
    for b in template:
        by_text.setdefault(b.msgid, []).append(b)
    wanted: dict[tuple[str, str], str] = {}
    errors = []
    for number, raw in enumerate(batch.splitlines(), 1):
        if not raw.strip() or raw.startswith("#"):
            continue
        if "\t" not in raw:
            errors.append(f"line {number}: no tab between the key and the translation")
            continue
        key, text = raw.split("\t", 1)
        text = _unescape(text.rstrip("\r"))
        if key.startswith("="):
            sources = by_text.get(_unescape(key[1:]), [])
        else:
            sources = [by_key[key]] if key in by_key else []
        if not sources:
            errors.append(f"line {number}: {key[:40]!r} is not in the template")
        for source in sources:
            wanted[(source.ctx, source.msgid)] = text
    if errors:
        return 0, 0, errors
    changed = added = 0
    have = {(b.ctx, b.msgid): b for b in po if b.is_message}
    for (ctx, msgid), text in wanted.items():
        block = have.get((ctx, msgid))
        if block is None:
            lines = (["msgctxt " + quote(ctx)] if ctx else []) + ["msgid " + quote(msgid), "msgstr " + quote(text)]
            po.append(Block(lines, ctx, msgid, text))
            added += 1
        elif block.msgstr != text or block.fuzzy:
            block.msgstr, block.fuzzy, block.changed = text, False, True
            changed += 1
    return changed, added, []


def sync(po: list[Block], template: list[Block]) -> int:
    known = {(b.ctx, b.msgid) for b in template}
    gone = 0
    for block in po:
        if block.is_message and (block.ctx, block.msgid) not in known:
            block.lines = [line if line.startswith("#") else "#~ " + line for line in block.lines if not line.startswith("#:")]
            block.msgid = None
            gone += 1
    return gone


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["todo", "apply", "sync"])
    parser.add_argument("po", type=Path)
    parser.add_argument("batch", type=Path, nargs="?")
    parser.add_argument("--from", dest="where", action="append", default=[])
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args(argv)
    po = parse(args.po.read_text(encoding="utf-8"))
    template = _template()
    if args.command == "todo":
        sys.stdout.reconfigure(encoding="utf-8")
        print("\n".join(todo(po, template, args.where, args.limit)))
        return 0
    if args.command == "apply":
        if args.batch is None:
            parser.error("apply needs a batch file")
        changed, added, errors = apply(po, template, args.batch.read_text(encoding="utf-8"))
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print(f"{args.po.name}: {changed} changed, {added} added")
    else:
        print(f"{args.po.name}: {sync(po, template)} made obsolete")
    args.po.write_text(write(po), encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
