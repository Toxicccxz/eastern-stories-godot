"""Batches into a .po without touching the rest (tools/l10n/po_batch.py)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/l10n"))

import check_po  # noqa: E402
import po_batch  # noqa: E402

TEMPLATE = """msgid ""
msgstr ""
"Language: zh_CN\\n"

#: scenes/a.tscn
msgid "新游戏"
msgstr ""

#. a note
#: data/oldpine/rooms.json
msgid "松林"
msgstr ""

#: data/cloud/npcs.json
msgid "很长的一句话，"
"分两行写。"
msgstr ""

msgctxt "speed"
#: ui/a.gd
msgid "快"
msgstr ""

msgctxt "move"
#: ui/b.gd
msgid "快"
msgstr ""
"""

# As Poedit writes it: references, a fuzzy entry with its old source, a wrapped msgstr.
PO = """# Eastern Stories — English.
msgid ""
msgstr ""
"Language: en\\n"

#: scenes/a.tscn
msgid "新游戏"
msgstr "New Game"

#. a note
#: data/oldpine/rooms.json
#, fuzzy
#| msgid "老松林"
msgid "松林"
msgstr "Old Pines"

#: data/cloud/npcs.json
msgid "很长的一句话，"
"分两行写。"
msgstr "A long line, "
"written on two."
"""


def _template() -> list[po_batch.Block]:
    return [b for b in po_batch.parse(TEMPLATE) if b.is_message]


class PoBatchTest(unittest.TestCase):
    def test_reading_and_writing_changes_nothing(self) -> None:
        self.assertEqual(po_batch.write(po_batch.parse(PO)), PO)
        shipped = (REPOSITORY / "game/locale/en.po").read_text(encoding="utf-8")
        self.assertEqual(po_batch.write(po_batch.parse(shipped)), shipped)

    def test_keys_are_stable_and_unique(self) -> None:
        self.assertEqual(po_batch.key_of("", "新游戏"), po_batch.key_of("", "新游戏"))
        self.assertNotEqual(po_batch.key_of("speed", "快"), po_batch.key_of("move", "快"))
        template = po_batch.parse((REPOSITORY / "game/locale/eastern_stories.pot").read_text(encoding="utf-8"))
        keys = [po_batch.key_of(b.ctx, b.msgid) for b in template if b.is_message]
        self.assertEqual(len(keys), len(set(keys)))

    def test_todo_lists_the_untranslated_and_the_fuzzy(self) -> None:
        lines = po_batch.todo(po_batch.parse(PO), _template(), [], 0)
        sources = [line.split("\t")[1] for line in lines]
        self.assertEqual(sources, ["松林", "快", "快"])
        self.assertIn("# a note", lines[0])
        self.assertIn("[speed]", lines[1])
        only = po_batch.todo(po_batch.parse(PO), _template(), ["data/oldpine"], 0)
        self.assertEqual(len(only), 1)
        self.assertEqual(len(po_batch.todo(po_batch.parse(PO), _template(), [], 2)), 2)

    def test_apply_changes_only_what_the_batch_names(self) -> None:
        blocks = po_batch.parse(PO)
        batch = "# a comment line\n\n" + po_batch.key_of("", "松林") + "\tPine Wood\n=快\tFast\n"
        changed, added, errors = po_batch.apply(blocks, _template(), batch)
        self.assertEqual((changed, added, errors), (1, 2, []))
        out = po_batch.write(blocks)
        # The untouched entries are as they were, the changed one keeps its comments.
        self.assertIn('#: scenes/a.tscn\nmsgid "新游戏"\nmsgstr "New Game"', out)
        self.assertIn('msgstr "A long line, "\n"written on two."', out)
        self.assertIn('#. a note\n#: data/oldpine/rooms.json\nmsgid "松林"\nmsgstr "Pine Wood"', out)
        self.assertNotIn("fuzzy", out)
        self.assertNotIn("#|", out)
        self.assertIn('msgctxt "speed"\nmsgid "快"\nmsgstr "Fast"', out)
        self.assertIn('msgctxt "move"\nmsgid "快"\nmsgstr "Fast"', out)
        again = po_batch.parse(out)
        self.assertEqual(po_batch.todo(again, _template(), [], 0), [])

    def test_a_line_break_and_quotes_survive(self) -> None:
        blocks = po_batch.parse(PO)
        po_batch.apply(blocks, _template(), "=新游戏\tSay \"hi\"\\nthen go\n")
        entry = [b for b in po_batch.parse(po_batch.write(blocks)) if b.msgid == "新游戏"][0]
        self.assertEqual(entry.msgstr, 'Say "hi"\nthen go')

    def test_a_bad_batch_changes_nothing(self) -> None:
        blocks = po_batch.parse(PO)
        changed, added, errors = po_batch.apply(blocks, _template(), "=没有这句\tNope\nnotab\n")
        self.assertEqual((changed, added), (0, 0))
        self.assertEqual(len(errors), 2)
        self.assertEqual(po_batch.write(blocks), PO)

    def test_sync_makes_a_gone_entry_obsolete(self) -> None:
        blocks = po_batch.parse(PO + '\n#: x.gd\nmsgid "删掉的"\nmsgstr "Gone"\n')
        self.assertEqual(po_batch.sync(blocks, _template()), 1)
        out = po_batch.write(blocks)
        self.assertIn('#~ msgid "删掉的"\n#~ msgstr "Gone"', out)
        self.assertNotIn("#: x.gd", out)
        with tempfile.TemporaryDirectory() as folder:
            po, pot = Path(folder) / "en.po", Path(folder) / "t.pot"
            po.write_text(out, encoding="utf-8")
            pot.write_text(TEMPLATE, encoding="utf-8")
            self.assertEqual(check_po.problems_in(po, pot), [])


if __name__ == "__main__":
    unittest.main()
