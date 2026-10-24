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


if __name__ == '__main__':
    unittest.main()
