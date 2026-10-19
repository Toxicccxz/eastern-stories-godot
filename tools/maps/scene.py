"""Scene text builders: the .tscn header, the two scene skeletons and the node blocks.

Two skeletons exist, as the maps were drawn:
* `map`: string resource ids, the tile layers under a Terrain node, CorpseLayer and Interactions,
  a square player with camera limits (Old Pine, 绮云镇, 野羊山).
* `flat`: numeric resource ids as in snow_inn.tscn, the tile layers at the root, a polygon player
  with a zoomed camera (Snow's inn upstairs and cellar).
"""

from __future__ import annotations

WORLD = 'res://runtime/world/'
TILESET = ('[ext_resource type="TileSet" path="res://scenes/world/common/placeholder_terrain_tileset.tres" '
           'id="terrain_tiles"]\n\n')
DOOR_SCRIPT = ('world_door.gd', 'door')
SERVICE_SCRIPT = ('world_service_point.gd', 'service')

STYLES = {
    'map': {
        'scripts': [('world_map_controller.gd', 'map'), ('world_spawn_marker_2d.gd', 'marker'),
                    ('world_character_body_2d.gd', 'body'), ('world_landmark_area_2d.gd', 'landmark'),
                    ('world_passage_area_2d.gd', 'passage'), ('world_physical_zone_area_2d.gd', 'zone')],
        'defaults': {'marker': {'script': 'marker'}, 'zone': {'script': 'zone'}, 'stairs': {'script': 'passage'}},
    },
    'flat': {
        'scripts': [('world_map_controller.gd', '1'), ('world_character_body_2d.gd', '2'),
                    ('world_spawn_marker_2d.gd', '3'), ('world_physical_zone_area_2d.gd', '4'),
                    ('world_passage_area_2d.gd', '5')],
        'defaults': {'marker': {'script': '3'}, 'zone': {'script': '4', 'pickable': False}, 'stairs': {'script': '5'}},
    },
}


# --- Node blocks ---------------------------------------------------------------------------

def group(name, type='Node2D', parent='.'):
    return f'[node name="{name}" type="{type}" parent="{parent}"]\n\n'


def marker(name, at, id, script='marker'):
    return (f'[node name="{name}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({at[0]}, {at[1]})\n'
            f'script = ExtResource("{script}")\nspawn_point_id = &"{id}"\n\n')


