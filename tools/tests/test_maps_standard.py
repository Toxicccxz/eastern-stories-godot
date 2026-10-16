"""The scale standard: street classes, facades with doors, interiors laid out from their exits,
the building size checks and the filler trim (tools/maps/standard.py)."""

from __future__ import annotations

import copy
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.maps import paint, standard  # noqa: E402
from tools.maps.region import Region  # noqa: E402

ROOMS = [
    {'id': 'es2:t/street', 'short': '大街', 'long': '一条大街。\n', 'exits': {'west': 'es2:t/shop'}},
    {'id': 'es2:t/shop', 'short': '店铺', 'long': '一间宽敞的店铺。\n', 'exits': {'east': 'es2:t/street', 'west': 'es2:t/store'}},
    {'id': 'es2:t/store', 'short': '库房', 'long': '堆满货物的库房。\n', 'exits': {'east': 'es2:t/shop'}},
]
WORLD = {
    'regions': [{'id': 't', 'name': '测试镇'}],
    'maps': [{'id': 't.street_map', 'region': 't', 'scene': 'res://scenes/world/t/t_street.tscn', 'entry': 't.street.start'},
             {'id': 't.shop_map', 'region': 't', 'scene': 'res://scenes/world/t/t_shop.tscn', 'entry': 't.shop.from_street'}],
    'zones': [{'id': 't.street', 'map': 't.street_map', 'rooms': ['es2:t/street']},
              {'id': 't.shop', 'map': 't.shop_map', 'rooms': ['es2:t/shop']},
              {'id': 't.store', 'map': 't.shop_map', 'rooms': ['es2:t/store']}],
    'portals': [
        {'id': 't.street.west', 'from_zone': 't.street', 'to_zone': 't.shop', 'to_spawn': 't.shop.from_street',
         'legacy_room': 'es2:t/street', 'legacy_command': 'west'},
        {'id': 't.shop.east', 'from_zone': 't.shop', 'to_zone': 't.street', 'to_spawn': 't.street.from_shop',
         'legacy_room': 'es2:t/shop', 'legacy_command': 'east'},
    ],
}
SPAWNS = {'spawns': [{'id': 't.shop.keeper', 'map': 't.shop_map', 'zone': 't.shop', 'points': ['t.shop.keeper.1'],
                      'legacy_room': 'es2:t/shop'}]}


def scene(map_id: str, root: str, points: list) -> dict:
    return {'style': 'map', 'root': root, 'map': map_id, 'player_color': 'Color(1, 1, 1, 1)', 'shapes': {},
            'nodes': [{'generated': 'captions'}], 'zones': [{'generated': 'zones'}],
            'spawn_points': points + [{'generated': 'markers'}]}


STREET = {
    'file': 't_street.tscn',
    'draw': {'technique': 'town', 'base': 'boundary', 'bounds': [-640, -640, 640, 640], 'ground': [],
             'zones': {'t.street': {'street': 'main', 'axis': 'y', 'centre': 0, 'span': [-512, 512]}},
             'buildings': [{'name': '店铺', 'street': 't.street', 'side': 'west', 'frontage': 'shop', 'at': 0,
                            'doors': ['t.street.west']},
                           {'name': '民居', 'street': 't.street', 'side': 'west', 'frontage': 'small', 'at': -384}],
             'reach_from': 'Start', 'placed': {}},
    'scene': scene('t.street_map', 'TStreet', [{'name': 'Start', 'at': [0, 400], 'id': 't.street.start'}]),
}
SHOP = {
    'file': 't_shop.tscn',
    'draw': {'technique': 'interior', 'building': 'shop',
             'rooms': {'t.shop': {'size': 'large', 'floor': 'floor_shop'}, 't.store': {'size': 'small'}},
             'props': [['blocked', 't.shop', 'n', 6, 1, 'the counter']],
             'placed': {'t.shop.keeper.1': ['t.shop', ['n', 0, 2]]},
             'reach_from': 'ShopFromStreet'},
    'scene': scene('t.shop_map', 'TShop', []),
}


class StandardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        data = Path(self.dir.name) / 't'
        data.mkdir()
        for name, value in (('rooms.json', {'rooms': ROOMS}), ('world.json', WORLD), ('spawns.json', SPAWNS)):
            (data / name).write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
        self.region = Region('t', Path(self.dir.name))
        self.saved = copy.deepcopy(standard.STANDARD)

    def tearDown(self) -> None:
        standard.STANDARD.clear()
        standard.STANDARD.update(self.saved)
        self.dir.cleanup()

    def test_a_street_is_as_wide_as_its_class(self) -> None:
        x0, y0, x1, y1, *_ = standard.prepare_town(self.region, STREET)['draw']['zones']['t.street']
        self.assertEqual(x1 - x0, standard.px(standard.STANDARD['street']['main'], 32))
        self.assertEqual((y0, y1), (-512, 512))

    def test_a_facade_stands_on_its_street_with_its_door(self) -> None:
        entry = standard.prepare_town(self.region, STREET)
        street = entry['draw']['zones']['t.street']
        wall = entry['draw']['ground'][0]
        self.assertEqual(wall[3], street[0], 'the facade backs onto the street edge')
        self.assertEqual(wall[3] - wall[1], standard.px(standard.STANDARD['facade']['depth']['shop']))
        passage = next(n for n in entry['scene']['nodes'] if n.get('node') == 'passage')
        self.assertEqual(passage['id'], 't.street.west')
        self.assertTrue(street[0] < passage['at'][0] < street[0] + 64, 'the passage stands just inside the street')
        marker = next(m for m in entry['scene']['spawn_points'] if m.get('id') == 't.street.from_shop')
        self.assertGreater(marker['at'][0], passage['at'][0], 'the way back out arrives in front of the door')
        text = paint.paint_map(self.region, STREET)
        self.assertIn('portal_id = &"t.street.west"', text)

    def test_facades_keep_an_alley(self) -> None:
        crowded = copy.deepcopy(STREET)
        crowded['draw']['buildings'][1]['at'] = -224
        with self.assertRaises(AssertionError):
            standard.prepare_town(self.region, crowded)

    def test_a_wider_street_carries_its_buildings(self) -> None:
        before = standard.prepare_town(self.region, STREET)['draw']['ground'][0]
        standard.STANDARD['street']['main'] = 10.0
        after = standard.prepare_town(self.region, STREET)['draw']['ground'][0]
        self.assertLess(after[1], before[1], 'the facade moves out with the street edge')
        self.assertEqual(after[3] - after[1], before[3] - before[1])

    def test_an_interior_lays_its_rooms_out_by_their_exits(self) -> None:
        entry = standard.prepare_interior(self.region, SHOP)
        zones = entry['draw']['zones']
        shop, store = zones['t.shop'], zones['t.store']
        self.assertEqual(store[2], shop[0], 'the store lies west of the shop, wall to wall')
        self.assertTrue(store[1] < shop[3] and shop[1] < store[3])
        wall = standard.wall_px()
        floor = standard.room_floor('large')
        self.assertEqual(shop[2] - shop[0], floor[0] + 2 * wall)
        doorway = next(p for p in entry['draw']['props'] if p[-1] == 'the doorway out')
        self.assertEqual((doorway[1], doorway[3]), (shop[2] - wall, shop[2]), 'the way out is in the east wall')
        counter = next(p for p in entry['draw']['props'] if p[-1] == 'the counter')
        self.assertEqual(counter[2], shop[1] + wall, 'the counter stands against the north wall')
        self.assertEqual(counter[3] - counter[1], standard.px(6))
        keeper = entry['draw']['placed']['t.shop.keeper.1']
        self.assertGreater(keeper[1], counter[4], 'the keeper stands behind the counter, two bodies off the wall')
        text = paint.paint_map(self.region, SHOP)
        self.assertIn('portal_id = &"t.shop.east"', text)
        self.assertIn('spawn_point_id = &"t.shop.from_street"', text)

    def test_a_building_must_reach_its_class(self) -> None:
        small = copy.deepcopy(SHOP)
        small['draw']['building'] = 'school'
        with self.assertRaises(AssertionError):
            standard.prepare_interior(self.region, small)

    def test_a_building_named_larger_must_be(self) -> None:
        notes: list = []
        bigger = copy.deepcopy(SHOP)
        bigger['draw']['larger_than'] = ['snow/inn']
        with self.assertRaises(AssertionError):
            paint.paint_map(self.region, bigger, notes)
        bigger['draw']['rooms'] = {'t.shop': {'size': 'grand'}, 't.store': {'size': 'grand'}}
        bigger['draw']['props'] = []
        paint.paint_map(self.region, bigger, notes)

    def test_a_description_against_the_size_is_noted(self) -> None:
        small = copy.deepcopy(SHOP)
        small['draw']['rooms']['t.shop']['size'] = 'small'
        small['draw']['props'] = []
        small['draw']['placed'] = {}
        notes: list = []
        paint.paint_map(self.region, small, notes)
        self.assertTrue(any('t.shop' in n and '宽敞' in n for n in notes), notes)

    def test_the_filler_keeps_only_a_skirt(self) -> None:
        text = paint.paint_map(self.region, STREET)
        blob = re.search(r'name="TerrainStructures"[^\n]*\n(?:[^\n]*\n)*?tile_map_data = PackedByteArray\(([^)]*)\)', text).group(1)
        cells = (blob.count(',') + 1 - 2) // 12
        full = (1280 // 16) * (1280 // 16)
        self.assertLess(cells, full // 2, 'most of the empty edge is gone')
        self.assertIn('[node name="Backdrop" type="ColorRect" parent="."]', text)


if __name__ == '__main__':
    unittest.main()
