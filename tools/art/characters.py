"""Walking characters, 32x32 art px, drawn part by part with Pixel Loom stamps.

Frames: idle_down 0, walk_down 1-4, idle_up 5, walk_up 6-9, idle_right 10, walk_right 11-14.
Left is the right frames mirrored in the game. Feet stand on y = 30; the game anchors there.

Part patterns are authored here as ASCII (keys below); the host only computes where each part
goes on each frame (the walk cycle) and sends native stamp operations.

Keys: o outline, s skin, S skin shade, e eye, h hair, H hair light, k hair tie / hat band,
r robe, R robe shade, l robe light, c collar/trim, b belt, t trousers, T trousers shade, f shoe,
w towel/cloth, W cloth shade, a hat, A hat shade, p pack, P pack shade.
"""
import sys

from loomlib import Doc, call, rect, stamp, new_project
from palette import INK, SKIN, SKIN_S, SKIN_D, HAIR, HAIR_L, WHITE, PLASTER_S

OUT = '#2a1d1e'


def check(name, rows, width=None):
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (name, rows)
    if width:
        assert w == width, (name, w)
    return rows


# --- down (facing the viewer) ----------------------------------------------------------------
HEAD_DOWN = check('head_down', [
    '...oooooo...',
    '..ohhhhhho..',
    '.ohhhhHhhhho',
    'ohhhhhhHhhho',
    'ohhhhhhhhhho',
    'ohhssssssho.',
    'ohssssssssho',
    'osseSsseSsso',
    'oSssssssssSo',
    '.oSssssssSo.',
    '..oooooooo..',
][:5] + [
    'ohhsssssshho',
    'ohssssssssho',
    'ossessssesso',
    'oSssssssssSo',
    '.oSssssssSo.',
    '..oooooooo..',
], 12)
HEAD_UP = check('head_up', [
    '...oooooo...',
    '..ohhhhhho..',
    '.ohhhhHhhhho',
    'ohhhhhhHhhho',
    'ohhhhhhhhhho',
    'ohhhhhhhhhho',
    'ohhHhhhhhhho',
    'ohhhhhhhhhho',
    'oShhhhhhhhSo',
    '.oShhhhhhSo.',
    '..oooooooo..',
], 12)
HEAD_RIGHT = check('head_right', [
    '...ooooo....',
    '..ohhhhhoo..',
    '.ohhhhHhhho.',
    'ohhhhhhhhhho',
    'ohhhhhhhhhho',
    'ohhhhhhsssho',
    'ohhhhsssssso',
    'ohhhhsssesso',
    'oShhhssssssS',
    '.oShhSssssSo',
    '..ooooooooo.',
], 12)
BUN = {'down': check('bun', ['.oo.', 'okko', 'ohho', '.oo.']),
       'up': check('bun', ['.oo.', 'ohho', 'okko', '.oo.']),
       'right': check('bun', ['.oo.', 'ohho', 'okko', '.oo.'])}
TWIN_BUNS = check('twin', ['.oo.', 'ohho', 'ohHo', 'okko', '.oo.'])
BODY_DOWN = check('body_down', [
    '..orccccro..',
    '.orrrccrrro.',
    'orrrrcrrrrRo',
    'orrrrrcrrrRo',
    'obbbbbbbbbbo',
    'orrrrrrrrrRo',
    'orrrrrrrrrRo',
    'orRrrrrrrRRo',
    '.oooooooooo.',
], 12)
BODY_UP = check('body_up', [
    '..orrrrrro..',
    '.orrrrrrrro.',
    'orrrrrrrrrRo',
    'orrrrrrrrrRo',
    'obbbbbbbbbbo',
    'orrrrrrrrrRo',
    'orrrrrrrrrRo',
    'orRrrrrrrRRo',
    '.oooooooooo.',
], 12)
BODY_RIGHT = check('body_right', [
    '..orrcco.',
    '.orrrrcco',
    'oRrrrrrco',
    'oRrrrrrro',
    'obbbbbbbo',
    'oRrrrrrro',
    'oRrrrrrro',
    'oRRrrrrRo',
    '.ooooooo.',
], 9)
SKIRT_DOWN = check('skirt_down', [
    'orrrrrrrrrRo',
    'orRrrrrrrRRo',
    'orRrrrrrrRRo',
    '.oooooooooo.',
], 12)
SKIRT_RIGHT = check('skirt_right', [
    'oRrrrrrro',
    'oRRrrrrRo',
    'oRRrrrrRRo'[:9],
    '.ooooooo.',
], 9)
ARM_DOWN = check('arm', ['orro', 'orRo', 'orRo', 'oRRo', 'osso', '.oo.'], 4)
ARM_RIGHT_FRONT = check('arm_rf', ['oro', 'orR', 'orR', 'oRo', 'oso', '.o.'], 3)
LEG_DOWN = check('leg', ['otTo', 'otTo', 'offo', '.oo.'], 4)
LEG_RIGHT = check('leg_r', ['otTo.', 'otTo.', 'offfo', '.ooo.'], 5)
TOWEL_DOWN = check('towel', ['.wwwwwwww.', 'wWw....wWw', 'ww......ww'], 10)
TOWEL_RIGHT = check('towel_r', ['wwwww', 'wW..w'], 5)
HAT_DOWN = check('hat', [
    '.....oooooo.....',
    '...ooaaaaaaoo...',
    '.ooaaaaAaaaaaoo.',
    'oaaaaaaaaaaaaaao',
    'oAAAAkkkkkkAAAAo',
    '.oooooooooooooo.',
], 16)
HAT_RIGHT = HAT_DOWN
PACK_UP = check('pack', ['.oooooo.', 'oppppppo', 'opPppPpo', 'oppppppo', 'oPPPPPPo', '.oooooo.'], 8)
PACK_RIGHT = check('pack_r', ['.ooo', 'oppo', 'oPpo', 'oppo', 'oPPo', '.ooo'], 4)
SHADOW = check('shadow', ['..ssssssss..', 'ssssssssssss', '..ssssssss..'], 12)


