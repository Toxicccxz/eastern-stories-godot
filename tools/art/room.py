"""饮风客栈 ground floor backdrop, 480x352 art px = the layout's 960x704 world px at 2x.

Every feature sits where tools/maps/layouts/snow.json puts it: art (ax, ay) = ((x + 480) / 2, (y + 352) / 2).
Furniture that blocks (tables, counter, jar shelf) is NOT drawn here: those are separate prop sprites
placed on the layout's blocked boxes.
"""
import random
import sys

from loomlib import Doc, call, rect, hline, vline, px, poly, line, stamp, layer_add, new_project
from palette import *

W, H = 480, 352
FLOOR_X0, FLOOR_X1, FLOOR_Y0, FLOOR_Y1 = 32, 448, 32, 320   # walkable floor (x1/y1 exclusive)


def a(x, y):
    return (x + 480) // 2, (y + 352) // 2


def floor_ops():
    ops = [rect('floor', FLOOR_X0, FLOOR_Y0, FLOOR_X1 - FLOOR_X0, FLOOR_Y1 - FLOOR_Y0, FLOOR)]
    ops.append(rect('floor', 448, 152, 16, 48, FLOOR))          # the doorway's floor
    rnd = random.Random(7)
    row_h = 8
    for i, y in enumerate(range(FLOOR_Y0, FLOOR_Y1, row_h)):
        x = FLOOR_X0 - (i * 29) % 56
        while x < FLOOR_X1 + 16:
            plank = 56 + rnd.choice((0, 8, 16))
            tone = rnd.choice((FLOOR, FLOOR, FLOOR_B, FLOOR_S))
            x0 = max(x, FLOOR_X0)
            x1 = min(x + plank, FLOOR_X1 + 16)
            if tone != FLOOR and x1 > x0:
                ops.append(rect('floor', x0, y, x1 - x0, row_h - 1, tone))
            if x > FLOOR_X0:
                ops.append(vline('floor', x, y, y + row_h - 2, FLOOR_D))
            if rnd.random() < 0.35 and x1 - x0 > 20:      # a knot or a grain line
                gx = rnd.randint(x0 + 4, x1 - 10)
                ops.append(hline('floor', gx, gx + rnd.randint(3, 7), y + rnd.randint(2, 4), FLOOR_S))
            x += plank
        ops.append(hline('floor', FLOOR_X0, FLOOR_X1 + 15, y + row_h - 1, FLOOR_D))   # seam
    return ops


def shade_ops():
    """Light and shadow over the floor, rug and doorway (a layer of its own: Pixel Loom layers blend)."""
    L = 'shade'
    ops = [rect(L, FLOOR_X0, FLOOR_Y0, FLOOR_X1 - FLOOR_X0, 3, '#00000066'),
           rect(L, FLOOR_X0, FLOOR_Y0 + 3, FLOOR_X1 - FLOOR_X0, 3, '#00000033'),
           rect(L, FLOOR_X0, FLOOR_Y0 + 6, 4, FLOOR_Y1 - FLOOR_Y0 - 6, '#00000033'),
           rect(L, FLOOR_X1 - 4, FLOOR_Y0 + 6, 4, 146, '#00000033'),
           rect(L, FLOOR_X1 - 4, 200, 4, FLOOR_Y1 - 200, '#00000033'),
           rect(L, FLOOR_X0 + 4, FLOOR_Y1 - 4, FLOOR_X1 - FLOOR_X0 - 8, 4, '#00000033')]
    # daylight from the east door, in bands that do not overlap
    for x0, x1, col in ((388, 408, '#fff2d40e'), (408, 428, '#fff2d418'), (428, 448, '#fff2d424'), (448, 464, '#fff2d430')):
        ops.append(rect(L, x0, 156, x1 - x0, 40, col))
    return ops


