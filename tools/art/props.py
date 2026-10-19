"""Furniture that blocks, one Pixel Loom project each. A prop's sprite bottom sits on the bottom edge
of its layout box ("blocked" prop in tools/maps/layouts/*.json), centred on the box: the layout's
box is the collision, the sprite rises above it (a table top seen from the front and above).

Sizes are art px (1 art px = 2 world px).
"""
import random
import sys

from loomlib import Doc, call, rect, hline, vline, px, poly, line, stamp, new_project
from palette import *

SH = '#0000004d'


def table_base(L, w=32, h=24):
    """A square lacquered tea table: top surface, apron, four legs with a low stretcher, a floor shadow."""
    ops = [rect(L, 2, h - 3, w - 4, 3, SH)]                        # floor shadow
    ops.append(rect(L, 3, 14, w - 6, h - 19, '#00000040'))        # the dark under the top
    for lx in (5, w - 8):                                         # back legs, farther: shorter, darker
        ops += [rect(L, lx, 13, 3, h - 18, BEAM_D), hline(L, lx, lx + 2, h - 6, INK)]
    ops += [rect(L, 3, h - 7, w - 6, 2, BEAM_D), hline(L, 3, w - 4, h - 7, BEAM)]   # stretcher
    for lx in (1, w - 5):                                         # front legs
        ops += [rect(L, lx, 13, 4, h - 14, INK), rect(L, lx + 1, 13, 2, h - 15, BEAM_L),
                vline(L, lx + 1, 13, h - 3, BEAM_HL)]
    ops += [rect(L, 0, 1, w, 10, INK),                            # top: outline
            rect(L, 1, 2, w - 2, 8, BEAM_L),                      # surface
            hline(L, 1, w - 2, 2, BEAM_HL),
            rect(L, 0, 10, w, 4, INK), rect(L, 1, 10, w - 2, 3, BEAM), hline(L, 1, w - 2, 10, BEAM_HL)]
    for gx, gy, gl in ((5, 5, 6), (14, 7, 8), (22, 4, 5)):          # grain
        ops.append(hline(L, gx, gx + gl, gy, BEAM))
    return ops


def tea_items(L):
    teapot = ['.gg..', 'gGGgy', 'gGWGg', '.ggg.']
    cup = ['ww', 'WW']
    return [stamp(L, 13, 3, teapot, {'g': JADE_D, 'G': JADE, 'W': JADE_L, 'y': JADE_D}),
            stamp(L, 7, 6, cup, {'w': WHITE, 'W': PLASTER_S}),
            stamp(L, 22, 5, cup, {'w': WHITE, 'W': PLASTER_S}),
            stamp(L, 20, 7, cup, {'w': WHITE, 'W': PLASTER_S})]


def meal_items(L):
    bowl = ['.www.', 'wRRRw', '.www.']
    return [stamp(L, 5, 4, bowl, {'w': WHITE, 'R': '#e8c890'}),
            stamp(L, 18, 5, ['.wwwwww.', 'wGgGgGgw', '.wwwwww.'], {'w': WHITE, 'G': JADE_L, 'g': '#c46a3e'}),
            line(L, 11, 7, 15, 4, INK), line(L, 12, 8, 16, 5, BEAM_D),
            stamp(L, 26, 4, ['ww', 'WW'], {'w': WHITE, 'W': PLASTER_S})]


def wine_items(L):
    jug = ['.oo.', 'oRRo', 'RRLR', 'RRRR', '.RR.']
    return [stamp(L, 14, 2, jug, {'o': INK, 'R': '#7a4a2a', 'L': '#b07a48'}),
            stamp(L, 6, 6, ['ww', 'WW'], {'w': WHITE, 'W': PLASTER_S}),
            stamp(L, 22, 6, ['ww', 'WW'], {'w': WHITE, 'W': PLASTER_S}),
            stamp(L, 9, 4, ['gg'], {'g': '#e8c890'})]


