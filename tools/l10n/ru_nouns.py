#!/usr/bin/env python3
"""Draft the Russian forms of the names the game fills into sentences (game/locale/ru_nouns.json).

Russian puts a name in a case (бандит, бандита, бандиту…) and agrees words with its gender; the
game picks the form once a line is filled (RussianText, docs/production/russian_style.md). This
drafts a row for every translated name in game/locale/ru.po that has none yet — a person, beast,
item, limb, weapon, place, school — and never changes a row that is there: the file is the
home of the forms, read and corrected by hand.

    "nominative": [gender, genitive, dative, accusative, instrumental, prepositional, few, many]

gender is м ж ср мн; few and many are the counted nominative after 2–4 and 5+; an empty form is
the nominative (an undeclined name). The draft uses pymorphy3 (`pip install pymorphy3`, a
development tool: the game reads the JSON):

* a phrase's head is its first noun in the nominative; the adjectives before it agree with it
  (an animate masculine head takes the genitive form in the accusative); the words after it
  (a genitive complement: мастер школы) stay;
* a transliterated Chinese name (every word capitalised, no dictionary word) declines its last
  word when it is a man's and ends in a consonant (Лю Чуньфэн → Лю Чуньфэна); a woman's, or one
  ending in a vowel, does not change; the gender comes from the NPC's own data.

`python tools/l10n/ru_nouns.py draft` adds the new rows and lists them for review (`--dry` only
lists); `python tools/l10n/ru_nouns.py check` fails on a malformed row.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_po import parse  # noqa: E402
from po_batch import _read  # noqa: E402

REPOSITORY = Path(__file__).resolve().parents[2]
PO = REPOSITORY / "game/locale/ru.po"
POT = REPOSITORY / "game/locale/eastern_stories.pot"
TABLE = REPOSITORY / "game/locale/ru_nouns.json"
GENDERS = ("м", "ж", "ср", "мн")
CASES = ("gent", "datv", "accs", "ablt", "loct")
# The fields whose text the game fills into a sentence.
NAME_FIELDS = ("name", "limbs", "family.name", "short", "region", "nickname", "name_parts", "weapon", "liquid")
FEMALE = "女性"
FEMALE_BEAST = "雌性"


def _name_sources() -> dict[str, str]:
    """msgid → the gender of the NPC named so ("" for a thing), for every name in the template."""
    found: dict[str, str] = {}
    text = POT.read_text(encoding="utf-8")
    for chunk in text.split("\n\n"):
        block = _read(chunk.splitlines())
        if not block.is_message:
            continue
        fields = " ".join(block.notes)
        if any(re.search(rf"(^|\s){re.escape(field)}(\s|/|$)", fields) for field in NAME_FIELDS):
            found[block.msgid] = ""
    return found


def _npc_genders() -> dict[str, str]:
    """Chinese display name → gender, from every NPC in game/data."""
    genders: dict[str, str] = {}
    for path in (REPOSITORY / "game/data").rglob("*.json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, UnicodeDecodeError):
            continue
        _walk(data, genders)
    return genders


def _walk(node, genders: dict[str, str]) -> None:
    if isinstance(node, dict):
        if isinstance(node.get("name"), str) and isinstance(node.get("gender"), str):
            genders.setdefault(node["name"], node["gender"])
        for value in node.values():
            _walk(value, genders)
    elif isinstance(node, list):
        for value in node:
            _walk(value, genders)


class Drafter:
    def __init__(self) -> None:
        import pymorphy3

        self.morph = pymorphy3.MorphAnalyzer()

    def row(self, name: str, gender_hint: str) -> tuple[list[str], str]:
        """The row for `name` and a note for the reviewer ("" when the draft is sure)."""
        words = name.split(" ")
        if self._is_chinese_name(words, gender_hint):
            female = gender_hint in (FEMALE, FEMALE_BEAST)
            last = words[-1]
            if female or not re.search(r"[бвгджзйклмнпрстфхцчшщь]$", last):
                return ["ж" if female else "м", "", "", "", "", "", "", ""], "a Chinese name: not declined"
            stem = last[:-1] if last.endswith(("ь", "й")) else last
            soft = last.endswith(("ь", "й"))
            endings = ("я", "ю", "я", "ем", "е") if soft else ("а", "у", "а", "ом", "е")
            head = " ".join(words[:-1] + [""])
            return ["м"] + [head + stem + ending for ending in endings] + ["", ""], "a Chinese man's name: its last word declined"
        parses = [self._parse(word) for word in words]
        head = next((i for i, p in enumerate(parses) if p is not None and p.tag.POS == "NOUN"), None)
        if head is None:
            return ["м", "", "", "", "", "", "", ""], "no noun found: not declined"
        noun = parses[head]
        gender = self._gender(noun)
        animate = "anim" in noun.tag
        row = [gender]
        note = ""
        for case in CASES:
            forms = []
            for i, word in enumerate(words):
                forms.append(self._inflect(word, parses[i], case, noun, animate, i < head, i == head))
            row.append(" ".join(forms))
        few, many = [], []
        for i, word in enumerate(words):
            few.append(self._counted(word, parses[i], noun, 2, i < head, i == head))
            many.append(self._counted(word, parses[i], noun, 5, i < head, i == head))
        row += [" ".join(few), " ".join(many)]
        if any(p is None or not p.is_known for p in parses[: head + 1]):
            note = "a word the dictionary does not know"
        return row, note

    def _parse(self, word: str):
        if not re.fullmatch(r"[А-Яа-яЁё-]+", word):
            return None
        parses = self.morph.parse(word)
        nominative = [p for p in parses if "nomn" in p.tag and "sing" in p.tag or "nomn" in p.tag and "Pltm" in p.tag or p.tag.POS in ("ADJF", "PRTF") and "nomn" in p.tag]
        plain = [p for p in nominative if not any(mark in p.tag for mark in ("Geox", "Name", "Surn", "Patr", "Orgn", "Abbr"))]
        return (plain or nominative or parses)[0]

    def _is_chinese_name(self, words: list[str], gender_hint: str) -> bool:
        if len(words) < 2 or not all(re.fullmatch(r"[А-ЯЁ][а-яё]+", word) for word in words):
            return False
        if gender_hint in ("男性", FEMALE):
            return True
        return all(not any(p.is_known for p in self.morph.parse(word)) or "Surn" in self.morph.parse(word)[0].tag or "Name" in self.morph.parse(word)[0].tag for word in words) and len(words) >= 2

    @staticmethod
    def _gender(noun) -> str:
        tag = noun.tag
        if "Pltm" in tag or tag.number == "plur":
            return "мн"
        return {"masc": "м", "femn": "ж", "neut": "ср"}.get(tag.gender or "", "м")

    def _inflect(self, word: str, parse, case: str, noun, animate: bool, before: bool, is_head: bool) -> str:
        if parse is None or not (before or is_head):
            return word
        if before and parse.tag.POS not in ("ADJF", "PRTF", "NUMR", "NPRO"):
            return word
        want = {case}
        if before:
            number = "plur" if self._gender(noun) == "мн" else "sing"
            want.add(number)
            if number == "sing" and noun.tag.gender:
                want.add(noun.tag.gender)
            if case == "accs" and (number == "plur" or noun.tag.gender == "masc"):
                want.add("anim" if animate else "inan")
        else:
            want.add("plur" if self._gender(noun) == "мн" else "sing")
        done = parse.inflect(want)
        return self._case_like(word, done.word) if done else word

    def _counted(self, word: str, parse, noun, amount: int, before: bool, is_head: bool) -> str:
        if parse is None or not (before or is_head) or self._gender(noun) == "мн":
            return word
        if is_head:
            done = parse.make_agree_with_number(amount)
            return self._case_like(word, done.word) if done else word
        if parse.tag.POS not in ("ADJF", "PRTF"):
            return word
        # 2–4: an adjective before a feminine noun takes the nominative plural, otherwise the genitive.
        if amount == 2 and noun.tag.gender == "femn":
            done = parse.inflect({"nomn", "plur"})
        else:
            done = parse.inflect({"gent", "plur"})
        return self._case_like(word, done.word) if done else word

    @staticmethod
    def _case_like(original: str, form: str) -> str:
        return form[0].upper() + form[1:] if original[:1].isupper() else form


def load_table() -> dict[str, list[str]]:
    if not TABLE.exists():
        return {}
    return json.loads(TABLE.read_text(encoding="utf-8"))


def write_table(table: dict[str, list[str]]) -> None:
    lines = ["{"]
    items = list(table.items())
    for index, (name, row) in enumerate(items):
        comma = "," if index < len(items) - 1 else ""
        lines.append(f"\t{json.dumps(name, ensure_ascii=False)}: {json.dumps(row, ensure_ascii=False)}{comma}")
    lines.append("}")
    TABLE.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def problems(table: dict[str, list[str]]) -> list[str]:
    found = []
    for name, row in table.items():
        if not isinstance(row, list) or len(row) != 8 or row[0] not in GENDERS:
            found.append(f"{name}: a row is a gender and seven forms")
    return found


def draft(dry: bool) -> int:
    table = load_table()
    names = _name_sources()
    genders = _npc_genders()
    drafter = Drafter()
    added = 0
    for _ctx, msgid, msgstr in parse(PO):
        name = msgstr.strip()
        if msgid not in names or not name or name in table or len(name.split(" ")) > 6:
            continue
        if not re.fullmatch(r"[А-Яа-яЁё][А-Яа-яЁё \-]*", name):
            continue
        row, note = drafter.row(name, genders.get(msgid, ""))
        table[name] = row
        added += 1
        print(f"{msgid}\t{name}\t{' | '.join(row)}\t{note}")
    if not dry:
        write_table(table)
    print(f"{added} rows drafted", file=sys.stderr)
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["draft", "check"])
    parser.add_argument("--dry", action="store_true", help="list the rows a draft would add, write nothing")
    args = parser.parse_args(argv)
    if args.command == "draft":
        return draft(args.dry)
    found = problems(load_table())
    for problem in found:
        print(problem)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
