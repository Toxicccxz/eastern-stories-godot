extends RefCounted

## Shared visual exit direction for both the floating marker and ground beyond it.
static func direction(command: String) -> Vector2:
	var directions: Dictionary = {
		"north":Vector2.UP,"northup":Vector2.UP,"northdown":Vector2.UP,
		"south":Vector2.DOWN,"southup":Vector2.DOWN,"southdown":Vector2.DOWN,
		"east":Vector2.RIGHT,"west":Vector2.LEFT,
		"northeast":Vector2(1,-1),"northwest":Vector2(-1,-1),
		"southeast":Vector2(1,1),"southwest":Vector2(-1,1)}
	return (directions.get(command,Vector2.ZERO) as Vector2).normalized()

## Stairs and room verbs have no compass direction. Use their physical approach.
static func for_passage(map: WorldMapController, passage: WorldPassageArea2D, portal: PortalDefinition) -> Vector2:
	var toward: Vector2 = direction(portal.legacy_command)
	if toward != Vector2.ZERO:
		return toward
	var nearest: float = INF
	for reverse: PortalDefinition in GameContent.catalog().portals_for_map(portal.destination_map_id):
		if reverse.destination_zone_id != portal.source_zone_id or reverse.source_zone_id != portal.destination_zone_id:
			continue
		var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(reverse.destination_spawn_point_id)
		if marker != null:
			var approach: Vector2 = passage.global_position-marker.global_position
			if approach.length_squared()>1 and approach.length_squared()<nearest:
				nearest = approach.length_squared()
				toward = approach.normalized()
	if toward == Vector2.ZERO:
		var zone: WorldPhysicalZoneArea2D = map.physical_zone(portal.source_zone_id)
		if zone != null:
			toward = (passage.global_position-zone.global_rect().get_center()).normalized()
	return toward

static func make(parent: Node3D, toward: Vector2) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for p: Vector3 in [Vector3(0,0,0.47),Vector3(-0.31,0,-0.25),Vector3(0.31,0,-0.25)]:
		surface.add_vertex(p)
	var marker := MeshInstance3D.new()
	marker.name = "ExitArrow"
	marker.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("ffe3a1")
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.rotation.y = atan2(toward.x,toward.y)
	parent.add_child(marker)
	return marker