def counter(L):
    """The counter: 160 x 24, its top 8 rows, a lacquered front panel with brass studs."""
    w, h = 160, 26
    ops = [rect(L, 1, h - 3, w - 2, 3, SH),
           rect(L, 0, 2, w, 9, INK), rect(L, 1, 3, w - 2, 7, BEAM_L), hline(L, 1, w - 2, 3, BEAM_HL),
           rect(L, 0, 10, w, h - 12, INK), rect(L, 1, 10, w - 2, h - 13, LAC_D),
           hline(L, 1, w - 2, 10, BEAM), hline(L, 1, w - 2, 11, LAC)]
    for x in range(4, w - 4, 26):                                  # front panels
        ops += [rect(L, x, 13, 22, h - 18, LAC), hline(L, x, x + 21, 13, LAC_L), vline(L, x, 13, h - 6, LAC_L),
                rect(L, x + 9, 16, 4, 4, GOLD_D), rect(L, x + 10, 17, 2, 2, GOLD_L)]
    ops.append(rect(L, 1, h - 5, w - 2, 2, BEAM_D))
    for gx in range(8, w - 8, 19):
        ops.append(hline(L, gx, gx + 7, 6, BEAM))
    # on the top: an abacus, the ledger, a bell, a tray of cups, a little wine jar
    ops += [rect(L, 18, 3, 22, 7, BEAM_D), rect(L, 19, 4, 20, 5, '#3a2a20')]
    for bx in range(20, 38, 3):
        ops += [px(L, bx, 5, LAC_L), px(L, bx, 7, LAC_L), px(L, bx + 1, 7, LAC_L)]
    ops += [hline(L, 19, 38, 6, BEAM_HL),
            rect(L, 60, 3, 16, 7, INK), rect(L, 61, 4, 6, 5, PAPER), rect(L, 69, 4, 6, 5, PAPER),
            vline(L, 68, 4, 8, LAC)]
    for ly in (5, 7):
        ops += [hline(L, 62, 65, ly, BEAM_L), hline(L, 70, 73, ly, BEAM_L)]
    ops += [stamp(L, 96, 2, ['.oo.', 'oGGo', 'GGLG', 'gggg'], {'o': INK, 'G': GOLD, 'L': GOLD_L, 'g': GOLD_D}),
            rect(L, 116, 5, 18, 5, BEAM_D), rect(L, 117, 6, 16, 3, BEAM)]
    for cx in (118, 123, 128):
        ops.append(stamp(L, cx, 4, ['ww', 'WW'], {'w': WHITE, 'W': PLASTER_S}))
    ops.append(stamp(L, 144, 0, ['.oo.', 'oRRo', 'RpRR', 'RRRR', '.RR.'], {'o': INK, 'R': '#7a4a2a', 'p': LAC_L}))
    return ops


JAR_GLAZES = [('#6a4026', '#a8714a'), ('#4a2c22', '#7e5038'), ('#7a5a30', '#b8904e'), ('#3e3430', '#6e605a')]


def jar(L, x, y, big=True, glaze=0, cloth=False):
    """A glazed wine jar with a red paper diamond (酒) and a dark mark, bottom at y."""
    if big:
        rows = ['...oooo...', '..oKKKKo..', '.oooooooo.', 'oJJJJJJJJo', 'oJLJJRJJJo', 'oJLJRkRJJo',
                'oJLJJRJJJo', 'oJJJJJJJJo', 'oJJJJJJJJo', '.oJJJJJJo.', '..oooooo..']
    else:
        rows = ['..ooo..', '.oKKKo.', 'ooooooo', 'oJLJRJo', 'oJLRkRo', 'oJJJRJo', '.oJJJo.', '..ooo..']
    body, light = JAR_GLAZES[glaze % len(JAR_GLAZES)]
    top = PLASTER_S if cloth else LAC
    return [stamp(L, x, y - len(rows), rows, {'o': INK, 'K': top, 'J': body, 'L': light, 'R': LAC_L, 'k': INK})]


def jar_shelf(L):
    """192 x 32: a two-tier rack against the back wall, wine jars on both tiers."""
    w, h = 192, 32
    ops = [rect(L, 0, h - 3, w, 3, SH)]
    for sx in (0, w // 2 - 2, w - 4):                              # uprights
        ops += [rect(L, sx, 2, 4, h - 3, BEAM_D), vline(L, sx + 1, 3, h - 3, BEAM_L)]
    for sy in (14, h - 5):                                         # shelves
        ops += [rect(L, 0, sy, w, 3, INK), rect(L, 1, sy, w - 2, 2, BEAM_L), hline(L, 1, w - 2, sy, BEAM_HL)]
    rnd = random.Random(3)
    x = 6
    while x < w - 12:
        if w // 2 - 11 < x < w // 2 + 4:
            x = w // 2 + 4
            continue
        ops += jar(L, x, 14, big=False, glaze=rnd.randint(0, 3), cloth=rnd.random() < 0.4)
        x += 9 + rnd.randint(0, 2)
    x = 5
    while x < w - 14:
        if w // 2 - 13 < x < w // 2 + 4:
            x = w // 2 + 4
            continue
        ops += jar(L, x, h - 5, big=True, glaze=rnd.randint(0, 3), cloth=rnd.random() < 0.3)
        x += 12 + rnd.randint(0, 3)
    return ops


def build(name, w, h, layers, drawers, stem):
    doc = new_project(name, w, h, layers)
    for label, ops in drawers:
        doc.edit(ops, label)
    print(name, doc.preview(stem, scale=6), doc.rev)
    return doc


TABLES = {'tea': tea_items, 'meal': meal_items, 'wine': wine_items}


def main(which):
    for kind, items in TABLES.items():
        if which in ('tables', 'all', 'table_' + kind):
            build('inn-table-' + kind, 32, 24, ['table', 'items'],
                  [('table', table_base('table')), (kind + ' things', items('items'))], 'table_' + kind)
    if which in ('counter', 'all'):
        build('inn-counter', 160, 26, ['counter'], [('counter', counter('counter'))], 'counter')
    if which in ('shelf', 'all'):
        build('inn-jar-shelf', 192, 32, ['shelf'], [('jar shelf', jar_shelf('shelf'))], 'shelf')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'all')
