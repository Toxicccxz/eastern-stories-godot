"""tools/l10n/extract_pot.py: what reaches the translation template, and the committed one is current."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/l10n"))

import extract_pot  # noqa: E402


def _ids(catalog: extract_pot.Catalog) -> list[tuple[str, str]]:
    return [(entry.context, entry.msgid) for entry in catalog.entries()]


class GdscriptTest(unittest.TestCase):
    def _extract(self, source: str) -> extract_pot.Catalog:
        catalog = extract_pot.Catalog()
        extract_pot.extract_gdscript(source, "x.gd", catalog)
        return catalog

    def test_translate_calls_and_chinese_literals(self) -> None:
        catalog = self._extract(
            'func f() -> void:\n'
            '\tlabel.text = tr("关闭")\n'
            '\tvar a := TranslationServer.translate("你给{npc}{item}。")\n'
            '\tvar b := tr("Paused")\n'
            '\tvar c := "Window"\n'
            'const LINES: Array[String] = [\n'
            '\t"$N注视著$n的行动。",\n'
            ']\n'
        )
        self.assertEqual(
            _ids(catalog),
            [("", "关闭"), ("", "你给{npc}{item}。"), ("", "Paused"), ("", "$N注视著$n的行动。")],
        )

    def test_escapes_quotes_and_comments(self) -> None:
        catalog = self._extract(
            "# 注释里的中文不算\n"
            "var a := \"第一行\\n第二行\\t\\\"引号\\\"\"  # 行尾注释\n"
            "var b := '单引号里的\\'中文\\''\n"
            "var c := &\"男性\"\n"
            "var d := ^\"路径/中文\"\n"
        )
        self.assertEqual(
            [msgid for _, msgid in _ids(catalog)],
            ["第一行\n第二行\t\"引号\"", "单引号里的'中文'", "男性"],
        )

    def test_no_translate_and_translator_notes(self) -> None:
        catalog = self._extract(
            'var mark := "魏无极"  # NO_TRANSLATE: a mark, never shown\n'
            '# NO_TRANSLATE\n'
            'var key := "治伤"\n'
            '# TRANSLATORS: {npc} is an NPC name.\n'
            'var line := tr("{npc}点了点头。")\n'
        )
        entries = catalog.entries()
        self.assertEqual([entry.msgid for entry in entries], ["{npc}点了点头。"])
        self.assertEqual(entries[0].notes, ["{npc} is an NPC name."])

    def test_context_must_be_literal(self) -> None:
        catalog = self._extract(
            'var a := TranslationServer.translate("万", "number")\n'
            'var b := tr("两", context)\n'
            'var c := tr(variable)\n'
        )
        self.assertEqual(_ids(catalog), [("number", "万")])

    def test_concatenation_lint(self) -> None:
        errors = extract_pot.lint_concatenation(
            'var a := family + "开山祖师"\n'
            'var b := "技能：" + skills\n'
            'text += "；"\n'
            'var ok := tr("{family}开山祖师").format({"family": family})\n'
            'var key := "负" + x  # NO_TRANSLATE\n',
            "x.gd",
        )
        self.assertEqual([error.split(":")[1] for error in errors], ["1", "2", "3"])


class SceneTest(unittest.TestCase):
    def test_text_properties_unless_auto_translate_is_disabled(self) -> None:
        catalog = extract_pot.Catalog()
        extract_pot.extract_scene(
            '[node name="Title" type="Label" parent="."]\n'
            'text = "东方故事"\n'
            '[node name="Name" type="LineEdit" parent="."]\n'
            'placeholder_text = "1–24 个字符"\n'
            '[node name="Log" type="RichTextLabel" parent="."]\n'
            'auto_translate_mode = 2\n'
            'text = "动态内容"\n'
            '[node name="Mode" type="OptionButton" parent="."]\n'
            'popup/item_0/text = "窗口"\n'
            'tooltip_text = "说\\"明\\""\n',
            "x.tscn",
            catalog,
        )
        self.assertEqual([msgid for _, msgid in _ids(catalog)], ["东方故事", "1–24 个字符", "窗口", '说"明"'])

    def test_multiline_text(self) -> None:
        catalog = extract_pot.Catalog()
        extract_pot.extract_scene(
            '[node name="Hint" type="Label" parent="."]\n'
            'text = "第一行\n第二行 \\"引\\"\n第三行"\n'
            'horizontal_alignment = 1\n',
            "x.tscn",
            catalog,
        )
        self.assertEqual([msgid for _, msgid in _ids(catalog)], ['第一行\n第二行 "引"\n第三行'])


class ContentTest(unittest.TestCase):
    def test_text_fields_topics_and_lines_but_not_marks_or_ids(self) -> None:
        catalog = extract_pot.Catalog()
        document = {"npcs": [{
            "id": "snow.npc.teacher",
            "name": "魏无极",
            "aliases": ["teacher"],
            "gender": "男性",
            "long": "一位老先生。\n",
            "inquiry": {"学费": ["只要五两银子。"], "here": ["这里是书院。"], "治伤": {"eff_kee_percent": [{"at_least": 0, "say": "伤得不轻。"}]}},
            "accept_object": [{"giver_mark": "魏无极", "emote": "点了点头。", "accept": True}],
            "chat_msg": ["老先生摇头晃脑。\n", {"action": "random_move"}],
            "family": {"name": "封山剑派", "title": "弟子"},
            "recognize_apprentice": [{"family": "family.fonxan", "fail": "他不愿意教你。"}],
            "limbs": ["头部", "尾巴"],
        }]}
        extract_pot.extract_content(document, "data/snow/npcs.json", catalog)
        self.assertEqual(
            [msgid for _, msgid in _ids(catalog)],
            ["魏无极", "男性", "一位老先生。\n", "学费", "只要五两银子。", "这里是书院。", "治伤", "伤得不轻。",
             "点了点头。", "老先生摇头晃脑。\n", "封山剑派", "弟子", "他不愿意教你。", "头部", "尾巴"],
        )
        name = next(entry for entry in catalog.entries() if entry.msgid == "魏无极")
        self.assertEqual(name.notes, ["snow.npc.teacher name"])


class RenderTest(unittest.TestCase):
    def test_multiline_and_context(self) -> None:
        catalog = extract_pot.Catalog()
        catalog.add("第一行\n第二行\n", "data/a.json", note="room long")
        catalog.add("万", "core/text/chinese_number.gd", context="number")
        text = extract_pot.render_pot(catalog)
        self.assertIn('#. room long\n#: data/a.json\nmsgid ""\n"第一行\\n"\n"第二行\\n"\nmsgstr ""\n', text)
        self.assertIn('#: core/text/chinese_number.gd\nmsgctxt "number"\nmsgid "万"\nmsgstr ""\n', text)

    def test_committed_template_is_current(self) -> None:
        current = (REPOSITORY / extract_pot.POT_PATH).read_text(encoding="utf-8")
        self.assertEqual(current, extract_pot.render_pot(extract_pot.build_catalog(REPOSITORY)),
                         "run python tools/l10n/extract_pot.py")

    def test_no_chinese_concatenation(self) -> None:
        self.assertEqual(extract_pot.lint_repository(REPOSITORY), [])


if __name__ == "__main__":
    unittest.main()
