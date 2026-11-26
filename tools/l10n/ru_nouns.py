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
  ending in a vowel, does not change; the gender comes from the NPC's own data;
* a person's gender is the person's (староста who is a woman: ж), a beast's or a thing's the
  word's (собака: ж, whatever the dog).

`python tools/l10n/ru_nouns.py draft` adds the new rows and lists them for review (`--dry` only
lists); `prune` drops the rows of names no translation uses any more (renamed in review);
`check` fails on a malformed row.
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
    """msgid → its notes, for every name in the template."""
    found: dict[str, str] = {}
    text = POT.read_text(encoding="utf-8")
    for chunk in text.split("\n\n"):
        block = _read(chunk.splitlines())
        if not block.is_message:
            continue
        fields = " ".join(block.notes)
        if any(re.search(rf"(^|\s){re.escape(field)}(\s|/|$)", fields) for field in NAME_FIELDS):
            found[block.msgid] = fields
    return found


# A place (a room's or region's name) is a proper name; a person, beast or thing is not.
PLACE_FIELDS = ("short", "region")


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


def _palladius_syllables() -> frozenset[str]:
    """Every syllable Palladius writes (a generous set: a few combinations Chinese lacks do no harm)."""
    initials = ["", "б", "п", "м", "ф", "д", "т", "н", "л", "г", "к", "х", "цз", "ц", "с", "чж", "ч", "ш", "ж"]
    finals = ["а", "о", "э", "ай", "эй", "ао", "оу", "ань", "энь", "ан", "эн", "ун", "эр", "и", "ы", "я", "е", "яо",
              "ю", "янь", "инь", "ян", "ин", "юн", "у", "уа", "уай", "уй", "уань", "унь", "уан", "уэй", "юй", "юэ",
              "юань", "юнь", "ё"]
    found = {i + f for i in initials for f in finals}
    found |= {"ва", "во", "вай", "вэй", "вань", "вэнь", "ван", "вэн"}
    return frozenset(found)


PALLADIUS = _palladius_syllables()


