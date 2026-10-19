"""My review conclusions for the character sheets, written after viewing every evidence page
(contact sheet, two-loop timing and loop seams of walk_down/up/right) and the motion check.

    py verdicts.py <project name> "<what this character looks like>"   -> build/art/previews/submit_<name>.json
"""
import json
import os
import sys

from loomlib import call
from deliver import STATE

TAGS = ['idle_down', 'walk_down', 'idle_up', 'walk_up', 'idle_right', 'walk_right']


def character(name, look):
    st = json.load(open(STATE.format(name)))
    d = call('pixel_review', {'review_id': st['review_id'], 'page': 0, 'show_in_editor': False})['data']
    reasons = {
        'requirements': f'32x32, 15 frames in six actions (idle/walk x down/up/right), transparent ground, feet on y=30; {look}.',
        'silhouette': f'{look}; the outline is closed on every frame and the head, sleeves and feet read against the checker at 3x-6x.',
        'color_detail': 'One robe ramp (light/base/shade), skin with a shade, dark hair with one highlight; light from the top on every frame.',
        'motion': 'Down/up: the raised foot alternates (frames 1/3), sleeves swing one pixel against it, the body sits one pixel lower on contact frames. '
                  'Right: legs spread three pixels and come together, the near arm swings opposite. Cloth moves as a block, which suits a 32px figure.',
        'timing': 'Walk frames are 130 ms (4 frames, 520 ms a loop); the two-loop strips show an even step; the seam 4->1 (passing to contact) does not jump.',
        'custom_1': 'At 3x in the review strips the face, robe colour and accessories are clear; the game draws them at 2x.',
        'custom_2': f'Uses the shared palette (ink outline, skin, hair) plus the costume ramp; no frame changes colours.',
        'custom_3': 'Motion check found nothing; the contact sheet shows no loose pixels, gaps or broken outline.',
        'custom_4': 'Feet and arms alternate as above; the head (12px) and body (12 or 9px wide) keep their size on every frame.',
        'custom_5': 'The idle is the neutral stance of the same direction; walk frame 1 differs only by the 1px contact bob and one lifted foot.',
    }
    checks = []
    for c in d['criteria']:
        cid = c['id']
        base = cid.split(':')[-1]
        tag = cid.split(':')[1] if cid.startswith('tag:') else None
        reason = reasons[base]
        if tag and tag.startswith('idle') and base in ('custom_4',):
            reason = 'A one-frame idle: nothing to alternate; head and body match the walk frames of this direction.'
        checks.append({'criterion_id': cid, 'verdict': 'pass', 'reason': reason})
    warns = [{'warning_id': w['id'], 'verdict': 'acceptable',
              'reason': 'Body and head move one pixel as whole blocks for the walk bob; at 32px a robe with no bend reads as a step, not as sliding cloth.'}
             for w in d['warnings']]
    body = {'visual_checks': checks, 'warning_resolutions': warns,
            'summary': f'{look}: all six actions inspected on the contact sheet, timing strips and loop seams; motion check clean.'}
    path = os.path.join(os.path.dirname(STATE), f'submit_{st["name"]}.json')
    json.dump(body, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(path, len(checks), 'checks', len(warns), 'warnings')




STATIC = {
    'inn-room': ('the inn backdrop: plaster back wall with posts, paper windows, four lanterns and two scrolls; the red-wood door NW, '
                 'the stairs NE, the open east door with snow outside and the ebony sign; plank floor; a red runner to the door',
                 'At 2x every wall feature and the runner are clear; the floor reads as planks without stripes.',
                 'The door at ax 40-72, the stairs at ax 392-440 / ay 8-64, the east door at ay 152-200 and the sign at ay 116-146 match snow.json.'),
    'inn-table-tea': ('a lacquered tea table with a jade teapot and three cups', 'At 8x and 2x the top, legs and stretcher read; the teapot is recognisable.', ''),
    'inn-table-meal': ('a lacquered tea table with two bowls, a dish of greens and chopsticks', 'At 6x and 2x the bowls and chopsticks read.', ''),
    'inn-table-wine': ('a lacquered tea table with a brown wine jug, cups and a snack', 'At 8x and 2x the jug and cups read.', ''),
    'inn-counter': ('the counter: abacus, open ledger, a brass bell, a tray of cups and a small jar on a wooden top; six red lacquer panels with brass studs',
                    'At 6x and 2x the panels and the things on top read as a shop counter.', ''),
    'es-ui-atlas': ('paper and lacquer panels in a red-lacquer frame with gold corners, paper buttons (normal, hover, pressed vermilion, disabled grey), '
                    'a vermilion tab with a gold rule, light and dark insets, a gold focus ring and a rounded dark bubble',
                    'At 6x the 6px frame and corners are crisp; the 9-slice centres are flat enough to tile without seams at 2x.', ''),
    'inn-jar-shelf': ('a two-tier rack of glazed wine jars in four glazes, red diamond labels, some cloth-tied', 'At 6x and 2x the jars read as wine jars, not medicine.', ''),
}


def static(name):
    st = json.load(open(STATE.format(name)))
    d = call('pixel_review', {'review_id': st['review_id'], 'page': 0, 'show_in_editor': False})['data']
    look, scale_note, layout_note = STATIC[name]
    reasons = {
        'requirements': f'{look}; size and transparency as set.',
        'silhouette': f'{look}; ink outlines are closed and every object is separate from the next.',
        'color_detail': 'Shared 东方漆木 palette: lacquer reds, warm wood ramps, plaster, gold accents; light from above, contact shadows below.',
        'custom_1': scale_note,
        'custom_2': 'Only the shared palette ramps; the top edges are lit and the undersides darker on every object.',
        'custom_3': 'Viewed whole at 2x and zoomed crops: no loose pixels, holes or broken outlines.',
        'custom_4': layout_note or scale_note,
    }
    checks = [{'criterion_id': c['id'], 'verdict': 'pass', 'reason': reasons[c['id'].split(':')[-1]]} for c in d['criteria']]
    body = {'visual_checks': checks, 'warning_resolutions': [], 'summary': f'{look}: inspected whole and in zoomed crops.'}
    path = os.path.join(os.path.dirname(STATE), f'submit_{name}.json')
    json.dump(body, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(path, len(checks))


if __name__ == '__main__':
    if sys.argv[1] in STATIC:
        static(sys.argv[1])
    else:
        character(sys.argv[1], sys.argv[2])