def rug_ops():
    """A vermilion runner from the middle of the room to the east door, a gold border."""
    x0, x1, y0, y1 = 228, 448, 165, 187
    ops = [rect('rug', x0, y0, x1 - x0, y1 - y0, LAC_D),
           rect('rug', x0 + 1, y0 + 1, x1 - x0 - 1, y1 - y0 - 2, LAC),
           hline('rug', x0 + 2, x1, y0 + 3, GOLD_D), hline('rug', x0 + 2, x1, y1 - 4, GOLD_D),
           vline('rug', x0 + 3, y0 + 3, y1 - 4, GOLD_D)]
    for x in range(x0 + 10, x1 - 4, 14):     # a running 回 pattern
        ops += [rect('rug', x, y0 + 7, 7, 8, LAC_L), rect('rug', x + 2, y0 + 9, 3, 4, LAC),
                px('rug', x + 3, y0 + 11, GOLD)]
    for x in range(x0 + 1, x1, 2):            # fringe at the inner end
        pass
    ops.append(vline('rug', x0, y0 + 1, y1 - 2, GOLD))
    for y in range(y0 + 1, y1 - 1, 2):
        ops.append(px('rug', x0 - 1, y, GOLD_D))
    return ops


def back_wall_ops():
    ops = []
    # boundary above and the wall face (ay 0..32), corners included
    ops.append(rect('walls', 0, 0, W, H, VOID))
    ops.append(rect('walls', 16, 0, 448, 32, PLASTER))
    ops.append(rect('walls', 16, 0, 448, 4, BEAM_D))                 # roof beam
    ops.append(hline('walls', 16, 463, 4, BEAM))
    ops.append(hline('walls', 16, 463, 5, BEAM_L))
    ops.append(rect('walls', 16, 6, 448, 2, PLASTER_D))              # beam shadow on plaster
    ops.append(rect('walls', 16, 20, 448, 2, BEAM))                  # rail
    ops.append(hline('walls', 16, 463, 20, BEAM_L))
    ops.append(rect('walls', 16, 22, 448, 10, BEAM_D))               # wainscot
    for x in range(16, 464, 6):
        ops.append(vline('walls', x, 23, 30, BEAM))
    ops.append(hline('walls', 16, 463, 31, INK))
    # posts every 64 px
    for x in [16, 80, 144, 208, 272, 336, 400, 456]:
        ops.append(rect('walls', x, 0, 8, 32, BEAM))
        ops.append(vline('walls', x, 0, 31, BEAM_D))
        ops.append(vline('walls', x + 1, 6, 30, BEAM_L))
        ops.append(vline('walls', x + 7, 0, 31, INK))
    return ops


def side_wall_ops():
    ops = []
    for x0 in (16, 448):
        ops.append(rect('walls', x0, 32, 16, 288, BEAM_D))
        ops.append(rect('walls', x0 + 2, 32, 12, 288, BEAM))
        inner = x0 + 15 if x0 == 16 else x0
        ops.append(vline('walls', inner, 32, 319, BEAM_L))
        for y in range(48, 320, 48):                                  # post caps
            ops += [rect('walls', x0 + 1, y, 14, 6, BEAM_L), hline('walls', x0 + 1, x0 + 14, y, BEAM_HL),
                    hline('walls', x0 + 1, x0 + 14, y + 5, BEAM_D)]
    # bottom wall: the top of a low wall seen from above
    ops.append(rect('walls', 16, 320, 448, 16, BEAM_D))
    ops.append(rect('walls', 16, 322, 448, 10, BEAM))
    ops.append(hline('walls', 16, 463, 320, BEAM_L))
    for x in range(64, 448, 64):
        ops += [rect('walls', x, 321, 6, 14, BEAM_L), vline('walls', x, 321, 334, BEAM_HL)]
    return ops


def window(x, y):
    """A paper lattice window 18x12 on the plaster."""
    ops = [rect('decor', x - 1, y - 1, 20, 14, BEAM_D), rect('decor', x, y, 18, 12, PAPER)]
    for gx in range(x + 3, x + 18, 4):
        ops.append(vline('decor', gx, y, y + 11, BEAM_L))
    for gy in range(y + 3, y + 12, 4):
        ops.append(hline('decor', x, x + 17, gy, BEAM_L))
    ops.append(rect('decor', x - 2, y + 12, 22, 2, BEAM))
    return ops


