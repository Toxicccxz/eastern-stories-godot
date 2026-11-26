#!/usr/bin/env python3
"""List the lit words a translation lost (关键信息高亮, DECISIONS「关键信息高亮」).

A line of a scene may mark the words the player acts on after it (`keys`, NpcLine.keys). The game
lights each by putting the word into the shown language and looking for it in the shown line
(KeySpans): the line's own message ID carries no mark. So a word is lit in a language only when
that language's line writes the word as the word's own translation does; where it does not, the
word is simply not lit there. This lists those lines, language by language, for the translation
to look at: either the line says the word another way (change one of the two), or the language
has no use for the word there (leave it).

`python tools/l10n/check_keys.py [game/locale/en.po ...]` prints the list; exit 0 (it is a list to
read, not a gate). `--strict` exits 1 when anything is listed.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import check_po

REPOSITORY = Path(__file__).resolve().parents[2]
DATA = REPOSITORY / "game/data"
LOCALE = REPOSITORY / "game/locale"
WORD_JOINER = "⁠"
LINE_KINDS = ("say", "emote", "line", "whisper")


def marked_lines(data: Path = DATA) -> list[tuple[str, str, list[str]]]:
    """Every marked line of the content: (where, the line's text, its keys)."""
    found: list[tuple[str, str, list[str]]] = []
    for path in sorted(data.rglob("*.json")):
        try:
            document = json.loads(path.read_text(encoding="utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        _walk(document, path.relative_to(data).as_posix(), found)
    return found


def _walk(node: object, where: str, found: list[tuple[str, str, list[str]]]) -> None:
    if isinstance(node, list):
        for item in node:
            _walk(item, where, found)
    elif isinstance(node, dict):
        keys = node.get("keys")
        if isinstance(keys, list) and all(isinstance(key, str) for key in keys):
            for kind in LINE_KINDS:
                if isinstance(node.get(kind), str):
                    found.append((where, node[kind], keys))
        for value in node.values():
            _walk(value, where, found)


def _lettered(char: str) -> bool:
    return char.isascii() and char.isalnum()


def stands_in(line: str, word: str) -> bool:
    """Whether `word` stands in `line` as KeySpans looks for it: a whole word, in any case, where
    it is written in letters."""
    line = line.replace(WORD_JOINER, "")
    word = word.replace(WORD_JOINER, "").strip()
    if not word:
        return False
    if not (_lettered(word[0]) or _lettered(word[-1])):
        return word in line
    low, wanted = line.lower(), word.lower()
    start = low.find(wanted)
    while start >= 0:
        end = start + len(wanted)
        before = start > 0 and _lettered(word[0]) and _lettered(line[start - 1])
        after = end < len(line) and _lettered(word[-1]) and _lettered(line[end])
        if not before and not after:
            return True
        start = low.find(wanted, start + 1)
    return False


def lost_in(po: Path, lines: list[tuple[str, str, list[str]]]) -> list[str]:
    """The marked lines whose word the translation `po` does not have, one text a line."""
    entries = check_po.parse(po)
    translated = {msgid: msgstr for context, msgid, msgstr in entries if msgstr and not context}
    # A word's form as the line writes it (KeySpans.CONTEXT), where the translation gives one.
    lit = {msgid: msgstr for context, msgid, msgstr in entries if msgstr and context == "lit"}
    problems: list[str] = []
    for where, text, keys in lines:
        shown = translated.get(text)
        if shown is None:
            continue  # The line is not translated: it shows in Chinese, and so do its words.
        for key in keys:
            word = lit.get(key) or translated.get(key, key)
            if not stands_in(shown, word):
                problems.append(f"{po.name}: {where}: 「{key}」→「{word}」 is not in: {shown}")
    return problems


def lost_in_source(lines: list[tuple[str, str, list[str]]]) -> list[str]:
    """A marked word the authored line itself does not have (the loader refuses it too)."""
    return [f"{where}: 「{key}」 is not in: {text}" for where, text, keys in lines for key in keys if key not in text]


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    paths = [Path(arg) for arg in argv if not arg.startswith("--")] or sorted(LOCALE.glob("*.po"))
    lines = marked_lines()
    problems = lost_in_source(lines)
    for po in paths:
        problems += lost_in(po, lines)
    for problem in problems:
        print(problem)
    print(f"{len(lines)} marked line(s), {len(problems)} lit word(s) lost")
    return 1 if strict and problems else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
