"""Lived-in corner pieces (tools/maps/life.py): placed by a room's use, clear of what the player
walks to, the same every time."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.maps import life, paint, standard  # noqa: E402
from tools.maps.region import Region  # noqa: E402
from tools.maps.tiles import T  # noqa: E402


def drawn_entry(key: str):
    """(prepared entry, its first drawing, its pieces) of a snow map."""
    region = Region('snow', paint.DATA)
    entry = paint.layout('snow')['maps'][key]
    entry = standard.prepare_interior(region, entry) if entry['draw']['technique'] == 'interior' else copy.deepcopy(entry)
    drawn = paint.TECHNIQUES[entry['draw']['technique']](region, entry)
    return entry, drawn, life.dress(entry, drawn)


class MapsLifeTest(unittest.TestCase):
    def test_every_use_names_known_pieces(self) -> None:
        table = life.presets()
        for use, spec in table['uses'].items():
            for piece in spec.get('pieces', []):
                self.assertEqual(len(piece['size']), 2, use)
                self.assertTrue(all(v % T == 0 for v in piece['size']), (use, piece))
            self.assertTrue(set(spec) <= {'walls', 'grime', 'hangings', 'hang', 'tables', 'pieces', 'count', 'scatter', 'spread'}, use)
        self.assertEqual(set(table['wealth']), {'poor', 'plain', 'rich'})

    def test_every_layout_use_is_a_preset(self) -> None:
        table = life.presets()
        seen = set()
        for path in sorted((REPOSITORY / 'tools/maps/layouts').glob('*.json')):
            for key, entry in json.loads(path.read_text(encoding='utf-8'))['maps'].items():
                for zone, spec in life.rooms_of(entry).items():
                    self.assertIn(spec['use'], table['uses'], (path.name, key, zone))
                    self.assertIn(spec.get('wealth', 'plain'), table['wealth'], (path.name, key, zone))
                    # A room's spec may override its preset's fields (house2's own hangings).
                    self.assertTrue(set(spec) <= {'use', 'wealth', 'seed', 'tidy', 'count', 'keep_clear'} | set(table['uses'][spec['use']]), (path.name, key, zone))
                    seen.add(spec['use'])
        # B + C: 绮云镇, 水烟阁, 聚义厅, 土地庙 and 石室 each use their own presets.
        for use in ('escort_office', 'butcher', 'gaming_hall', 'pleasure_house', 'teahouse', 'coffin_shop',
                    'parlour', 'woodshed', 'servants_room', 'terrace_hall', 'bandit_hall', 'stone_chamber'):
            self.assertIn(use, seen)

    def test_smithy_corners_hold_iron_goods_clear_of_the_smith_and_the_door(self) -> None:
        entry, drawn, rows = drawn_entry('smithy')
        kinds = [row[-1]['look']['kind'] for row in rows]
        # 打铁铺子: 「角落里堆满了各式铁器」.
        self.assertGreaterEqual(kinds.count('iron_goods'), 3, kinds)
        walk = drawn.tiles.walkable_cells()
        keep, points, _ = life._keep(entry, drawn, walk)
        taken = set()
        for row in rows:
            cells = life._box_cells(tuple(row[1:5]))
            self.assertFalse(cells & keep, row)
            self.assertTrue(cells <= walk, row)
            self.assertFalse(cells & taken, row)
            taken |= cells
        self.assertEqual(life._reached(walk - taken, points), life._reached(walk, points))

    def test_pieces_keep_off_what_the_voxel_config_stands_or_hangs(self) -> None:
        # The inn's lamps, its 红木门 (a rect door and the red_door prop), signs over leaning tools.
        for key in ('inn', 'cellar', 'academy', 'smithy', 'workplace', 'herbshop', 'temple'):
            entry, drawn, rows = drawn_entry(key)
            keep, _, tall = life._keep(entry, drawn, drawn.tiles.walkable_cells())
            for row in rows:
                cells = life._box_cells(tuple(row[1:5]))
                self.assertFalse(cells & keep, (key, row))
                if row[-1]['look'].get('kind') in ('lumber',) or row[-1]['look'].get('heap', 'tools') in ('tools', 'blades') and row[-1]['look']['kind'] == 'iron_goods':
                    self.assertFalse(cells & tall, (key, row))
            for prop in life.config_props(entry):
                if prop['kind'] in life.FLAT or prop.get('wall_mounted') or prop['kind'] in ('window', 'sign', 'wall_scroll'):
                    continue
                x, y = prop['at']
                for row in rows:
                    x0, y0, x1, y1 = row[1:5]
                    self.assertFalse(x0 - 16 < x < x1 + 16 and y0 - 16 < y < y1 + 16, (key, prop, row))

    def test_leaning_pieces_stand_at_the_north_wall(self) -> None:
        for key in ('smithy', 'workplace', 'school'):
            _, _, rows = drawn_entry(key)
            for row in rows:
                if row[-1]['look']['kind'] == 'lumber' or (row[-1]['look']['kind'] == 'iron_goods' and row[-1]['look'].get('heap', 'tools') in ('tools', 'blades')):
                    self.assertEqual(row[-1]['look']['rotation'], 0, row)

    def test_same_seed_same_pieces_and_seed_changes_them(self) -> None:
        _, _, first = drawn_entry('temple')
        _, _, again = drawn_entry('temple')
        self.assertEqual(first, again)
        entry, drawn, _ = drawn_entry('temple')
        entry['draw']['life']['snow.temple']['seed'] = 2
        self.assertNotEqual(life.dress(entry, drawn), first)

    def test_scene_carries_each_rooms_life(self) -> None:
        text = (REPOSITORY / 'game/scenes/world/snow/snow_inn_upstairs.tscn').read_text(encoding='utf-8')
        self.assertIn('[node name="RoomLife" type="Node" parent="."]', text)
        self.assertIn('"snow.e_room": {"seed": 2, "tidy": true, "use": "guest_room"}', text)
        self.assertEqual(life.scene_node({}), '')


if __name__ == '__main__':
    unittest.main()
