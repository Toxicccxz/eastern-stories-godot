"""The generated world maps are exactly what tools/maps paints from their layouts."""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.maps import paint  # noqa: E402

GENERATED = {
    'oldpine': ['oldpine_outdoor.tscn', 'oldpine_cave.tscn', 'oldpine_gorge.tscn', 'oldpine_tree.tscn', 'oldpine_cliff.tscn',
                'oldpine_stone.tscn', 'oldpine_caves.tscn', 'oldpine_cliff2.tscn'],
    'snow': ['snow_outdoor.tscn', 'snow_inn.tscn', 'snow_inn_upstairs.tscn', 'snow_cellar.tscn'],
    'cloud': ['cloud_outdoor.tscn', 'cloud_tearoom_upstairs.tscn', 'cloud_jiyuan_upstairs.tscn', 'cloud_duchang_upstairs.tscn'],
    'goathill': ['goathill_mountain.tscn', 'goathill_caverns.tscn'],
    'waterfog': ['waterfog_mountain.tscn', 'waterfog_pavilion.tscn', 'waterfog_upstairs.tscn'],
    'green': ['green_village.tscn', 'green_mountain.tscn', 'green_maze.tscn'],
    'temple': ['temple_mountain.tscn', 'temple_grounds.tscn', 'temple_library.tscn'],
    'latemoon': ['latemoon_manor.tscn', 'latemoon_secret.tscn', 'latemoon_garden.tscn', 'latemoon_upper.tscn', 'latemoon_hills.tscn'],
    'sanyen': ['sunhill_mountain.tscn', 'sanyen_temple.tscn'],
    'choyin': ['choyin_town.tscn', 'choyin_yamen.tscn', 'choyin_altar.tscn', 'choyin_hotel_2f.tscn', 'choyin_hotel_3f.tscn',
               'choyin_tree_hollow.tscn', 'choyin_lion_cave.tscn', 'choyin_east.tscn', 'choyin_furnace.tscn', 'choyin_guye.tscn',
               'choyin_crown.tscn', 'choyin_cliff_cave.tscn', 'choyin_summit.tscn', 'choyin_valley.tscn'],
}


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


if __name__ == '__main__':
    unittest.main()