CHARACTERS = {
    'player_male': {
        'colors': {'r': '#4a6a8a', 'R': '#34506c', 'l': '#6f8fae', 'c': '#e8e0cc', 'b': '#3a2a22',
                   't': '#2e2c36', 'T': '#22202a', 'f': '#1a1418', 'k': '#4a6a8a'},
        'bun': 'top',
    },
    'player_female': {
        'colors': {'r': '#a0505e', 'R': '#7a3a48', 'l': '#c47482', 'c': '#f0e2c8', 'b': '#d4a446',
                   't': '#3a2a30', 'T': '#2a1e24', 'f': '#3a1e22', 'k': '#d4a446'},
        'bun': 'twin', 'skirt': True,
    },
    'waiter': {
        'colors': {'r': '#d6cab0', 'R': '#ab9c7c', 'l': '#ece2cc', 'c': '#8a7a5a', 'b': '#5a3b27',
                   't': '#3a3440', 'T': '#2a2430', 'f': '#1a1418', 'k': '#5a4a3a',
                   'w': '#f8f2e4', 'W': '#c8c0b0'},
        'bun': 'top', 'towel': True,
    },
    'traveller_a': {
        'colors': {'r': '#7a5a3a', 'R': '#5a4028', 'l': '#9a7a52', 'c': '#d8ccb0', 'b': '#2e1f1b',
                   't': '#4a3a30', 'T': '#382a22', 'f': '#2a1e18', 'k': '#8e2a22',
                   'a': '#c8a868', 'A': '#9c7c44'},
        'bun': 'top', 'hat': True,
    },
    'traveller_b': {
        'colors': {'r': '#3f6e5f', 'R': '#2c5046', 'l': '#5f8e7c', 'c': '#d8ccb0', 'b': '#2e1f1b',
                   't': '#36323a', 'T': '#28242c', 'f': '#1a1418', 'k': '#d8ccb0',
                   'p': '#a8885a', 'P': '#7a5e3a'},
        'bun': 'top', 'pack': True,
    },
}

BASE = {'o': OUT, 's': SKIN, 'S': SKIN_S, 'e': INK, 'h': HAIR, 'H': HAIR_L}

IDLE_MS, WALK_MS = 400, 130
DIRS = ['down', 'up', 'right']


def frame_index(direction, k):
    """k = -1 for idle, 0..3 for walk."""
    return DIRS.index(direction) * 5 + (0 if k < 0 else 1 + k)


