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

    def test_art_pictures_stand_on_their_boxes(self) -> None:
        """A map drawn by pictures (scene.art): its tiles hidden but kept, its stairs bare, and each
        prop's picture standing on the bottom edge of the box that is its collision."""
        for region in paint.regions():
            for entry in paint.layout(region)['maps'].values():
                if 'art' not in entry['scene']:
                    continue
                with self.subTest(map=entry['scene']['map']):
                    text = (paint.WORLD / region / entry['file']).read_text(encoding='utf-8')
                    self.assertIn('[node name="Terrain" type="Node2D" parent="."]\nvisible = false\n', text)
                    self.assertIn('PackedByteArray(', text.split('[node name="TerrainStructures"')[1].split('[node')[0])
                    self.assertNotIn('type="Polygon2D" parent="StairsUp"', text)
                    sprites = text.split('[node name="Props"')[1].split('[node name="CorpseLayer"')[0]
                    for row in entry['draw']['props']:
                        if not (isinstance(row[-1], dict) and 'art' in row[-1]):
                            continue
                        x0, _y0, x1, y1 = row[1:5]
                        w, h = paint.png_size(row[-1]['art'])
                        self.assertIn(f'position = Vector2({(x0 + x1) // 2}, {y1})\nscale = Vector2(2, 2)\n', sprites)
                        self.assertIn(f'offset = Vector2({-w // 2}, {-h})', sprites)
                        self.assertLessEqual(w * 2 - (x1 - x0), 8, ('a picture no wider than its box', row))

    def test_written_files_are_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as out, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(paint.main(['snow', '--out', out]), 0)
            for file in GENERATED['snow']:
                with self.subTest(map=file):
                    self.assertEqual((Path(out) / 'snow' / file).read_bytes(),
                                     (paint.WORLD / 'snow' / file).read_bytes())
            self.assertEqual(paint.main(['snow', '--check']), 0)


if __name__ == '__main__':
    unittest.main()
