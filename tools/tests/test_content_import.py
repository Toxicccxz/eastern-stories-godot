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

    def test_no_lost_character_reaches_the_game(self) -> None:
        # □ marks a character lost in ES2's Big5 conversion; text_replacements.json
        # decides each (owner, modern fixes II). Only skills.c's own enabled-skill
        # mark (martial_arts_page.gd MAPPED_MARK) may show one.
        lost = '□'
        found = []
        for path in sorted(ci.DATA.rglob('*.json')):
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if lost in line:
                    found.append(f'{path.relative_to(REPOSITORY).as_posix()}:{number}')
        for path in sorted((REPOSITORY / 'game').rglob('*.gd')):
            if '.godot' in path.parts or 'tests' in path.parts or path.name == 'martial_arts_page.gd':
                continue
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if lost in line and not line.lstrip().startswith('#'):
                    found.append(f'{path.relative_to(REPOSITORY).as_posix()}:{number}')
        self.assertEqual(found, [], 'decide the character in tools/migration/text_replacements.json')

    def test_ghosts_wait_for_the_taoist_sword(self) -> None:
        # Reminder (茅山 A): daemon/class/taoist/sword.c's hit_ob() (林忌's 咒剑王禅) acts
        # only on a victim whose is_ghost() is true, and no NPC in the game is one yet.
        # The region that places a ghost (乔阴's ghost.c and shadow.c, 鬼门关) ports it.
        ghosts = []
        for path in sorted(ci.DATA.rglob('npcs.json')):
            for record in json.loads(path.read_text(encoding='utf-8')).get('npcs', []):
                source = ci.MUDLIB / record['legacy_source']
                if 'is_ghost' in source.read_text(encoding='utf-8', errors='replace'):
                    ghosts.append(record['id'])
        self.assertEqual(ghosts, [], 'port daemon/class/taoist/sword.c hit_ob() with these ghosts')

    def test_generated_files_are_loaded(self) -> None:
        manifest = json.loads((ci.DATA / 'content_manifest.json').read_text(encoding='utf-8'))['files']
        self.assertEqual(sorted(set(self.files) - set(manifest)), [])

    def test_old_pine_keeps_its_hand_checked_records(self) -> None:
        npcs = {r['id']: r for r in json.loads(self.files['oldpine/npcs.json'])['npcs']}
        self.assertEqual(list(npcs), ['oldpine.npc.bandit', 'oldpine.npc.tall_bandit',
                                      'oldpine.npc.fat_bandit', 'oldpine.npc.serpent', 'oldpine.npc.maniac',
                                      'oldpine.npc.wolf_dog', 'oldpine.npc.butterfly', 'oldpine.npc.bandit_guard',
                                      'oldpine.npc.bandit_leader', 'oldpine.npc.bandit_commander',
                                      'oldpine.npc.spy', 'oldpine.npc.venomsnake'])
        self.assertEqual(npcs['oldpine.npc.serpent']['race'], 'beast')
        self.assertEqual(npcs['oldpine.npc.fat_bandit']['carry'][1]['item'], 'es2:d/oldpine/obj/leather')
        # set("bellicosity") is data; set_temp("apply/defense") joins the other applies.
        self.assertEqual(npcs['oldpine.npc.maniac']['bellicosity'], 10000)
        self.assertEqual(npcs['oldpine.npc.bandit_commander']['apply'], {'attack': 100, 'defense': 60})
        # carry_object(dust)->set_amount(30): a combined item's carried amount.
        self.assertEqual(npcs['oldpine.npc.spy']['carry'][2], {'item': 'es2:obj/dust', 'source': 'obj/dust.c', 'amount': 30})
        items = {r['id']: r for r in json.loads(self.files['common/items.json'])['items']}
        # COMBINED_ITEM: base_unit, base_weight and create()'s set_amount(); snake_drug.c's
        # base_weiht typo leaves base_weight 0.
        self.assertEqual(items['es2:obj/drug/snake_drug']['combined'], {'base_unit': '份', 'base_weight': 0, 'amount': 1})
        knives = {r['id']: r for r in json.loads(self.files['snow/items.json'])['items']}['es2:d/snow/npc/obj/throwing_knife']
        # THROWING is a combined weapon: init_throwing(20), set_amount(100).
        self.assertEqual([knives['combined']['amount'], knives['weapon']], [100, {'skill': 'throwing', 'damage': 20}])

    def test_heavy_equipment_names_the_setup_it_runs(self) -> None:
        # create()'s setup(): std/equip.c (std/weapon/<kind>.c) or std/armor/<type>.c, each
        # costing a heavy one dodge (ItemContentDefinition's rule, DECISIONS A1).
        snow = {r['id']: r for r in json.loads(self.files['snow/items.json'])['items']}
        self.assertEqual(snow['es2:d/snow/obj/lumber_axe']['weapon']['weight_dodge'], 'equip')
        self.assertEqual(snow['es2:d/snow/obj/shield']['armor']['weight_dodge'], 'armor')
        # throwing.c has a setup() of its own; 天师道袍 inherits EQUIP and never calls setup().
        self.assertNotIn('weight_dodge', snow['es2:d/snow/npc/obj/throwing_knife']['weapon'])
        common = {r['id']: r for r in json.loads(self.files['common/items.json'])['items']}
        self.assertNotIn('weight_dodge', common['es2:daemon/class/taoist/robe']['armor'])
        lpc = parse('inherit EQUIP;\nvoid create() { set_name("冠", ({ "hat" })); set("armor_type", "head"); setup(); }')
        self.assertTrue(lpc.calls_setup)
        self.assertEqual(lpc.calls, [ci.Call('set_name', ['冠', ['hat']], []), ci.Call('set', ['armor_type', 'head'], [])])

    def test_vendor_goods_from_lpc_or_hand_read_buy_object(self) -> None:
        vendors = {r['id']: r for r in json.loads(self.files['snow/vendors.json'])['vendors']}
        # herbalist.c sets vendor_goods (the value is the price).
        self.assertEqual(vendors['snow.vendor.herbalist']['goods'], [{'key': 'medicine', 'item': 'es2:obj/drug/hurt_drug'},
                                                                   {'key': 'snake drug', 'item': 'es2:obj/drug/snake_drug'}])
        # smith.c has no vendor_goods: its buy_object() asks 300 for a hammer worth 3.
        self.assertEqual(vendors['snow.vendor.smith']['goods'], [{'key': '铁锤', 'item': 'es2:d/snow/obj/hammer', 'price': 300}])

    def test_items_a_room_places_lie_on_its_floor(self) -> None:
        spawns = {r['id']: r for r in json.loads(self.files['snow/item_spawns.json'])['item_spawns']}
        # room.c make_inventory(): an object that is no NPC is an item on the floor.
        self.assertEqual(spawns['snow.outdoor.weapon_storage.bamboo_sword']['points'], ['snow.weapon_storage.bamboo_sword.1'])
        self.assertEqual(spawns['snow.cellar.secret_storage.shield']['zone'], 'snow.secret_storage')
        items = {r['id']: r for r in json.loads(self.files['snow/items.json'])['items']}
        # denotation.c: no set_weight() leaves move.c's `weight = 0`; set("no_get", 1) is data.
        box = items['es2:d/snow/obj/denotation']
        self.assertEqual((box['weight'], box['no_get']), (0, True))
        self.assertNotIn('snow.outdoor.temple.paper_seal', spawns)

    def test_a_book_teaches_what_its_skill_mapping_says(self) -> None:
        items = {r['id']: r for r in json.loads(self.files['common/items.json'])['items']}
        # obj/old_book.c set("skill", ([...])): study.c reads it; `name` becomes `skill`.
        self.assertEqual(items['es2:obj/old_book']['study'], {
            'skill': 'force', 'exp_required': 0, 'sen_cost': 30, 'difficulty': 20, 'max_skill': 10})

    def test_npcs_bound_to_services_and_teachers(self) -> None:
        npcs = {r['id']: r for r in json.loads(self.files['snow/npcs.json'])['npcs']}
        # A vendor sells from its body; rank_info/respect is how others address it.
        self.assertEqual(npcs['snow.npc.waiter']['vendor'], 'snow.vendor.waiter')
        self.assertEqual(npcs['snow.npc.waiter']['rank_info'], {'respect': '小二哥'})
        self.assertNotIn('vendor', npcs['snow.npc.annihir'])  # bank.c is the room's convert, not his
        # schoolhall.c places CLASS_D("swordsman") + "/master": a class daemon's NPC keeps its class.
        master = {r['id']: r for r in json.loads(self.files['common/npcs.json'])['npcs']}['common.npc.swordsman.master']
        self.assertEqual(master['family'], {'name': '封山剑派', 'generation': 13, 'title': '掌门人'})
        self.assertEqual((master['nickname'], master['f_master']), ('风雨双侠', True))
        spawns = {r['id']: r for r in json.loads(self.files['snow/spawns.json'])['spawns']}
        self.assertEqual(spawns['snow.outdoor.schoolhall.master']['npc'], 'common.npc.swordsman.master')
        items = {r['id']: r for r in json.loads(self.files['common/items.json'])['items']}
        # silk_cloth.c inherits EQUIP and sets its armor_type itself.
        self.assertEqual(items['es2:daemon/class/swordsman/silk_cloth']['armor'], {'type': 'cloth', 'props': {'dodge': 6, 'armor': 1}})
        snow_items = {r['id']: r for r in json.loads(self.files['snow/items.json'])['items']}
        self.assertEqual(snow_items['es2:d/snow/obj/denotation']['max_encumbrance'], 10000)

    def test_hand_read_vendor_goods_are_checked(self) -> None:
        importer = ci.Importer(ci.Corpus(), ci.DATA)
        for entry in ({'price': 300}, {'item': 'd/snow/npc/obj/hammer.c', 'price': 0},
                      {'item': 'd/snow/npc/obj/hammer.c', 'price': '300'}, {'item': 'd/snow/npc/obj/hammer.c', 'cost': 1}):
            with self.subTest(entry=entry), self.assertRaises(ci.ImportError_):
                importer.vendor('snow', 'd/snow/npc/smith.c', {}, {'铁锤': entry})
        with self.assertRaises(ci.ImportError_):
            importer.vendor('snow', 'd/snow/npc/herbalist.c', {}, {'medicine': {'item': 'obj/drug/hurt_drug.c'}})


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

    def test_class_d_path_macro(self) -> None:
        lpc = parse('void create() { set("objects", ([ CLASS_D("swordsman") + "/master": 1 ])); }', 'd/test/hall.c')
        self.assertEqual(lpc.sets(), {'objects': {'/daemon/class/swordsman/master': 1}})
        self.assertEqual(ci.npc_id('daemon/class/swordsman/master.c'), 'common.npc.swordsman.master')
        self.assertEqual(ci.npc_id('d/snow/npc/dog.c'), 'snow.npc.dog')

    def test_npc_ids_keep_a_subdirectory_apart(self) -> None:
        self.assertEqual(ci.npc_id('d/latemoon/npc/servant.c'), 'latemoon.npc.servant')
        self.assertEqual(ci.npc_id('d/latemoon/room/npc/servant.c'), 'latemoon.npc.room.servant')
        self.assertEqual(ci.npc_id('d/latemoon/park/npc/bird.c'), 'latemoon.npc.park.bird')

    def test_a_lost_character_in_a_string_is_a_box(self) -> None:
        lpc = parse('void create() { set("long", @LONG\n放开一切\ufffd 所有\nLONG\n); }', 'd/test/room.c')
        self.assertEqual(lpc.sets(), {'long': '放开一切\u25a1 所有\n'})
        with self.assertRaises(ci.ImportError_):
            parse('void create() { set\ufffd("long", "x"); }', 'd/test/room.c')

    def test_a_source_fix_repairs_a_file_once(self) -> None:
        corpus = ci.Corpus(REPOSITORY / 'reference/es2/mudlib')
        with self.assertRaises(ci.ImportError_):
            corpus.get('d/latemoon/sroad1.c')
        corpus = ci.Corpus(REPOSITORY / 'reference/es2/mudlib')
        corpus.fixes['d/latemoon/sroad1.c'] = [{'find': '"north: __DIR__"park/moondoor",', 'replace': '"north" : __DIR__"park/moondoor",'}]
        self.assertEqual(corpus.get('d/latemoon/sroad1.c').sets()['exits'],
                         {'north': '/d/latemoon/park/moondoor', 'southeast': '/d/latemoon/sroad2'})
        corpus = ci.Corpus(REPOSITORY / 'reference/es2/mudlib')
        corpus.fixes['d/latemoon/sroad2.c'] = [{'find': 'no such text', 'replace': 'x'}]
        with self.assertRaises(ci.ImportError_):
            corpus.get('d/latemoon/sroad2.c')

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


