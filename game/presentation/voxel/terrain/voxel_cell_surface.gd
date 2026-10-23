class_name VoxelCellSurface
extends RefCounted

## One occupied cell, one colour. Emit only union boundary faces: intersecting
## crowns cannot leave two differently coloured surfaces at the same depth.
var cells: Dictionary[Vector3i, Color] = {}
var cell_size: float = 0.28
var face_count: int = 0
const DIRECTIONS: Array[Vector3i] = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]

func ellipsoid(center: Vector3, radius: Vector3, palette: Array[String], seed_value: int) -> void:
	var first := Vector3i((center-radius)/cell_size)-Vector3i.ONE
	var last := Vector3i((center+radius)/cell_size)+Vector3i.ONE
	for y: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			for z: int in range(first.z,last.z+1):
				var cell := Vector3i(x,y,z)
				var relative: Vector3 = (Vector3(cell)*cell_size-center)/radius
				var variation: int = absi(x*73+y*31+z*53+seed_value*17)%13
				if relative.length_squared()>0.90+variation*0.012:
					continue
				var shade: int = clampi(floori((relative.y+1.0)*1.15)+int(relative.x< -0.25)+int(variation==2),0,palette.size()-1)
				cells[cell] = Color(palette[shade])

func mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	face_count = 0
	for cell: Vector3i in cells:
		for direction: Vector3i in DIRECTIONS:
			if cells.has(cell+direction):
				continue
			var normal := Vector3(direction)
			var tangent: Vector3 = Vector3.RIGHT if direction.y!=0 else Vector3.UP
			var across: Vector3 = normal.cross(tangent)
			var center: Vector3 = (Vector3(cell)+normal*0.5)*cell_size
			var corners: Array[Vector3] = [center+(-tangent-across)*cell_size*0.5,center+(tangent-across)*cell_size*0.5,center+(tangent+across)*cell_size*0.5,center+(-tangent+across)*cell_size*0.5]
			surface.set_color(cells[cell].srgb_to_linear())
			surface.set_normal(normal)
			for index: int in [0,2,1,0,3,2]:
				surface.add_vertex(corners[index])
			face_count += 1
	return surface.commit()