def lantern(x, y):
    """A red paper lantern hanging from the roof beam, centre x; a warm glow on the plaster."""
    rows = [
        '...d...',
        '..ggg..',
        '.rRRRr.',
        'rRRLRRr',
        'RRRLRRR',
        'RRRLRRR',
        'RRRLRRR',
        'rRRLRRr',
        '.rRRRr.',
        '..ggg..',
        '...y...',
        '..yyy..',
    ]
    glow = ['..ggggg..', '.ggggggg.', 'ggggggggg', 'ggggggggg', 'ggggggggg', '.ggggggg.', '..ggggg..']
    return [stamp('glow', x - 4, y + 2, glow, {'g': '#ffcf7a2e'}),
            vline('decor', x, 0, y - 1, INK),
            stamp('decor', x - 3, y, rows, {'d': INK, 'g': GOLD, 'r': LAC_D, 'R': LAC, 'L': LAC_HL, 'y': GOLD_L})]


def scroll(x, y, h=14):
    """A hanging calligraphy scroll."""
    ops = [rect('decor', x - 1, y, 10, 2, BEAM_D), rect('decor', x, y + 2, 8, h, PAPER),
           rect('decor', x - 1, y + 2 + h, 10, 2, BEAM_D)]
    for i, yy in enumerate(range(y + 4, y + h, 3)):
        ops.append(hline('decor', x + 2 + (i % 2), x + 5, yy, INK))
    return ops


def red_door_ops():
    """d/snow/inn.c's red-wood door in the north-west, glowing white (layout -400..-336, -320..-288)."""
    x0, y0 = a(-400, -320)[0], 4
    w, h = 32, 28
    ops = []
    for r, col in ((5, '#ffffff22'), (3, '#ffffff33'), (1, '#ffffff55')):
        ops.append(rect('reddoor', x0 - r, y0 - min(r, 3), w + 2 * r, h + min(r, 3), col))
    ops += [rect('reddoor', x0, y0, w, h, BEAM_D),
            rect('reddoor', x0 + 2, y0 + 2, w - 4, h - 2, LAC_D),
            rect('reddoor', x0 + 3, y0 + 3, 12, h - 3, LAC), rect('reddoor', x0 + 17, y0 + 3, 12, h - 3, LAC),
            vline('reddoor', x0 + 4, y0 + 3, y0 + h - 1, LAC_L), vline('reddoor', x0 + 18, y0 + 3, y0 + h - 1, LAC_L),
            vline('reddoor', x0 + 15, y0 + 2, y0 + h - 1, INK), vline('reddoor', x0 + 16, y0 + 2, y0 + h - 1, LAC_D),
            rect('reddoor', x0 - 1, y0 - 2, w + 2, 3, BEAM_L), hline('reddoor', x0 - 1, x0 + w, y0 - 2, BEAM_HL)]
    for sx in (x0 + 6, x0 + 10, x0 + 21, x0 + 25):
        for sy in (y0 + 7, y0 + 13, y0 + 19):
            ops.append(px('reddoor', sx, sy, GOLD))
    ops += [rect('reddoor', x0 + 13, y0 + 13, 2, 3, GOLD_L), rect('reddoor', x0 + 17, y0 + 13, 2, 3, GOLD_L)]
    return ops