def ops_for(char: dict, direction: str, k: int) -> list:
    f = frame_index(direction, k)
    colors = dict(BASE)
    colors.update(char['colors'])

    def st(layer, x, y, rows):
        used = {ch for r in rows for ch in r if ch != '.'}
        return stamp(layer, x, y, rows, {c: colors[c] for c in used}, frame=f)

    walking = k >= 0
    bob = 1 if walking and k % 2 == 0 else 0          # contact frames sit a pixel lower
    ops = [stamp('shadow', 10, 28, [r.replace('s', 'x') for r in SHADOW], {'x': '#00000040'}, frame=f)]
    head_y, body_y, legs_y = 6 + bob, 17 + bob, 25
    skirt = char.get('skirt')
    if direction in ('down', 'up'):
        lift_l = 1 if walking and k == 2 else 0          # the raised foot
        lift_r = 1 if walking and k == 0 else 0
        if not skirt:
            ops += [st('legs', 11, legs_y - lift_l, LEG_DOWN), st('legs', 17, legs_y - lift_r, LEG_DOWN)]
        else:
            ops += [st('legs', 11, legs_y + 1 - lift_l, LEG_DOWN[2:]), st('legs', 17, legs_y + 1 - lift_r, LEG_DOWN[2:])]
        body = BODY_DOWN if direction == 'down' else BODY_UP
        ops.append(st('body', 10, body_y, body))
        if skirt:
            ops.append(st('body', 10, body_y + 5, SKIRT_DOWN))
        swing = 0 if not walking else (1 if k == 0 else (-1 if k == 2 else 0))
        ops += [st('arms', 7, body_y + 1 + swing, ARM_DOWN), st('arms', 21, body_y + 1 - swing, ARM_DOWN)]
        if char.get('pack') and direction == 'up':
            ops.append(st('acc', 12, body_y, PACK_UP))
        if char.get('towel') and direction == 'down':
            ops.append(st('acc', 11, body_y, TOWEL_DOWN))
        head = HEAD_DOWN if direction == 'down' else HEAD_UP
        ops.append(st('head', 10, head_y, head))
        if char.get('bun') == 'top':
            ops.append(st('head', 14, head_y - 3, BUN[direction]))
        elif char.get('bun') == 'twin':
            ops += [st('head', 8, head_y - 1, TWIN_BUNS), st('head', 20, head_y - 1, TWIN_BUNS)]
        if char.get('hat'):
            ops.append(st('acc', 8, head_y - 3, HAT_DOWN))
    else:
        # right: legs spread on contact frames, together (one lifted) passing
        spread = {0: 3, 1: 0, 2: -3, 3: 0}.get(k, 0)
        lift = 1 if walking and k in (1, 3) else 0
        back_x, front_x = 13 - spread, 14 + spread
        if skirt:
            ops += [st('legs', back_x, legs_y + 2, LEG_RIGHT[2:]), st('legs', front_x, legs_y + 2 - lift, LEG_RIGHT[2:])]
        else:
            ops += [st('legs', back_x, legs_y, LEG_RIGHT), st('legs', front_x, legs_y - lift, LEG_RIGHT)]
        arm_swing = {0: -2, 1: 0, 2: 2, 3: 0}.get(k, 0)
        ops.append(st('arms_back', 13 - arm_swing, body_y + 1, ARM_RIGHT_FRONT))
        if char.get('pack'):
            ops.append(st('arms_back', 9, body_y, PACK_RIGHT))
        ops.append(st('body', 11, body_y, BODY_RIGHT))
        if skirt:
            ops.append(st('body', 11, body_y + 5, SKIRT_RIGHT))
        if char.get('towel'):
            ops.append(st('acc', 15, body_y, TOWEL_RIGHT))
        ops.append(st('head', 10, head_y, HEAD_RIGHT))
        if char.get('bun') == 'top':
            ops.append(st('head', 11, head_y - 2, BUN['right']))
        elif char.get('bun') == 'twin':
            ops.append(st('head', 8, head_y, TWIN_BUNS))
        if char.get('hat'):
            ops.append(st('acc', 8, head_y - 3, HAT_RIGHT))
        ops.append(st('arms', 15 + arm_swing, body_y + 1, ARM_RIGHT_FRONT))
    return ops


def build(name):
    char = CHARACTERS[name]
    doc = new_project('es-' + name, 32, 32, ['shadow', 'legs', 'arms_back', 'body', 'arms', 'acc', 'head'])
    # head above acc so the bun shows; the hat goes on 'acc' but is stamped after the head (below)
    frames = [{'op': 'frame_add', 'after': i, 'blank': True, 'duration_ms': WALK_MS} for i in range(14)]
    frames.append({'op': 'frame_set', 'frame': 0, 'duration_ms': IDLE_MS})
    for d in DIRS:
        base = DIRS.index(d) * 5
        frames += [{'op': 'frame_set', 'frame': base, 'duration_ms': IDLE_MS},
                   {'op': 'tag_set', 'name': 'idle_' + d, 'start': base, 'end': base},
                   {'op': 'tag_set', 'name': 'walk_' + d, 'start': base + 1, 'end': base + 4}]
    doc.edit(frames, 'frames and actions')
    ops = []
    for d in DIRS:
        for k in range(-1, 4):
            ops += ops_for(char, d, k)
    if char.get('hat'):
        ops.insert(0, {'op': 'layer_move', 'layer': 'acc', 'index': 6})
    doc.edit(ops, name + ' poses')
    r = call('pixel_contact_sheet', {'frames': list(range(15)), 'scale': 6, 'columns': 5})
    from loomlib import save_images
    print(name, save_images(r['images'], 'char_' + name), doc.rev)
    return doc


if __name__ == '__main__':
    for n in (sys.argv[1:] or CHARACTERS):
        build(n)
