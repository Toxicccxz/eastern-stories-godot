"""The generated world maps are exactly what tools/maps paints from their layouts."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.maps import paint  # noqa: E402

def generated() -> dict[str, list[str]]:
    """Region folder -> the scene files of its maps, read from every game/data/*/world.json: a
    map's scene lives under game/scenes/world/<folder>/ and is painted from layouts/<folder>.json."""
    out: dict[str, list[str]] = {}
    for world in sorted((REPOSITORY / 'game/data').glob('*/world.json')):
        for m in json.loads(world.read_text(encoding='utf-8')).get('maps', []):
            folder, file = m['scene'].removeprefix('res://scenes/world/').split('/')
            out.setdefault(folder, []).append(file)
    return out


GENERATED = generated()


def first_difference(committed: bytes, painted: bytes) -> str:
    for number, (a, b) in enumerate(zip(committed.split(b'\n'), painted.split(b'\n')), 1):
        if a != b:
            return f'line {number}: committed {a[:120]!r}, painted {b[:120]!r}'
    return f'lengths differ: committed {len(committed)} bytes, painted {len(painted)} bytes'


class MapsPaintTest(unittest.TestCase):
    def test_layouts_are_the_generated_maps(self) -> None:
        self.assertEqual(paint.regions(), sorted(GENERATED))
        for region, files in GENERATED.items():
            with self.subTest(region=region):
                self.assertEqual(sorted(e['file'] for e in paint.layout(region)['maps'].values()), sorted(files))

    def test_committed_scenes_are_the_painted_output(self) -> None:
        for region, files in GENERATED.items():
            scenes = paint.generate(region)
            for file in files:
                with self.subTest(map=f'{region}/{file}'):
                    committed = (paint.WORLD / region / file).read_bytes()
                    painted = scenes[file].encode('utf-8')
                    if committed != painted:
                        self.fail(f'{first_difference(committed, painted)}; edit tools/maps/layouts/{region}.json '
                                  f'and rerun: python -m tools.maps.paint {region}')

    def test_written_files_are_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as out, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(paint.main(['snow', '--out', out]), 0)
            for file in GENERATED['snow']:
                with self.subTest(map=file):
                    self.assertEqual((Path(out) / 'snow' / file).read_bytes(),
                                     (paint.WORLD / 'snow' / file).read_bytes())
            self.assertEqual(paint.main(['snow', '--check']), 0)

    def test_a_canvas_maps_fill_steps_carry_furnishings(self) -> None:
        draw = {'technique': 'canvas', 'steps': [
            {'op': 'blobs', 'blobs': []},
            {'op': 'fill', 'fills': [['grass', 0, 0, 32, 32],
                                     ['blocked', 32, 48, 64, 64, 'a fire', {'look': {'kind': 'campfire'}}]]}]}
        text = paint.furnishings(draw)
        self.assertIn('metadata/look = {"kind": "campfire"}', text)
        self.assertIn('position = Vector2(48, 56)', text)
        self.assertIn('metadata/footprint = Vector2(32, 16)', text)

    def test_maps_with_watchers_have_cover_and_light(self) -> None:
        """WorldMapWatches reads a furnishing's look for `cover` (true: it blocks a watcher's sight)
        and `light` (a radius in pixels: the player is seen farther in it). A misspelt or mistyped one
        is silent, so: each is the right type wherever it stands, and every map a watcher walks has
        at least one of each (全项目审查第四批)."""
        watchers = set()
        for path in (REPOSITORY / 'game/data').glob('*/npcs.json'):
            for npc in json.loads(path.read_text(encoding='utf-8')).get('npcs', []):
                if 'watch' in npc:
                    watchers.add(npc['id'])
        watched_maps = set()
        for path in (REPOSITORY / 'game/data').glob('*/spawns.json'):
            for spawn in json.loads(path.read_text(encoding='utf-8')).get('spawns', []):
                if spawn.get('npc') in watchers:
                    watched_maps.add(spawn['map'])
        self.assertTrue(watched_maps, 'some map has watchers (皇城)')

        def looks(node):
            if isinstance(node, dict):
                if isinstance(node.get('look'), dict):
                    yield node['look']
                for key, value in node.items():
                    if key != 'look':
                        yield from looks(value)
            elif isinstance(node, list):
                for value in node:
                    yield from looks(value)

        seen = set()
        for region in paint.regions():
            for entry in paint.layout(region)['maps'].values():
                map_id = entry['scene']['map']
                found = list(looks(entry['draw']))
                for look in found:
                    with self.subTest(map=map_id, kind=look.get('kind')):
                        if 'cover' in look:
                            self.assertIs(look['cover'], True, 'cover is true or absent')
                        if 'light' in look:
                            self.assertTrue(isinstance(look['light'], (int, float)) and look['light'] > 0, 'light is a radius')
                if map_id in watched_maps:
                    seen.add(map_id)
                    with self.subTest(map=map_id):
                        self.assertTrue(any(look.get('cover') is True for look in found), 'a watched map has cover')
                        self.assertTrue(any(isinstance(look.get('light'), (int, float)) and look['light'] > 0 for look in found), 'and light')
        self.assertEqual(seen, watched_maps, 'every watched map is a painted one')

    def test_zones_of_a_map_never_overlap(self) -> None:
        """Every committed map's zones lie apart (a body in two zones could never be saved), and the
        painter refuses two that overlap whatever technique drew them (关北 steppe, 2026-11-12)."""
        for folder, files in GENERATED.items():
            for file in files:
                with self.subTest(map=f'{folder}/{file}'):
                    text = (paint.WORLD / folder / file).read_text(encoding='utf-8')
                    self.assertTrue(paint._ZONE.search(text) is not None or 'parent="Zones"' not in text)
                    paint.zones_apart(text, file)

        def zone(name: str, at: tuple, shape: str) -> str:
            return (f'[node name="{name}" type="Area2D" parent="Zones"]\nposition = Vector2({at[0]}, {at[1]})\n'
                    f'collision_layer = 0\nscript = ExtResource("zone")\nzone_id = &"t.{name}"\n\n'
                    f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Zones/{name}"]\n'
                    f'shape = SubResource("{shape}")\n\n')
        shapes = ('[sub_resource type="RectangleShape2D" id="Rect_64_64"]\nsize = Vector2(64, 64)\n\n')
        paint.zones_apart(shapes + zone('a', (32, 32), 'Rect_64_64') + zone('b', (96, 32), 'Rect_64_64'), 'edge to edge')
        with self.assertRaises(AssertionError):
            paint.zones_apart(shapes + zone('a', (32, 32), 'Rect_64_64') + zone('b', (80, 48), 'Rect_64_64'), 'overlap')


if __name__ == '__main__':
    unittest.main()