def zone(name, id, at, shape, script='zone', pickable=True):
    pick = '' if pickable else 'input_pickable = false\n'
    return (f'[node name="{name}" type="Area2D" parent="Zones"]\nposition = Vector2({at[0]}, {at[1]})\n'
            f'collision_layer = 0\n{pick}script = ExtResource("{script}")\nzone_id = &"{id}"\n\n'
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Zones/{name}"]\nshape = SubResource("{shape}")\n\n')


def landmark(name, id, at, shape, script='landmark'):
    return (f'[node name="{name}" type="Area2D" parent="Interactions"]\nposition = Vector2({at[0]}, {at[1]})\n'
            f'collision_layer = 2\nscript = ExtResource("{script}")\nlandmark_id = &"{id}"\n\n'
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Interactions/{name}"]\nshape = SubResource("{shape}")\n\n')


def passage(name, id, at, shape, script='passage'):
    return (f'[node name="{name}" type="Area2D" parent="."]\nposition = Vector2({at[0]}, {at[1]})\n'
            f'collision_layer = 0\ninput_pickable = false\nscript = ExtResource("{script}")\nportal_id = &"{id}"\n\n'
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{name}"]\nshape = SubResource("{shape}")\n\n')


def service(name, id, at, text='', script='service', hidden=False):
    """A service point (services[] in world.json): a blue diamond, its label below. A hidden one
    (a secret: d/canyon/canyon4.c's swear) is the bare point, found by its context button."""
    label = (f'[node name="Label" type="Label" parent="{name}"]\noffset_left = -100.0\noffset_top = 26.0\n'
             f'offset_right = 100.0\nmouse_filter = 2\ntext = "{text}"\nhorizontal_alignment = 1\n\n') if text else ''
    point = (f'[node name="{name}" type="Marker2D" parent="."]\nposition = Vector2({at[0]}, {at[1]})\n'
             f'script = ExtResource("{script}")\nservice_id = &"{id}"\n\n')
    if hidden:
        assert not text, ('a hidden service has no label', name)
        return point
    return (point + f'[node name="Visual" type="Polygon2D" parent="{name}"]\n'
            'polygon = PackedVector2Array(0, -20, 16, 8, 0, 20, -16, 8)\ncolor = Color(0.5, 0.85, 1, 1)\n\n' + label)


def rect(name, rect, color, parent='Terrain'):
    x0, y0, x1, y1 = rect
    return (f'[node name="{name}" type="ColorRect" parent="{parent}"]\noffset_left = {x0}\noffset_top = {y0}\n'
            f'offset_right = {x1}\noffset_bottom = {y1}\nmouse_filter = 2\ncolor = {color}\n\n')


def caption(name, at, text, size=22, parent='Terrain'):
    """A map-style label: integer offsets, 1 px wide, font size always set."""
    x, y = at
    return (f'[node name="{name}" type="Label" parent="{parent}"]\noffset_left = {x}\noffset_top = {y}\n'
            f'offset_right = {x + 1}\noffset_bottom = {y + 23}\nmouse_filter = 2\n'
            f'theme_override_font_sizes/font_size = {size}\ntext = "{text}"\n\n')


def label(name, at, text, size=0, parent='Ground'):
    """A flat-style label: float offsets, font size only when given."""
    font = f'theme_override_font_sizes/font_size = {size}\n' if size else ''
    return (f'[node name="{name}" type="Label" parent="{parent}"]\noffset_left = {at[0]}.0\noffset_top = {at[1]}.0\n'
            f'text = "{text}"\n{font}mouse_filter = 2\n\n')


def stairs(name, at, id, shape, extent, color, text, script='passage', parent='.', drawn=True):
    """A passage drawn as a flight of steps the size of its shape, named above it; on a map drawn
    by pictures (`scene.art`) the picture shows the stairs and the passage is bare."""
    w, h = extent
    child = name if parent == '.' else f'{parent}/{name}'
    area = (f'[node name="{name}" type="Area2D" parent="{parent}"]\nposition = Vector2({at[0]}, {at[1]})\n'
            f'collision_layer = 0\ninput_pickable = false\nscript = ExtResource("{script}")\nportal_id = &"{id}"\n\n'
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{child}"]\nshape = SubResource("{shape}")\n\n')
    if not drawn:
        return area
    return (area +
            f'[node name="Steps" type="Polygon2D" parent="{child}"]\n'
            f'polygon = PackedVector2Array({-w // 2}, {-h // 2}, {w // 2}, {-h // 2}, {w // 2}, {h // 2}, {-w // 2}, {h // 2})\n'
            f'color = {color}\n\n'
            f'[node name="StepLines" type="Line2D" parent="{child}"]\n'
            f'points = PackedVector2Array({-w // 2}, {-h // 6}, {w // 2}, {-h // 6}, {w // 2}, {h // 6}, {-w // 2}, {h // 6})\n'
            f'width = 2.0\ndefault_color = Color(0.2, 0.15, 0.1, 1)\n\n'
            f'[node name="Name" type="Label" parent="{child}"]\noffset_left = {-w // 2 - 20}.0\n'
            f'offset_top = {-h // 2 - 26}.0\noffset_right = {w // 2 + 20}.0\ntext = "{text}"\n'
            f'horizontal_alignment = 1\nmouse_filter = 2\n\n')


def door_parts(name, id, at, extent, shape, style):
    """A door: its wall shape across the doorway, the shutter drawn over it and the door node."""
    cx, cy = at
    w, h = extent
    walls, shutters = style['walls'], style['shutters']
    wall_name = name + style.get('wall_suffix', '')
    wall = (f'[node name="{wall_name}" type="CollisionShape2D" parent="{walls}"]\n'
            f'position = Vector2({cx}, {cy})\nshape = SubResource("{shape}")\n\n')
    shutter = (f'[node name="{name}Shutter" type="Polygon2D" parent="{shutters}"]\n'
               f'polygon = PackedVector2Array({cx - w // 2}, {cy - h // 2}, {cx + w // 2}, {cy - h // 2}, '
               f'{cx + w // 2}, {cy + h // 2}, {cx - w // 2}, {cy + h // 2})\ncolor = {style["color"]}\n\n')
    door = (f'[node name="{name}" type="Node" parent="."]\nscript = ExtResource("door")\ndoor_id = &"{id}"\n'
            f'wall = NodePath("../{walls}/{wall_name}")\nshutter = NodePath("../{shutters}/{name}Shutter")\n\n')
    return wall, shutter, door


def shapes(sizes: dict) -> str:
    return ''.join(f'[sub_resource type="RectangleShape2D" id="{k}"]\nsize = Vector2({w}, {h})\n\n' for k, (w, h) in sizes.items())


BUILDERS = {f.__name__: f for f in (group, marker, zone, landmark, passage, service, rect, caption, label, stairs)}


def render(items: list, default: str, style: str, fragments: dict) -> str:
    """A slot's node list: {"generated": name} inserts what the drawing made, anything else is a
    node block built by its "node" builder (or the slot's default) from the remaining fields."""
    out = ''
    for item in items:
        if 'generated' in item:
            out += fragments[item['generated']]
            continue
        fields = {k: v for k, v in item.items() if k not in ('node', 'note')}
        kind = item.get('node', default)
        out += build(kind, style, **fields)
    return out


def build(kind: str, style: str, **fields) -> str:
    for key, value in STYLES[style]['defaults'].get(kind, {}).items():
        fields.setdefault(key, value)
    return BUILDERS[kind](**fields)


# --- Skeletons ------------------------------------------------------------------------------

def header(style: str, doors: bool, services: bool = False, textures: dict | None = None) -> str:
    scripts = STYLES[style]['scripts'] + ([DOOR_SCRIPT] if doors else []) + ([SERVICE_SCRIPT] if services else [])
    return ('[gd_scene format=3]\n\n'
            + ''.join(f'[ext_resource type="Script" path="{WORLD}{path}" id="{rid}"]\n' for path, rid in scripts)
            + ''.join(f'[ext_resource type="Texture2D" path="{path}" id="{rid}"]\n' for path, rid in (textures or {}).items())
            + TILESET)


# --- Art ------------------------------------------------------------------------------------
# A map with `scene.art` is drawn by pictures instead of its tiles: the tiles stay (hidden) and
# keep every collision; the room's picture lies under everything and each prop that names its
# picture stands on the bottom edge of its box, sorted by y with the characters.

def art_textures(art: dict, props: list) -> dict:
    """Texture path -> resource id, the room's first, then the props' in the order they appear."""
    paths = [art['room']] + [row[-1]['art'] for row in props if isinstance(row[-1], dict) and 'art' in row[-1]]
    ids: dict = {}
    for path in paths:
        ids.setdefault(path, 'art_room' if not ids else f'art_{len(ids)}')
    return ids


def art_room(art: dict, bounds, textures: dict) -> str:
    k = art.get('scale', 2)
    return ('[node name="Art" type="Node2D" parent="."]\nz_index = -10\ntexture_filter = 1\n\n'
            f'[node name="Room" type="Sprite2D" parent="Art"]\nposition = Vector2({bounds[0]}, {bounds[1]})\n'
            f'scale = Vector2({k}, {k})\ntexture = ExtResource("{textures[art["room"]]}")\ncentered = false\n\n')


def art_props(art: dict, props: list, textures: dict, sizes: dict) -> str:
    """Each prop's picture (`sizes`: its texture size in art px), centred on its box's bottom edge."""
    k = art.get('scale', 2)
    out = '[node name="Props" type="Node2D" parent="."]\ny_sort_enabled = true\ntexture_filter = 1\n\n'
    counts: dict = {}
    for row in props:
        if not (isinstance(row[-1], dict) and 'art' in row[-1]):
            continue
        path = row[-1]['art']
        x0, _y0, x1, y1 = row[1:5]
        w, h = sizes[path]
        stem = ''.join(part.capitalize() for part in path.rsplit('/', 1)[-1].split('.')[0].split('_'))
        counts[stem] = counts.get(stem, 0) + 1
        assert (x0 + x1) % 2 == 0 and w % 2 == 0, ('a prop centres on whole pixels', path, row)
        out += (f'[node name="{stem}{counts[stem]}" type="Sprite2D" parent="Props"]\n'
                f'position = Vector2({(x0 + x1) // 2}, {y1})\nscale = Vector2({k}, {k})\n'
                f'texture = ExtResource("{textures[path]}")\ncentered = false\noffset = Vector2({-w // 2}, {-h})\n\n')
    return out


def map_scene(root, map_id, sizes, nodes, zones, spawn_points, interactions, limits, player_color, doors=False,
              services=False, backdrop=None, art=None):
    """`backdrop`: (colour, box) drawn behind the tiles, a trimmed filler's colour over the drawing.
    `art`: (scene.art, its textures, the room's nodes, the props' nodes) for a map drawn by pictures."""
    sizes = dict(sizes)
    sizes['Rect_34_34'] = (34, 34)
    if art and backdrop:
        backdrop = (art[0].get('surround', backdrop[0]), backdrop[1])
    behind = rect('Backdrop', backdrop[1], backdrop[0], parent='.') if backdrop else ''
    if art and behind:
        behind = behind.replace('parent="."]\n', 'parent="."]\nz_index = -20\n', 1)
    return (header('map', doors, services, art[1] if art else None) + shapes(sizes) +
            f'[node name="{root}" type="Node2D"]\n' + ('y_sort_enabled = true\n' if art else '') +
            f'script = ExtResource("map")\nmap = &"{map_id}"\n\n' + behind +
            '[node name="Terrain" type="Node2D" parent="."]\n' + ('visible = false\n' if art else '') + '\n'
            '[node name="TerrainGround" type="TileMapLayer" parent="Terrain"]\ntile_map_data = PackedByteArray()\ntile_set = ExtResource("terrain_tiles")\n\n'
            '[node name="TerrainStructures" type="TileMapLayer" parent="Terrain"]\ntile_map_data = PackedByteArray()\ntile_set = ExtResource("terrain_tiles")\n\n'
            + nodes + (art[2] if art else '') +
            '[node name="Zones" type="Node2D" parent="."]\n\n' + zones +
            '[node name="SpawnPoints" type="Node2D" parent="."]\n' + ('z_index = -1\n' if art else '') + '\n' + spawn_points +
            '[node name="Characters" type="Node2D" parent="."]\n' + ('y_sort_enabled = true\n' if art else '') + '\n'
            '[node name="Player" type="CharacterBody2D" parent="Characters"]\nunique_name_in_owner = true\nscript = ExtResource("body")\n\n'
            '[node name="Visual" type="ColorRect" parent="Characters/Player"]\noffset_left = -18.0\noffset_top = -18.0\n'
            f'offset_right = 18.0\noffset_bottom = 18.0\nmouse_filter = 2\ncolor = {player_color}\n\n'
            '[node name="CollisionShape2D" type="CollisionShape2D" parent="Characters/Player"]\nshape = SubResource("Rect_34_34")\n\n'
            '[node name="NameLabel" type="Label" parent="Characters/Player"]\noffset_left = -58.0\noffset_top = -48.0\n'
            'offset_right = -57.0\noffset_bottom = -25.0\ntheme_override_font_sizes/font_size = 16\n\n'
            '[node name="Camera2D" type="Camera2D" parent="Characters/Player"]\nenabled = false\n'
            f'limit_left = {limits[0]}\nlimit_top = {limits[1]}\nlimit_right = {limits[2]}\nlimit_bottom = {limits[3]}\n'
            'position_smoothing_enabled = true\nposition_smoothing_speed = 6.0\n\n'
            + (art[3] if art else '') +
            '[node name="CorpseLayer" type="Node2D" parent="."]\n' + ('z_index = -1\n' if art else '') + '\n'
            '[node name="Interactions" type="Node2D" parent="."]\n' + ('z_index = -1\n' if art else '') + '\n' + interactions)


def flat_scene(root, map_id, sizes, nodes, zones, spawn_points, player_color, zoom, doors=False):
    """Player shape: the layout lists `PlayerShape` among its shapes."""
    return (header('flat', doors) + shapes(sizes) +
            f'[node name="{root}" type="Node2D"]\nscript = ExtResource("1")\nmap = &"{map_id}"\n\n'
            '[node name="TerrainGround" type="TileMapLayer" parent="."]\ntile_map_data = PackedByteArray()\ntile_set = ExtResource("terrain_tiles")\n\n'
            '[node name="TerrainStructures" type="TileMapLayer" parent="."]\ntile_map_data = PackedByteArray()\ntile_set = ExtResource("terrain_tiles")\n\n'
            + nodes +
            '[node name="Zones" type="Node2D" parent="."]\n\n' + zones +
            '[node name="SpawnPoints" type="Node2D" parent="."]\n\n' + spawn_points +
            '[node name="Characters" type="Node2D" parent="."]\n\n'
            '[node name="Player" type="CharacterBody2D" parent="Characters"]\nunique_name_in_owner = true\nscript = ExtResource("2")\n\n'
            '[node name="Visual" type="Polygon2D" parent="Characters/Player"]\npolygon = PackedVector2Array(-17, -17, 17, -17, 17, 17, -17, 17)\n'
            f'color = {player_color}\n\n'
            '[node name="CollisionShape2D" type="CollisionShape2D" parent="Characters/Player"]\nshape = SubResource("PlayerShape")\n\n'
            '[node name="NameLabel" type="Label" parent="Characters/Player"]\noffset_left = -45.0\noffset_top = -46.0\noffset_right = 45.0\noffset_bottom = -20.0\nhorizontal_alignment = 1\nmouse_filter = 2\n\n'
            f'[node name="Camera2D" type="Camera2D" parent="Characters/Player"]\nenabled = false\nzoom = Vector2({zoom}, {zoom})\n')
