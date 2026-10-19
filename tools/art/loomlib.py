"""Client over the Pixel Loom bridge: the art trial's pictures are drawn with Pixel Loom's native
operations (rect/line/pixel/polygon/stamp ...); the host only computes geometry and sends batches.

Setup (nothing of it is committed): unpack the Pixel Loom 0.7.17 Windows portable release
(github.com/yangsir2077/pixel-loom, MIT) under build/tools/pixel-loom/, then keep one MCP server alive:

    py tools/art/loom_bridge.py build/tools/pixel-loom/PixelLoom/app/PixelLoomMCP.exe build/art/loom_stderr.log

Drawing: room.py, props.py, characters.py, ui_atlas.py (each makes its projects; previews go to
build/art/previews/). Delivery through Pixel Loom's review gate: deliver.py review, look at every
evidence page, verdicts.py, deliver.py submit / export (build/art/exports/), then copy the PNGs (and a
character's SpriteFrames .tres) into game/presentation/art/ or game/ui/theme/. The editable projects
are tools/art/pixloom/*.pixloom.
"""
from __future__ import annotations

import base64
import json
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'build', 'art', 'previews')


def call(name: str, args: dict | None = None) -> dict:
    req = urllib.request.Request('http://127.0.0.1:8765/call',
                                 data=json.dumps({'name': name, 'arguments': args or {}}).encode('utf-8'),
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=900) as r:
        res = json.loads(r.read())
    if 'result' not in res:
        raise RuntimeError(json.dumps(res, ensure_ascii=False)[:2000])
    result = res['result']
    texts, images = [], []
    for item in result.get('content', []):
        if item.get('type') == 'text':
            texts.append(item['text'])
        elif item.get('type') == 'image':
            images.append(base64.b64decode(item['data']))
    if result.get('isError'):
        raise RuntimeError(name + ': ' + '\n'.join(texts)[:4000])
    data = None
    for t in texts:
        try:
            data = json.loads(t)
            break
        except ValueError:
            continue
    if data is None and result.get('structuredContent'):
        data = result['structuredContent']
    return {'data': data, 'texts': texts, 'images': images}


def save_images(images: list, stem: str) -> list:
    os.makedirs(OUT, exist_ok=True)
    paths = []
    for i, png in enumerate(images):
        p = os.path.join(OUT, f'{stem}{"" if i == 0 else "_" + str(i)}.png')
        with open(p, 'wb') as f:
            f.write(png)
        paths.append(p)
    return paths


def _find(d, key):
    if isinstance(d, dict):
        if key in d:
            return d[key]
        for v in d.values():
            r = _find(v, key)
            if r is not None:
                return r
    elif isinstance(d, list):
        for v in d:
            r = _find(v, key)
            if r is not None:
                return r
    return None


class Doc:
    """The active Pixel Loom document and its tokens."""

    def __init__(self):
        self.refresh()

    def refresh(self):
        st = call('pixel_status', {'compact': True})['data']
        self.doc_id = _find(st, 'document_id')
        self.rev = _find(st, 'revision')
        self.status = st
        return st

    def tokens(self):
        return {'expected_document_id': self.doc_id, 'expected_revision': self.rev}

    def _take(self, data):
        rev = _find(data, 'revision')
        did = _find(data, 'document_id')
        if rev is not None:
            self.rev = rev
        if did is not None:
            self.doc_id = did

    known: set | None = None

    def _palette_ops(self, ops: list) -> list:
        """palette_add for colours the batch uses that the palette lacks."""
        if self.known is None:
            st = call('pixel_status', {'compact': False})['data']
            pal = _find(st, 'palette') or []
            self.known = {_norm(c) for c in pal if isinstance(c, str)}
        used = []
        for op in ops:
            cols = [op['color']] if isinstance(op.get('color'), str) else []
            cols += [c for c in (op.get('colors') or {}).values() if isinstance(c, str)] if isinstance(op.get('colors'), dict) else []
            for c in cols:
                n = _norm(c)
                if n not in self.known and n not in used:
                    used.append(n)
        self.known.update(used)
        return [{'op': 'palette_add', 'colors': used[i:i + 200]} for i in range(0, len(used), 200)]

    def edit(self, ops: list, label: str, preview_stem: str | None = None) -> list:
        """One atomic batch; splits very large op lists into several labelled batches."""
        ops = self._palette_ops(ops) + ops
        paths = []
        chunk = 1500
        for start in range(0, len(ops), chunk):
            part = ops[start:start + chunk]
            last = start + chunk >= len(ops)
            r = call('pixel_edit', {'ops': part, 'label': label, 'compact': True,
                                    'include_preview': bool(preview_stem) and last, **self.tokens()})
            self._take(r['data'])
            if preview_stem and last and r['images']:
                paths = save_images(r['images'], preview_stem)
        return paths

    def preview(self, stem: str, scale: int = 2, frame=None, layers=None, rect=None, checker=True) -> list:
        args = {'scale': scale, 'checker': checker}
        if frame is not None:
            args['frame'] = frame
        if layers is not None:
            args['layers'] = layers
        if rect is not None:
            args['rect'] = rect
        r = call('pixel_preview', args)
        return save_images(r['images'], stem)


