"""game/data is exactly what the content importer makes of the LPC and the overrides."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.migration import content_importer as ci  # noqa: E402


def parse(source: str, path: str = 'd/test/npc/sample.c') -> ci.LpcObject:
    return ci.Parser(path, source.encode('utf-8')).parse()


class GeneratedDataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.importer, cls.files = ci.generate()

    def test_game_data_is_the_generated_output(self) -> None:
        for name, text in self.files.items():
            with self.subTest(file=name):
                current = (ci.DATA / name).read_text(encoding='utf-8')
                self.assertEqual(current, text, 'rerun: python -m tools.migration.content_importer')

    def test_every_finding_has_a_review_decision(self) -> None:
        self.assertEqual([(f.source, f.key) for f in ci.open_findings(self.importer)], [])
        self.assertEqual(ci.stale_decisions(self.importer), [])

    def test_generated_files_are_loaded(self) -> None:
        manifest = json.loads((ci.DATA / 'content_manifest.json').read_text(encoding='utf-8'))['files']
        self.assertEqual(sorted(set(self.files) - set(manifest)), [])

    def test_old_pine_keeps_its_hand_checked_records(self) -> None:
        npcs = {r['id']: r for r in json.loads(self.files['oldpine/npcs.json'])['npcs']}
        self.assertEqual(list(npcs), ['oldpine.npc.bandit', 'oldpine.npc.tall_bandit',
                                      'oldpine.npc.fat_bandit', 'oldpine.npc.serpent'])
        self.assertEqual(npcs['oldpine.npc.serpent']['race'], 'beast')
        self.assertEqual(npcs['oldpine.npc.fat_bandit']['carry'][1]['item'], 'es2:d/oldpine/obj/leather')


class ParserTest(unittest.TestCase):
    def test_create_facts_in_authored_order(self) -> None:
        lpc = parse('''
            #include <ansi.h>
            inherit NPC;
            string ask_me(object who);
            void create()
            {
                set_name("旅客", ({ "traveller" }));
                // set("long", "commented out");
                set("long", "这是一位" "旅客。\\n");
                set("combat_exp", 600+random(400));
                set("score", 5-random(10));
                if(random(10)<7)
                    set("gender", "男性" );
                else
                    set("gender", "女性" );
                carry_object(__DIR__"obj/knife")->wield();
                setup();
            }
            string ask_me(object who) { return "?"; }
        ''')
        self.assertEqual(lpc.inherits, ['NPC'])
        self.assertEqual(lpc.functions, ['ask_me'])
        sets = lpc.sets()
        self.assertEqual(list(sets), ['long', 'combat_exp', 'score', 'gender'])
        self.assertEqual(sets['long'], '这是一位旅客。\n')
        self.assertEqual(sets['combat_exp'], ci.RandomInt(600, 1, 400))
        self.assertEqual(sets['score'], ci.RandomInt(5, -1, 10))
        self.assertEqual(sets['gender'], ci.RandomChoice(10, 7, '男性', '女性'))
        carry = lpc.first('carry_object')
        self.assertEqual((carry.args, carry.chain), (['/d/test/npc/obj/knife'], ['wield']))

    def test_clonep_idiom_and_mappings(self) -> None:
        lpc = parse('''
            inherit SWORD;
            void create()
            {
                set_name("短剑", ({ "short sword", "sword" }) );
                set_weight(3000);
                if( clonep() )
                    set_default_object(__FILE__);
                else {
                    set("unit", "把");
                    set("liquid", ([ "type": "alcohol", "remaining": 15, ]) );
                }
                init_sword(15, SECONDARY | EDGED);
                setup();
            }
        ''', 'd/test/obj/short_sword.c')
        self.assertEqual(lpc.sets(), {'unit': '把', 'liquid': {'type': 'alcohol', 'remaining': 15}})
        self.assertEqual(lpc.first('init_sword').args, [15, [ci.Const('SECONDARY'), ci.Const('EDGED')]])
        self.assertEqual(lpc.findings, [])

    def test_mudos_escapes_and_colour_macros(self) -> None:
        lpc = parse('void create() { set("msg", CYN "小人不会武功\\，" NOR); set("tab", "a\\tb"); }')
        self.assertEqual(lpc.sets(), {'msg': '小人不会武功，', 'tab': 'a\tb'})

    def test_unhandled_statements_become_findings(self) -> None:
        lpc = parse('''
            int has_alcohol;
            void create() {
                has_alcohol = 1;
                if (query("x")) set("y", 1);
                set("chat_msg", ({ (: random_move :), "hi\\n" }));
            }
        ''')
        self.assertEqual(lpc.findings, ['statement in create(): has_alcohol = 1',
                                        'condition in create(): if (query("x"))'])
        self.assertEqual(lpc.sets()['chat_msg'], [ci.Closure('(: random_move :)'), 'hi\n'])


    def test_a_loop_is_one_finding_and_the_next_fact_survives(self) -> None:
        lpc = parse('''
            void create() {
                for (i = 0; i < 2; i++) { carry_object("/obj/cloth"); }
                set("age", 30);
                do { i--; } while (i > 0);
                set("str", 20);
            }
        ''')
        self.assertEqual(lpc.sets(), {'age': 30, 'str': 20})
        self.assertEqual([f.split(':')[0] for f in lpc.findings], ['for in create()', 'do in create()'])

    def test_inherit_by_path_is_a_finding(self) -> None:
        lpc = parse('inherit NPC;\ninherit __DIR__"base";\nvoid create() { set("age", 0x10); }')
        self.assertEqual(lpc.inherits, ['NPC', '__DIR__"base"'])
        self.assertEqual(lpc.findings, ['inherit by path: __DIR__"base"'])
        self.assertEqual(lpc.sets(), {'age': ci.Unknown('0x10')})

    def test_clonep_branch_must_only_set_the_default_object(self) -> None:
        lpc = parse('void create() { if (clonep()) { set_default_object(__FILE__); set("x", 1); } else set("y", 2); }')
        self.assertEqual(lpc.sets(), {'y': 2})
        self.assertEqual(lpc.findings, ['condition in create(): clonep() branch does more than set_default_object'])


class OutputTest(unittest.TestCase):
    def test_fields_inline_until_too_wide(self) -> None:
        text = ci.render('spawns', [{'id': 'a', 'points': ['x' * 50, 'y' * 50], 'exits': {'north': 'b'}}])
        self.assertIn('\t\t\t"points": [\n\t\t\t\t"' + 'x' * 50, text)
        self.assertIn('\t\t\t"exits": {\n\t\t\t\t"north": "b"\n\t\t\t}', text)
        self.assertEqual(json.loads(text)['spawns'][0]['id'], 'a')


if __name__ == '__main__':
    unittest.main()
