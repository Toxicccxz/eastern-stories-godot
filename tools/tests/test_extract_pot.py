"""tools/l10n/extract_pot.py: what reaches the translation template, and the committed one is current."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/l10n"))

import extract_pot  # noqa: E402


# Keys in game/data whose strings are never shown to the player as they stand, with why. Every
# other string with Chinese text in game/data must reach the template (CompletenessTest): a new
# text key fails there until the extractor learns it or it is listed here.
NOT_SHOWN = {
    # Notes for the developers: comments, provenance, the LPC a record came from.
    "note": "a comment", "_comment": "a comment", "note_bands": "a comment", "origin": "provenance",
    "source": "provenance", "sources": "provenance", "legacy_source": "provenance",
    "legacy_sources": "provenance", "legacy_room": "provenance",
    # Marks and temps (CharacterState.marks / temps) are ids the rules test, never printed.
    "mark": "a mark", "marks": "marks", "not_mark": "a mark", "unmark": "a mark",
    "asker_marks": "marks", "asker_lacks": "marks", "mark_asker": "a mark", "marks_asker": "marks",
    "listed_marks": "marks", "confirm_marks": "marks", "confirm_lacks": "marks",
    "giver_mark": "a mark", "mark_giver": "a mark", "unless_giver_mark": "a mark",
    "scene_mark": "a mark", "cleared_mark": "a mark", "set_mark": "a mark", "found_by": "a mark",
    "teaches": "a mark", "spar_won_mark": "a mark", "again_mark": "a mark",
    "die_marks_killer": "a mark", "forbids_marks": "marks", "accept_marks": "marks",
    "attack_unless_mark": "a mark", "attack_unless_marks": "marks",
    "unless_mark": "a mark", "unless_marks": "marks",
    "temp": "a temp", "set_temp": "a temp", "set_temps": "temps", "unset_temps": "temps",
    "clear_temp": "a temp", "giver_temp": "a temp", "unless_temp": "a temp", "not_temp": "a temp",
    # Words matched, not printed: an item's aliases (give/ask by name), an item carried, a chat
    # line's source text a journal entry waits for.
    "aliases": "matched against", "carries": "an item matched", "asker_carries": "an item matched",
    "contains": "matched against the source line",
    # Read but not shown: an item's material (no screen reads it).
    "material": "not drawn",
    # Pieces of a name, shown only joined: a drawn name's parts (each whole name is extracted),
    # a 法名's first character before the player's own, the new player's suggested names (the
    # player's own name is kept as typed, not translated).
    "name_parts": "joined names are extracted", "prefixes": "joined to the player's name",
    "surnames": "the player's own name", "male": "the player's own name", "female": "the player's own name",
}


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

    def test_developer_output_is_not_player_text(self) -> None:
        catalog = self._extract(
            'func f() -> void:\n'
            '\tpush_error("车马行: the fare (%d) was not taken" % fare)\n'
            '\tpush_warning("遁 could not reach %s" % place)\n'
            '\tprint("调试")\n'
            '\tshow("你付了车钱。")\n'
        )
        self.assertEqual(_ids(catalog), [("", "你付了车钱。")])

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
            "chat_msg_combat": ["你走吧！\n", {"say": "他笑了。\n", "color": "CYN"}, {"action": "perform", "skill": "sword", "function": "counterattack"}],
            "family": {"name": "封山剑派", "title": "弟子"},
            "recognize_apprentice": [{"family": "family.fonxan", "fail": "他不愿意教你。"}],
            "limbs": ["头部", "尾巴"],
        }]}
        extract_pot.extract_content(document, "data/snow/npcs.json", catalog)
        self.assertEqual(
            [msgid for _, msgid in _ids(catalog)],
            ["魏无极", "男性", "一位老先生。\n", "学费", "只要五两银子。", "这里是书院。", "治伤", "伤得不轻。",
             "点了点头。", "老先生摇头晃脑。\n", "你走吧！\n", "他笑了。\n", "封山剑派", "弟子", "他不愿意教你。", "头部", "尾巴"],
        )
        name = next(entry for entry in catalog.entries() if entry.msgid == "魏无极")
        self.assertEqual(name.notes, ["snow.npc.teacher name"])

    def test_no_drop_lines_and_checklist_missing(self) -> None:
        # drop.c's refusal when no_drop is a sentence; `true` (ES2's own line, in code) is no text.
        catalog = extract_pot.Catalog()
        document = {
            "items": [
                {"id": "native:choyin/magistrate_letter", "name": "程不平的信", "no_drop": "这封信不能随便丢。"},
                {"id": "native:imperial/palace_blade_manual", "name": "禁中刀谱", "no_drop": True},
            ],
            "quests": [{"id": "main.chapter6", "steps": [{"checklist": [
                {"label": "程不平的信在你身上", "when": {"item": "native:choyin/magistrate_letter"}, "missing": "丢了就回乔阴县衙找程不平再写一封"},
            ]}]}],
        }
        extract_pot.extract_content({"items": document["items"]}, "data/choyin/items.json", catalog)
        extract_pot.extract_content({"quests": document["quests"]}, "data/story/chapter6.json", catalog)
        ids = [msgid for _, msgid in _ids(catalog)]
        self.assertIn("程不平的信在你身上", ids)
        self.assertIn("这封信不能随便丢。", ids)
        self.assertIn("丢了就回乔阴县衙找程不平再写一封", ids)
        self.assertNotIn("True", ids)
        line = next(entry for entry in catalog.entries() if entry.msgid == "这封信不能随便丢。")
        self.assertEqual(line.notes, ["native:choyin/magistrate_letter no_drop"])

    def test_story_lines_written_for_a_moment(self) -> None:
        # 攻击 on one the story will not let the player fight, a watch's lines when it catches the
        # player again, a trial's question and deed and its master's words, a helper leaving, an
        # act's questions and answers, a landmark's guarded line; none of their marks or ids.
        catalog = extract_pot.Catalog()
        document = {
            "npcs": [{
                "id": "native.npc.guard",
                "fight_deferred": "你的手刚抬起来，四面的禁军已经拔了刀。",
                "fights_beside_leaves": "{npc}收了刀，走了。",
                "watch": {"caught": {"again_mark": "被禁军拿过两回", "again_lines": ["禁军把你押回了侍卫营。"]}},
                "trials": [{"confirm": "三鞭是真打。", "deed": "接下了三鞭", "relent_say": "我不用内力。",
                            "rest_say": "歇好了再来。", "unless_mark": "接过三鞭"}],
                "rank_info": {"self": "小的"},
                "attitude": {"when": {"mark": "x"}, "then": "peaceful", "else": "friendly"},
                "classic": {"combat_exp": 600, "without": ["resources"]},
                "moods": [{"combat_chat_msg": ["他叫道：认输了！", {"action": "random_move"}]}],
            }],
            "acts": [{"steps": [{"questions": [{"text": "头在哪里？", "answers": [{"text": "在湖底。", "mark": "说了湖底"}]}]}]}],
            "landmarks": [{"messages": {"guarded": "僧人说：偷东西不好。"}}],
        }
        extract_pot.extract_content(document, "data/native/npcs.json", catalog)
        self.assertEqual(
            sorted(msgid for _, msgid in _ids(catalog)),
            sorted(["你的手刚抬起来，四面的禁军已经拔了刀。", "{npc}收了刀，走了。", "禁军把你押回了侍卫营。", "三鞭是真打。",
                    "接下了三鞭", "我不用内力。", "歇好了再来。", "小的", "他叫道：认输了！", "头在哪里？", "在湖底。",
                    "僧人说：偷东西不好。"]),
        )

    def test_a_document_holding_one_record(self) -> None:
        # common/opening.json: {"opening": {...}}, not a list of records.
        catalog = extract_pot.Catalog()
        document = {"opening": {"source": "native: 开场", "title": "开场", "paragraphs": ["第一段。", "第二段。"]}}
        extract_pot.extract_content(document, "data/common/opening.json", catalog)
        self.assertEqual([msgid for _, msgid in _ids(catalog)], ["开场", "第一段。", "第二段。"])

    def test_a_moves_bare_hand_word_but_not_a_skill_type(self) -> None:
        catalog = extract_pot.Catalog()
        document = {
            "skills": [{"id": "x", "groups": ["逼", "守"], "actions": [{"action": "$N一指点出。", "weapon": "右手食指", "group": "逼"}]}],
            "npcs": [{"id": "y", "weapon": "sword"}],
        }
        extract_pot.extract_content(document, "data/common/skills.json", catalog)
        self.assertEqual([msgid for _, msgid in _ids(catalog)], ["逼", "守", "$N一指点出。", "右手食指"])

    def test_skill_practice_valid_learn_and_improved_lines(self) -> None:
        catalog = extract_pot.Catalog()
        document = {"skills": [{
            "id": "fonxansword", "name": "封山剑法", "kind": "specialized", "enable": ["sword"],
            "practice": {"kee": 30, "force": 3, "done": "你按著所学练了一遍封山剑法。", "fail": "你的内力或气不够。"},
            "valid_learn": {"max_force": "你的内力不够。", "weapon": "你必须先找一把剑。"},
            "improved_line": "你的体质改善了。", "improved_color": "HIW",
        }]}
        extract_pot.extract_content(document, "data/common/skills.json", catalog)
        self.assertEqual(
            [msgid for _, msgid in _ids(catalog)],
            ["封山剑法", "你按著所学练了一遍封山剑法。", "你的内力或气不够。", "你的内力不够。", "你必须先找一把剑。", "你的体质改善了。"],
        )


class RenderTest(unittest.TestCase):
    def test_voxel_signs_and_entrances_reach_translators(self) -> None:
        catalog = extract_pot.build_catalog(REPOSITORY)
        for message in ["非请莫入", "楼梯 · 下楼"]:
            entry = next(e for e in catalog.entries() if e.msgid == message)
            self.assertTrue(any("/voxel/" in source for source in entry.sources))

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


class CompletenessTest(unittest.TestCase):
    """Every string with Chinese text in game/data (the manifest's files, common/opening.json, the
    appearances, names and voxel configs read for display) reaches the template, unless it sits
    under a key in NOT_SHOWN."""

    def _missing(self, document: object, catalog_ids: set[str], path: tuple[str, ...] = ()) -> list[tuple[str, str]]:
        if isinstance(document, dict):
            found: list[tuple[str, str]] = []
            for key, value in document.items():
                if key not in NOT_SHOWN:
                    found.extend(self._missing(value, catalog_ids, path + (key,)))
            return found
        if isinstance(document, list):
            return [item for value in document for item in self._missing(value, catalog_ids, path)]
        if isinstance(document, str) and extract_pot.has_chinese(document) and document not in catalog_ids:
            return [(".".join(path), document)]
        return []

    def test_every_shown_string_reaches_the_template(self) -> None:
        catalog_ids = {entry.msgid for entry in extract_pot.build_catalog(REPOSITORY).entries()}
        data = REPOSITORY / extract_pot.GAME / "data"
        files = sorted(data.rglob("*.json"))
        self.assertTrue(any(path.name == "opening.json" for path in files))
        missing: list[str] = []
        for path in files:
            document = json.loads(path.read_text(encoding="utf-8"))
            for where, text in self._missing(document, catalog_ids):
                missing.append(f"{path.relative_to(data).as_posix()} {where}: {text[:40]!r}")
        self.assertEqual(missing[:20], [], f"{len(missing)} strings with Chinese text are neither extracted nor listed in NOT_SHOWN")

    def test_the_check_notices_a_new_text_key(self) -> None:
        document = {"npcs": [{"id": "x", "farewell_say": "后会有期。", "mark": "见过了"}]}
        self.assertEqual(self._missing(document, set()), [("npcs.farewell_say", "后会有期。")])


if __name__ == "__main__":
    unittest.main()