def stairs_ops():
    """The stairs up in the north-east corner (layout passage at 352,-248, 96x48)."""
    x0, x1 = 392, 440
    ops = [rect('stairs', x0 + 2, 6, x1 - x0 - 4, 26, INK),            # the opening in the wall
           rect('stairs', x0 + 4, 8, x1 - x0 - 8, 24, '#2a1c18')]
    steps = 8
    top, bottom = 8, 64
    step_h = (bottom - top) // steps
    for i in range(steps):
        y = bottom - (i + 1) * step_h
        shade = [FLOOR_HL, FLOOR_L, FLOOR_B, FLOOR, FLOOR_S, FLOOR_S, FLOOR_D, FLOOR_D][i]
        ops += [rect('stairs', x0 + 3, y, x1 - x0 - 6, step_h, shade),
                hline('stairs', x0 + 3, x1 - 4, y + step_h - 2, FLOOR_D),
                hline('stairs', x0 + 3, x1 - 4, y + step_h - 1, BEAM_D)]
    for rx in (x0, x1 - 3):                                              # railings
        ops += [rect('stairs', rx, 0, 3, 66, BEAM_D), vline('stairs', rx + 1, 2, 64, BEAM_L)]
        for py in range(10, 64, 9):
            ops.append(rect('stairs', rx - 1, py, 5, 2, BEAM_HL))
    ops.append(rect('stairs', x0 - 1, 64, x1 - x0 + 2, 2, '#00000044'))
    return ops


def east_door_ops():
    """The door east onto the square (layout floor 416..448 x -48..48): open, the snow outside."""
    x0, y0, y1 = 448, 152, 200
    ops = [rect('door', 464, y0 - 4, 16, y1 - y0 + 8, SNOW_S), rect('door', 466, y0, 14, y1 - y0, SNOW),
           rect('door', x0, y0, 16, y1 - y0, STONE), hline('door', x0, x0 + 15, y0, STONE_L),
           hline('door', x0, x0 + 15, y1 - 1, STONE_D)]
    for y in range(y0 + 6, y1, 8):
        ops.append(hline('door', x0 + 1, x0 + 14, y, STONE_D))
    for py in (y0 - 6, y1):                                              # the frame posts
        ops += [rect('door', x0 - 1, py, 18, 6, BEAM_D), rect('door', x0, py + 1, 16, 4, LAC),
                hline('door', x0, x0 + 15, py + 1, LAC_L)]
    return ops


def sign_ops():
    """The ebony sign beside the door (layout 424..440 x -112..-64): a vertical black board, gold strokes."""
    x0, y0 = 450, 116
    ops = [rect('decor', x0, y0, 10, 30, INK), rect('decor', x0 + 1, y0 + 1, 8, 28, '#2a2026'),
           rect('decor', x0 - 1, y0 - 1, 12, 2, GOLD_D), rect('decor', x0 - 1, y0 + 29, 12, 2, GOLD_D)]
    for i, yy in enumerate(range(y0 + 4, y0 + 27, 6)):
        ops += [hline('decor', x0 + 3, x0 + 6, yy, GOLD), vline('decor', x0 + 4 + (i % 2), yy, yy + 3, GOLD),
                px('decor', x0 + 6, yy + 3, GOLD_L)]
    return ops


def wall_decor_ops():
    ops = []
    for x in (92, 120):
        ops += window(x, 7)
    for x in (344, 370):
        ops += window(x, 7)
    ops += scroll(152, 6) + scroll(320, 6)
    for x in (116, 196, 284, 366):
        ops += lantern(x, 5)
    return ops


def main():
    doc = new_project('inn-room', W, H, ['walls', 'floor', 'rug', 'shade', 'door', 'stairs', 'reddoor', 'glow', 'decor'])
    print('doc', doc.doc_id, doc.rev)
    doc.edit(back_wall_ops() + side_wall_ops(), 'walls')
    doc.edit(floor_ops(), 'floor planks')
    doc.edit(rug_ops(), 'runner to the door')
    doc.edit(shade_ops(), 'light and shadow')
    doc.edit(east_door_ops(), 'east door')
    doc.edit(stairs_ops(), 'stairs up')
    doc.edit(red_door_ops(), 'red-wood door')
    doc.edit(wall_decor_ops() + sign_ops(), 'windows, lanterns, scrolls, sign', preview_stem='room_v1')
    print(doc.preview('room_full', scale=2, checker=False))
    print('rev', doc.rev)


if __name__ == '__main__':
    main()
