"""东方漆木 UI atlas, 144x80 art px (exported at 2x for the game's 9-slice styleboxes).

    (0,0)   paper panel 48x48: a red-lacquer frame with gold corner fittings, paper inside
    (48,0)  lacquer panel 48x48: the same frame, dark lacquer inside (over the map)
    (96,0)  button normal 48x16   (96,16) hover   (96,32) pressed   (96,48) disabled   (96,64) selected tab
    (0,48)  inset 24x24: a sunken paper section     (24,48) dark inset 24x24
    (48,48) focus ring 24x24     (72,48) bubble 24x24 (lacquer, rounded)
"""
import random

from loomlib import rect, hline, vline, px, stamp, new_project, call, save_images
from palette import INK, LAC_D, LAC, LAC_L, LAC_HL, GOLD_D, GOLD, GOLD_L, PAPER, PLASTER_S, PLASTER_D, BEAM_D, BEAM

PAPER_BASE = '#efe3c6'
PAPER_HI = '#f8f0dc'
PAPER_SH = '#ddcca8'
PAPER_FIBER = '#e6d7b5'
LACQUER_IN = '#1f1512fa'
LACQUER_FIBER = '#2a1c18fa'

CORNER = ['ggggg..',
          'gGGGg..',
          'gG.....',
          'gG.....',
          'g......',
          '.......',
          '.......']


def frame(L, x0, y0, w, h):
    """The lacquer frame: ink outline, 3px red lacquer lit from the top, a gold inner line."""
    ops = [rect(L, x0, y0, w, h, INK),
           rect(L, x0 + 1, y0 + 1, w - 2, h - 2, LAC_D),
           rect(L, x0 + 1, y0 + 1, w - 2, 2, LAC),
           hline(L, x0 + 2, x0 + w - 3, y0 + 1, LAC_L),
           rect(L, x0 + 4, y0 + 4, w - 8, h - 8, GOLD_D),
           hline(L, x0 + 4, x0 + w - 5, y0 + 4, GOLD),
           rect(L, x0 + 5, y0 + 5, w - 10, h - 10, INK)]
    return ops


def corners(L, x0, y0, w, h):
    """Gold corner fittings, mirrored into the four corners."""
    ops = []
    for flip_x in (False, True):
        for flip_y in (False, True):
            rows = CORNER[::-1] if flip_y else CORNER
            rows = [r[::-1] for r in rows] if flip_x else rows
            x = x0 + w - 7 if flip_x else x0
            y = y0 + h - 7 if flip_y else y0
            ops.append(stamp(L, x, y, rows, {'g': GOLD_D, 'G': GOLD_L}))
    return ops