def _norm(c: str) -> str:
    c = c.lower()
    return c if len(c) == 9 else c + 'ff'


def new_project(name: str, width: int, height: int, layers: list[str] = ()) -> Doc:
    """A blank project on the shared palette, the default layer replaced by `layers` (bottom first)."""
    import palette
    call('pixel_projects', {'action': 'new', 'name': name, 'width': width, 'height': height, 'compact': True})
    doc = Doc()
    st = call('pixel_status', {'compact': False})['data']
    default_layers = [l['id'] for l in st['layers']]
    colors = ['#00000000'] + [v for k, v in vars(palette).items() if k.isupper() and isinstance(v, str)]
    ops = [{'op': 'palette_set', 'colors': colors, 'remap': False}]
    ops += [layer_add(l) for l in layers]
    ops += [{'op': 'layer_delete', 'layer': lid} for lid in default_layers] if layers else []
    doc.known = {_norm(c) for c in colors}
    r = call('pixel_edit', {'ops': ops, 'label': 'palette and layers', 'compact': True, 'include_preview': False, **doc.tokens()})
    doc._take(r['data'])
    return doc


# --- geometry helpers that produce native ops ------------------------------------------------

def rect(layer, x, y, w, h, color, frame=None):
    op = {'op': 'rect', 'layer': layer, 'x': x, 'y': y, 'width': w, 'height': h, 'color': color, 'filled': True}
    if frame is not None:
        op['frame'] = frame
    return op


def hline(layer, x0, x1, y, color, frame=None):
    return rect(layer, min(x0, x1), y, abs(x1 - x0) + 1, 1, color, frame)


def vline(layer, x, y0, y1, color, frame=None):
    return rect(layer, x, min(y0, y1), 1, abs(y1 - y0) + 1, color, frame)


def px(layer, x, y, color, frame=None):
    op = {'op': 'pixel', 'layer': layer, 'x': x, 'y': y, 'color': color}
    if frame is not None:
        op['frame'] = frame
    return op


def poly(layer, points, color, frame=None, filled=True):
    op = {'op': 'polygon', 'layer': layer, 'points': [list(p) for p in points], 'color': color, 'filled': filled}
    if frame is not None:
        op['frame'] = frame
    return op


def line(layer, x1, y1, x2, y2, color, frame=None):
    op = {'op': 'line', 'layer': layer, 'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'color': color}
    if frame is not None:
        op['frame'] = frame
    return op


def stamp(layer, x, y, rows: list[str], colors: dict, frame=None):
    """ASCII pattern: '.' leaves pixels unchanged; other chars map through `colors`."""
    op = {'op': 'stamp', 'layer': layer, 'x': x, 'y': y, 'rows': rows, 'colors': colors}
    if frame is not None:
        op['frame'] = frame
    return op


def layer_add(lid, name=None):
    return {'op': 'layer_add', 'id': lid, 'name': name or lid}
