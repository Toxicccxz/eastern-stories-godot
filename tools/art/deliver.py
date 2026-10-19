"""Pixel Loom's delivery gate for the art trial, one project at a time.

    py deliver.py review <project name> [criteria...]   settings + pixel_review; evidence saved to build/art/previews/
    py deliver.py submit <project name> <json file>     pixel_review_submit with my observations
    py deliver.py export <project name> <png|sheet>      save .pixloom and export to build/art/exports/
"""
import json
import os
import sys

from loomlib import Doc, call, save_images, _find

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORTS = os.path.join(HERE, '..', '..', 'build', 'art', 'exports')
STATE = os.path.join(HERE, '..', '..', 'build', 'art', 'previews', 'review_state_{}.json')

BRIEFS = {
    'inn-room': ('饮风客栈 ground floor backdrop for a Godot top-down RPG, 480x352, aligned to the map layout: '
                 'back wall with windows, lanterns, scrolls, the red-wood door NW, stairs NE, the east door, plank floor, runner.',
                 480, 352, 1, False),
    'inn-table-tea': ('Lacquered tea table prop, 3/4 top-down, teapot and cups', 32, 24, 1, True),
    'inn-table-meal': ('Lacquered tea table prop, 3/4 top-down, bowls, a dish and chopsticks', 32, 24, 1, True),
    'inn-table-wine': ('Lacquered tea table prop, 3/4 top-down, a wine jug and cups', 32, 24, 1, True),
    'inn-counter': ('Inn counter prop 160x26: wooden top with abacus, ledger, bell, cups and a jar; lacquered red front panels with brass', 160, 26, 1, True),
    'inn-jar-shelf': ('Two-tier wooden rack of wine jars against the back wall, 192x32', 192, 32, 1, True),
}
BRIEFS['es-ui-atlas'] = ('东方漆木 UI atlas: paper and lacquer 9-slice panels with gold corner fittings, paper button states, a lacquer tab, insets, focus ring and bubble', 144, 80, 1, True)
for c in ('player_male', 'player_female', 'waiter', 'traveller_a', 'traveller_b'):
    BRIEFS['es-' + c] = (f'{c}: 32x32 chibi wuxia character; idle and 4-frame walk facing down, up and right; '
                         'feet on y=30; left is mirrored in the engine.', 32, 32, 15, True)


def latest(name):
    page, best = 0, None
    while True:
        d = call('pixel_projects', {'action': 'list', 'limit': 100, 'page': page, 'compact': True})['data']
        for p in d['projects']:
            if p['name'] == name and (best is None or p['created_at'] > best['created_at']):
                best = p
        if not d.get('has_more'):
            break
        page += 1
    return best


def switch(name):
    p = latest(name)
    st = call('pixel_status', {'compact': True})['data']
    if _find(st, 'name') != name or _find(st, 'document_id') != p['document_id']:
        call('pixel_projects', {'action': 'switch', 'project_id': p['id'], 'compact': True})
    return Doc()


def review(name, extra):
    doc = switch(name)
    brief, w, h, frames, transparent = BRIEFS[name]
    criteria = ['Reads clearly at the game scale (2x) over the inn floor', 'Consistent light from the top and the shared 东方漆木 palette',
                'No stray pixels, holes or broken outlines'] + extra
    if frames > 1:
        criteria += ['Each walk cycle alternates feet and arms without jumps; the head and body keep their size',
                     'Idle frames match the first walk pose of the same direction']
    settings = {'brief': brief, 'expected_width': w, 'expected_height': h, 'expected_frames': frames,
                'transparent_background': transparent, 'criteria': criteria, 'max_rounds': 6}
    r = call('pixel_review_settings', {'settings': settings, 'compact': True, **doc.tokens()})
    doc.refresh()
    r = call('pixel_review', {'show_in_editor': False})
    data = r['data']
    paths = save_images(r['images'], 'review_' + name)
    pages = _find(data, 'pages') or _find(data, 'page_count')
    rid = _find(data, 'review_id')
    out = {'review_id': rid, 'paths': paths, 'data': data}
    page = 1
    while isinstance(pages, int) and page < pages:
        rr = call('pixel_review', {'review_id': rid, 'page': page, 'show_in_editor': False})
        out['paths'] += save_images(rr['images'], f'review_{name}_p{page}')
        page += 1
    json.dump({'name': name, 'review_id': rid}, open(STATE.format(name), 'w'))
    print(json.dumps({k: v for k, v in data.items() if k not in ('evidence',)}, ensure_ascii=False, indent=1)[:6000])
    print('IMAGES', out['paths'])


def submit(name, path):
    doc = switch(name)
    body = json.load(open(path, encoding='utf-8'))
    st = json.load(open(STATE.format(name)))
    r = call('pixel_review_submit', {'review_id': st['review_id'], 'method': 'frames_and_timing', 'compact': True,
                                     **body, **doc.tokens()})
    print(json.dumps(r['data'], ensure_ascii=False)[:3000])


def export(name, kind):
    doc = switch(name)
    path = 'eastern-stories/' + name + '.pixloom'
    r = call('pixel_project', {'action': 'save', 'path': path, 'overwrite': True, 'compact': True, **doc.tokens()})
    print('saved', _find(r['data'], 'project_path') or _find(r['data'], 'path'))
    os.makedirs(EXPORTS, exist_ok=True)
    target = os.path.join(EXPORTS, name + '.png')
    args = {'path': target, 'overwrite': True}
    if kind == 'png2':
        args['scale'] = 2
    if kind == 'sheet':
        args.update({'kind': 'sheet', 'sheet_format': 'godot', 'columns': 5})
    r = call('pixel_export', args)
    print(json.dumps(r['data'], ensure_ascii=False)[:1500])


if __name__ == '__main__':
    cmd, name = sys.argv[1], sys.argv[2]
    if cmd == 'review':
        review(name, sys.argv[3:])
    elif cmd == 'submit':
        submit(name, sys.argv[3])
    elif cmd == 'export':
        export(name, sys.argv[3])