def _palladius_word(word: str) -> bool:
    """Whether `word` splits into Palladius syllables (ъ marks a boundary: Цинъинь)."""
    text = word.lower()
    for part in text.split("ъ"):
        reachable = [True] + [False] * len(part)
        for end in range(1, len(part) + 1):
            reachable[end] = any(reachable[start] and part[start:end] in PALLADIUS for start in range(max(0, end - 5), end))
        if not part or not reachable[-1]:
            return False
    return True


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
        parses = [self._parse(word, i < len(words) - 1) for i, word in enumerate(words)]
        if any(p.tag.POS == "PREP" for p in self.morph.parse(words[0])):
            return ["мн" if parses[-1] is not None and parses[-1].tag.number == "plur" else "м", "", "", "", "", "", "", ""], "a phrase opening with a preposition: not declined"
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
        # A person's gender is the person's (a староста who is a woman is ж), a beast's the word's.
        if gender_hint in ("男性", FEMALE) and gender != "мн":
            row[0] = "ж" if gender_hint == FEMALE else "м"
        if any(p is None or not p.is_known for p in parses[: head + 1]):
            note = "a word the dictionary does not know"
        return row, note

    def is_proper(self, name: str) -> bool:
        """A transliterated name, or a phrase whose first word the dictionary knows only as a name."""
        words = name.split(" ")
        if self._is_chinese_name(words, ""):
            return True
        parses = self.morph.parse(words[0])
        return not any(p.is_known and not any(mark in p.tag for mark in ("Name", "Surn", "Geox")) for p in parses)

    def _parse(self, word: str, more_follow: bool = False):
        if not re.fullmatch(r"[А-Яа-яЁё-]+", word):
            return None
        parses = self.morph.parse(word)
        nominative = [p for p in parses if "nomn" in p.tag and "sing" in p.tag or "nomn" in p.tag and "Pltm" in p.tag or p.tag.POS in ("ADJF", "PRTF") and "nomn" in p.tag]
        plain = [p for p in nominative if not any(mark in p.tag for mark in ("Geox", "Name", "Surn", "Patr", "Orgn", "Abbr"))]
        if more_follow:
            # A word before others is an adjective when it can be one: Малый меч, not «малый» a lad.
            adjectives = [p for p in plain or nominative if p.tag.POS in ("ADJF", "PRTF")]
            if adjectives:
                return adjectives[0]
        return (plain or nominative or parses)[0]

    def _is_chinese_name(self, words: list[str], gender_hint: str) -> bool:
        """Every word a capitalised run of Palladius syllables (Лю Чуньфэн, Линь Чжи, Ланьчэн); a
        single word only when the dictionary does not know it as a common word."""
        if not all(re.fullmatch(r"[А-ЯЁ][а-яёъ]+", word) and _palladius_word(word) for word in words):
            return False
        if len(words) > 1 or gender_hint in ("男性", FEMALE):
            return True
        return not any(p.is_known and not any(mark in p.tag for mark in ("Name", "Surn", "Geox")) for p in self.morph.parse(words[0]))

    @staticmethod
    def _gender(noun) -> str:
        tag = noun.tag
        if "Pltm" in tag or tag.number == "plur":
            return "мн"
        if "Ms-f" in tag:
            return "м"  # a common-gender person (убийца, слуга): a man unless the NPC is a woman
        return {"masc": "м", "femn": "ж", "neut": "ср"}.get(tag.gender or "", "м")

    def _inflect(self, word: str, parse, case: str, noun, animate: bool, before: bool, is_head: bool) -> str:
        if parse is None or not (before or is_head):
            return word
        if before and parse.tag.POS not in ("ADJF", "PRTF", "NUMR", "NPRO"):
            return word
        want = {case}
        if before and parse.normal_form == "больший":
            # «большая» read as the comparative's lemma gives «большей»: decline большой instead.
            parse = next((p for p in self.morph.parse("большой") if p.tag.POS == "ADJF"), parse)
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
        lowered = name[:1].lower() + name[1:]
        if msgid not in names or not name or name in table or lowered in table or len(name.split(" ")) > 6:
            continue
        if not re.fullmatch(r"[А-Яа-яЁё][А-Яа-яЁё \-]*", name):
            continue
        row, note = drafter.row(name, genders.get(msgid, ""))
        # ru.po shows every name with its capital; a common noun's row is kept under its lower-case
        # key, so a sentence shows it in lower case (RussianNouns.is_common). A Chinese name, a
        # place and a title keep the capital.
        place = any(re.search(rf"(^|\s){field}(\s|/|$)", names[msgid]) for field in PLACE_FIELDS)
        proper = place or drafter.is_proper(name)
        if not proper:
            row = [row[0]] + [form[:1].lower() + form[1:] for form in row[1:]]
        table[name if proper else lowered] = row
        added += 1
        print(f"{msgid}\t{name}\t{' | '.join(row)}\t{note}")
    if not dry:
        write_table(table)
    print(f"{added} rows drafted", file=sys.stderr)
    return 0


def prune() -> int:
    """Drops the rows whose name no translation in ru.po is any more (a name renamed in review)."""
    table = load_table()
    shown = {msgstr.strip() for _ctx, _msgid, msgstr in parse(PO) if msgstr.strip()}
    gone = [name for name in table if name not in shown and name[:1].upper() + name[1:] not in shown and name[:1].lower() + name[1:] not in shown]
    for name in gone:
        del table[name]
        print(name)
    write_table(table)
    print(f"{len(gone)} rows dropped", file=sys.stderr)
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["draft", "check", "prune"])
    parser.add_argument("--dry", action="store_true", help="list the rows a draft would add, write nothing")
    args = parser.parse_args(argv)
    if args.command == "draft":
        return draft(args.dry)
    if args.command == "prune":
        return prune()
    found = problems(load_table())
    for problem in found:
        print(problem)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
