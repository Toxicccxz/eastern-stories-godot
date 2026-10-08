"""game/data/*/rooms.json must carry the ES2 room text verbatim."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
DATA = REPOSITORY / "game/data"
MUDLIB = REPOSITORY / "reference/es2/mudlib"


def _rooms() -> list[dict]:
    rooms: list[dict] = []
    for path in sorted(DATA.glob("*/rooms.json")):
        rooms.extend(json.loads(path.read_text(encoding="utf-8"))["rooms"])
    return rooms


class RoomDataTest(unittest.TestCase):
    def test_rooms_exist(self) -> None:
        self.assertGreater(len(_rooms()), 0)

    def test_text_and_exits_match_the_lpc_source(self) -> None:
        for room in _rooms():
            with self.subTest(room=room["id"]):
                self.assertTrue(room["id"].startswith("es2:"))
                source = (MUDLIB / (room["id"].removeprefix("es2:") + ".c")).read_text(encoding="utf-8")
                # A backslash before a Chinese character (a Big5 artifact, d/temple/trainroom.c's
                # 练功\房) is an unknown escape: MudOS keeps the character alone.
                short = re.sub(r'\\(?=[^\x00-\x7f])', '', source)
                self.assertRegex(short, r'set\s*\(\s*"short"\s*,\s*"' + re.escape(room["short"]) + '"')
                # The long text is a @LONG ... LONG block: every line verbatim, in order.
                block = re.search(r"@(\w+)\n(.*?)\n\1\b", source, re.DOTALL)
                self.assertIsNotNone(block, "no @LONG block")
                self.assertEqual(room["long"], block.group(2) + "\n")
                for direction, target in room.get("exits", {}).items():
                    name = target.removeprefix("es2:").rsplit("/", 1)[-1]
                    self.assertRegex(source, rf'"{direction}"\s*:\s*(__DIR__\s*)?"[^"]*{name}"')


if __name__ == "__main__":
    unittest.main()