class RoomTest(unittest.TestCase):
    def test_no_fight_and_no_magic(self) -> None:
        record = ci.Importer(ci.Corpus(), ci.DATA).room('d/city/bank.c')
        self.assertEqual((record.get('no_fight'), record.get('no_magic')), (True, True))
        record = ci.Importer(ci.Corpus(), ci.DATA).room('d/snow/bank.c')
        self.assertEqual((record.get('no_fight'), record.get('no_magic')), (None, None))


class TalkTest(unittest.TestCase):
    """npc.c chat() and ask.c answers become data only when every part of them is data."""

    def setUp(self) -> None:
        self.importer = ci.Importer(ci.Corpus(), ci.DATA)

    def talk(self, source: str) -> tuple[dict, set[str]]:
        sets, record = parse(source).sets(), {}
        handled = self.importer.chat('d/test/npc/sample.c', sets, record)
        handled |= self.importer.inquiry('d/test/npc/sample.c', sets, record)
        return record, handled

    def test_chat_lines_and_random_move(self) -> None:
        record, handled = self.talk('void create() { set("chat_chance", 6); set("chat_msg", ({ (: random_move :), "x\\n" })); }')
        self.assertEqual(record, {'chat_chance': 6, 'chat_msg': [{'action': 'random_move'}, 'x\n']})
        self.assertEqual(handled, {'chat_chance', 'chat_msg'})

    def test_combat_chat_specials_and_coloured_lines(self) -> None:
        record, handled = self.talk('''void create() { set("chat_chance_combat", 40); set("chat_msg_combat", ({
            CYN "a\\n" NOR, "b\\n", (: perform_action, "sword.counterattack" :), (: cast_spell, "drainerbolt" :),
            (: exert_function, "powerup" :), (: command, "surrender" :) })); }''')
        self.assertEqual(record, {'chat_chance_combat': 40, 'chat_msg_combat': [
            {'say': 'a\n', 'color': 'CYN'}, 'b\n', {'action': 'perform', 'skill': 'sword', 'function': 'counterattack'},
            {'action': 'cast', 'function': 'drainerbolt'}, {'action': 'exert', 'function': 'powerup'},
            {'action': 'surrender'}]})
        self.assertEqual(handled, {'chat_chance_combat', 'chat_msg_combat'})

    def test_combat_chat_without_its_chance_or_with_another_command_stays_a_finding(self) -> None:
        for source in ('void create() { set("chat_msg_combat", ({ "x" })); }',
                       'void create() { set("chat_chance_combat", 10); set("chat_msg_combat", ({ (: command, "flee" :) })); }',
                       'void create() { set("chat_chance_combat", 10); set("chat_msg_combat", ({ (: random_move :) })); }'):
            with self.subTest(source=source):
                record, handled = self.talk(source)
                self.assertEqual((record, handled), ({}, set()))

    def test_chat_with_another_function_or_without_lines_stays_a_finding(self) -> None:
        for source in ('void create() { set("chat_chance", 10); set("chat_msg", ({ (: do_drink :), "x" })); }',
                       'void create() { set("chat_chance", 10); }'):
            with self.subTest(source=source):
                record, handled = self.talk(source)
                self.assertEqual((record, handled), ({}, set()))

    def test_inquiry_answers_keep_strings_only(self) -> None:
        record, handled = self.talk('''void create() { set("inquiry", ([
            "here": "a\\n", "学费": ({ "b", 0, "c" }), "刘安禄": ({ "d", (: follow_player :) }), "寄信": (: send_mail :) ])); }''')
        self.assertEqual(record, {'inquiry': {'here': ['a\n'], '学费': ['b', 'c'], '刘安禄': ['d']}})
        self.assertEqual(handled, {'inquiry'})
        self.assertEqual([(f.key, f.detail) for f in self.importer.findings],
                         [('inquiry 刘安禄', '(: follow_player :)'), ('inquiry 寄信', '(: send_mail :)')])


class OutputTest(unittest.TestCase):
    def test_fields_inline_until_too_wide(self) -> None:
        text = ci.render('spawns', [{'id': 'a', 'points': ['x' * 50, 'y' * 50], 'exits': {'north': 'b'}}])
        self.assertIn('\t\t\t"points": [\n\t\t\t\t"' + 'x' * 50, text)
        self.assertIn('\t\t\t"exits": {\n\t\t\t\t"north": "b"\n\t\t\t}', text)
        self.assertEqual(json.loads(text)['spawns'][0]['id'], 'a')


if __name__ == '__main__':
    unittest.main()
