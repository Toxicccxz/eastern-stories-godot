"""Technique `fills`: boxes of terrain painted in order, and fixed mazes.

    "draw": {"technique": "fills", "fills": [
        ["cliff", -192, -160, 192, 160],                    kind and box; `void` clears
        {"maze": {"grid": [...], "cell": 48, "kind": "cave_floor", "note": "..."}}
    ]}

A maze grid is rows of `#` (left as painted), `.` open, `S` the way in and `E` the way out;
each open character is painted as one cell from the origin.
"""

from __future__ import annotations

from collections import deque

from .region import Drawn, fill_row
from .tiles import Tiles


def draw(region, entry: dict) -> Drawn:
    tiles = Tiles()
    notes = []
    for row in entry['draw']['fills']:
        if isinstance(row, dict):
            spec = row['maze']
            notes.append(maze(tiles, spec['grid'], spec['cell'], spec['kind']))
        else:
            tiles.fill(*fill_row(row))
    return Drawn(tiles, notes=notes)


def maze(tiles: Tiles, grid: list, cell: int, kind: str) -> str:
    report = check_maze(grid)
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c != '#':
                tiles.fill(kind, x * cell, y * cell, x * cell + cell, y * cell + cell)
    return report


def check_maze(grid: list) -> str:
    """One way through from S to E and no cell cut off; reports loops and dead ends."""
    cells = {(x, y) for y, row in enumerate(grid) for x, c in enumerate(row) if c != '#'}
    start = next((x, y) for y, row in enumerate(grid) for x, c in enumerate(row) if c == 'S')
    end = next((x, y) for y, row in enumerate(grid) for x, c in enumerate(row) if c == 'E')
    seen, todo = {start}, deque([start])
    while todo:
        x, y = todo.popleft()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n in cells and n not in seen:
                seen.add(n)
                todo.append(n)
    assert end in seen, 'maze has no way through'
    assert seen == cells, f'unreachable cells: {sorted(cells - seen)}'
    edges = sum(1 for (x, y) in cells for n in ((x + 1, y), (x, y + 1)) if n in cells)
    loops = edges - len(cells) + 1
    ends = sum(1 for (x, y) in cells if sum(n in cells for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))) == 1)
    return f'maze: {len(cells)} cells, {loops} loop(s), {ends} dead end(s)'