def paper_fill(L, x0, y0, w, h, seed):
    rnd = random.Random(seed)
    ops = [rect(L, x0, y0, w, h, PAPER_BASE)]
    for _ in range(w * h // 45):
        ops.append(px(L, x0 + rnd.randrange(w), y0 + rnd.randrange(h), PAPER_FIBER))
    return ops


def panel(L, x0, y0, paper=True):
    w = h = 48
    ops = frame(L, x0, y0, w, h)
    if paper:
        ops += paper_fill(L, x0 + 6, y0 + 6, w - 12, h - 12, 5)
        ops += [hline(L, x0 + 6, x0 + w - 7, y0 + 6, PAPER_SH)]          # the frame's shadow on the paper
    else:
        ops += [rect(L, x0 + 6, y0 + 6, w - 12, h - 12, LACQUER_IN)]
        rnd = random.Random(9)
        for _ in range(24):
            ops.append(px(L, x0 + 6 + rnd.randrange(w - 12), y0 + 6 + rnd.randrange(h - 12), LACQUER_FIBER))
    return ops + corners('fit', x0, y0, w, h)


def button(L, x0, y0, state):
    w, h = 48, 16
    edge = {'normal': INK, 'hover': GOLD_D, 'pressed': INK, 'disabled': PLASTER_D, 'tab': GOLD_D}[state]
    face = {'normal': PAPER_BASE, 'hover': PAPER_HI, 'pressed': LAC, 'disabled': '#d6ccb6', 'tab': LAC}[state]
    hi = {'normal': PAPER_HI, 'hover': '#fffaf0', 'pressed': LAC_L, 'disabled': '#e2d9c6', 'tab': LAC_HL}[state]
    sh = {'normal': PAPER_SH, 'hover': PAPER_SH, 'pressed': LAC_D, 'disabled': '#c4b89e', 'tab': LAC_D}[state]
    cap = {'normal': LAC, 'hover': LAC_L, 'pressed': LAC_D, 'disabled': '#a8988a', 'tab': GOLD}[state]
    ops = [rect(L, x0, y0 + 1, w, h - 1, '#00000040'),                # drop shadow under the plaque
           rect(L, x0, y0, w, h - 1, edge),
           rect(L, x0 + 1, y0 + 1, w - 2, h - 3, face),
           hline(L, x0 + 2, x0 + w - 3, y0 + 1, hi),
           rect(L, x0 + 1, y0 + h - 4, w - 2, 2, sh),
           rect(L, x0 + 1, y0 + 2, 2, h - 5, cap), rect(L, x0 + w - 3, y0 + 2, 2, h - 5, cap)]
    if state == 'pressed':
        ops = [rect(L, x0, y0, w, h, INK), rect(L, x0 + 1, y0 + 2, w - 2, h - 3, face),
               hline(L, x0 + 1, x0 + w - 2, y0 + 1, LAC_D), rect(L, x0 + 1, y0 + 2, 2, h - 3, cap),
               rect(L, x0 + w - 3, y0 + 2, 2, h - 3, cap)]
    if state == 'tab':
        ops += [hline(L, x0 + 3, x0 + w - 4, y0 + h - 2, GOLD)]
    return ops


def insets(L):
    ops = [rect(L, 0, 48, 24, 24, PAPER_SH), rect(L, 1, 49, 22, 22, '#e9dcbd'), hline(L, 1, 22, 49, PLASTER_D),
           vline(L, 1, 49, 70, PLASTER_D), hline(L, 1, 22, 70, PAPER_HI)]
    ops += [rect(L, 24, 48, 24, 24, INK), rect(L, 25, 49, 22, 22, '#2a1c18'), hline(L, 25, 46, 49, '#120c0a'),
            hline(L, 25, 46, 70, '#3a2a22')]
    ops += [rect(L, 48, 48, 24, 24, GOLD_D), rect(L, 49, 49, 22, 22, GOLD_L), rect(L, 51, 51, 18, 18, '#00000000')]
    for (x, y) in ((48, 48), (71, 48), (48, 71), (71, 71)):
        ops.append(px(L, x, y, '#00000000'))
    ops += [rect(L, 73, 49, 22, 22, INK), rect(L, 72, 50, 24, 20, INK), rect(L, 74, 50, 20, 20, '#1f1512f0'),
            rect(L, 73, 51, 22, 18, '#1f1512f0'), hline(L, 74, 93, 50, '#3a2a22f0')]
    for (x, y) in ((72, 49), (95, 49), (72, 70), (95, 70)):
        ops.append(px(L, x, y, '#00000000'))
    return ops


def main():
    doc = new_project('es-ui-atlas', 144, 80, ['panels', 'fit', 'buttons', 'insets'])
    doc.edit(panel('panels', 0, 0, True) + panel('panels', 48, 0, False), 'paper and lacquer panels')
    ops = []
    for i, state in enumerate(('normal', 'hover', 'pressed', 'disabled', 'tab')):
        ops += button('buttons', 96, i * 16, state)
    doc.edit(ops, 'buttons and tab')
    doc.edit(insets('insets'), 'insets, focus ring, bubble')
    print(doc.preview('ui_atlas', scale=6))


if __name__ == '__main__':
    main()
