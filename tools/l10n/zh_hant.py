#!/usr/bin/env python3
"""Traditional Chinese for game/locale/zh_Hant.po, made from the Simplified source text.

The .po is the one home of the translation (LOCALIZATION.md); this tool only drafts the
messages it does not translate yet, as a batch for `po_batch.py apply`:

* OpenCC s2tw turns the characters into Taiwan's standard forms (著, 裡, 麼) and changes no
  words: the story's written language is the same on both sides of the strait;
* tools/l10n/zh_hant_rules.tsv fixes what s2tw gets wrong here (a phrase keeps its place: 回雪亭
  is not 迴雪亭, 汗還沒乾 is not 幹), folds the variant forms s2tw mixes into one, and gives
  interface text the words a Taiwan player knows (設定, 視窗, 解析度);
* “ ” and ‘ ’ become 「 」 and 『 』, the marks the rest of the text uses.

`check` reads the .po back: every message converts back to its source (OpenCC tw2s) except
where a rule changed a word, so a hand edit that lost or changed text shows up.

OpenCC is a development tool only (pip install opencc); the game reads the .po.

    python tools/l10n/zh_hant.py draft game/locale/zh_Hant.po > build/l10n/zh_hant_batch.tsv
    python tools/l10n/po_batch.py apply game/locale/zh_Hant.po build/l10n/zh_hant_batch.tsv
    python tools/l10n/zh_hant.py check game/locale/zh_Hant.po
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from po_batch import Block, _escape, _template, key_of, parse  # noqa: E402

RULES = Path(__file__).resolve().parent / "zh_hant_rules.tsv"
# Interface text: anything said by code or a scene, and the 入门 guide in the 百科.
GUIDE_NOTE = "guide."


@dataclass
class Rules:
    phrases: list[tuple[str, str]] = field(default_factory=list)
    chars: dict[str, str] = field(default_factory=dict)
    ui: list[tuple[str, str]] = field(default_factory=list)


def load_rules(path: Path = RULES) -> Rules:
    rules = Rules()
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip() or raw.startswith("#"):
            continue
        kind, source, target = raw.split("\t")[:3]
        if kind == "phrase":
            if len(source) != len(target):
                raise ValueError(f"{path.name}:{number}: {source} and {target} differ in length")
            rules.phrases.append((source, target))
        elif kind == "char":
            rules.chars[source] = target
        elif kind == "ui":
            rules.ui.append((source, target))
        else:
            raise ValueError(f"{path.name}:{number}: unknown kind {kind!r}")
    rules.phrases.sort(key=lambda pair: len(pair[0]))
    return rules


def is_interface(entry: Block) -> bool:
    return any(not ref.startswith("data/") for ref in entry.refs) or any(
        note.startswith(GUIDE_NOTE) for note in entry.notes
    )


class Converter:
    def __init__(self, rules: Rules | None = None) -> None:
        import opencc  # a development tool: pip install opencc

        self.rules = load_rules() if rules is None else rules
        self._s2tw = opencc.OpenCC("s2tw")
        self._tw2s = opencc.OpenCC("tw2s")

    def convert(self, source: str, interface: bool = False) -> str:
        chars = list(self._s2tw.convert(source))
        if len(chars) != len(source):
            raise ValueError(f"s2tw changed the length of {source!r}")
        for simplified, traditional in self.rules.phrases:
            start = source.find(simplified)
            while start >= 0:
                chars[start : start + len(simplified)] = traditional
                start = source.find(simplified, start + 1)
        text = "".join(self.rules.chars.get(char, char) for char in chars)
        text = text.replace("“", "「").replace("”", "」")
        text = re.sub(r"‘([^‘’]*)’", r"『\1』", text)
        if interface:
            for word, taiwan in self.rules.ui:
                text = text.replace(word, taiwan)
        return text

    def back(self, text: str) -> str:
        return self._tw2s.convert(text)


def draft(po: list[Block], template: list[Block], converter: Converter) -> list[str]:
    done = {(b.ctx, b.msgid) for b in po if b.is_message and b.msgstr and not b.fuzzy}
    return [
        f"{key_of(entry.ctx, entry.msgid)}\t{_escape(converter.convert(entry.msgid, is_interface(entry)))}"
        for entry in template
        if (entry.ctx, entry.msgid) not in done
    ]


def check(po: list[Block], template: list[Block], converter: Converter) -> list[str]:
    """Messages whose Traditional text no longer says what the source says."""
    interface = {(b.ctx, b.msgid): is_interface(b) for b in template}
    problems = []
    for block in po:
        if not block.is_message or not block.msgstr or (block.ctx, block.msgid) not in interface:
            continue
        expected = converter.convert(block.msgid, interface[(block.ctx, block.msgid)])
        if block.msgstr == expected:
            continue
        if converter.back(block.msgstr) != converter.back(expected):
            problems.append(f"{key_of(block.ctx, block.msgid)}\t{_escape(block.msgid)}\t{_escape(block.msgstr)}")
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["draft", "check"])
    parser.add_argument("po", type=Path)
    args = parser.parse_args(argv)
    sys.stdout.reconfigure(encoding="utf-8")
    po = parse(args.po.read_text(encoding="utf-8"))
    converter = Converter()
    if args.command == "draft":
        print("\n".join(draft(po, _template(), converter)))
        return 0
    problems = check(po, _template(), converter)
    print("\n".join(problems) if problems else f"{args.po.name}: every message says what its source says")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
