extends RefCounted

func run_all(_tree: SceneTree) -> Dictionary:
	var failures: Array[String] = []
	var union := VoxelCellSurface.new()
	union.cells[Vector3i.ZERO] = Color.RED
	union.cells[Vector3i.RIGHT] = Color.GREEN
	var mesh: ArrayMesh = union.mesh()
	if union.face_count!=10:
		failures.append("adjacent differently coloured leaves must not retain their shared faces")
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var correct_winding: bool = true
	for i: int in range(0,vertices.size(),3):
		correct_winding = correct_winding and (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).dot(normals[i])>0
	if not correct_winding:
		failures.append("union faces must face outward for opaque and shadow rendering")
	var canopy := VoxelCellSurface.new()
	canopy.ellipsoid(Vector3(0,2,0),Vector3.ONE,["54885a","8aaa68"],71)
	canopy.mesh()
	var original_faces: int = canopy.face_count
	canopy.ellipsoid(Vector3(0,2,0),Vector3.ONE,["cf8bab","eeb3c7"],71)
	canopy.mesh()
	if canopy.face_count!=original_faces:
		failures.append("overlapping crowns must overwrite occupancy instead of duplicating coplanar surfaces")
	var land := VoxelLandmass.new()
	var source: Dictionary[Vector2i,String] = {
		Vector2i(-24,-24):"grass",Vector2i(8,8):"street",
		Vector2i(800,800):"boundary",Vector2i(8,984):"path"}
	var required: Array[Rect2] = [Rect2(-128,-64,96,64)]
	land.build(source,required,{})
	var terrain: Dictionary[Vector2i,String] = land.terrain(source)
	if terrain.get(Vector2i(-24,-24))!="grass" or terrain.get(Vector2i(8,984))!="path" or not land.supports(Vector2(-80,-32),20):
		failures.append("authored terrain and building footprints stay supported, including negative coordinates")
	if land.contains(Vector2(8,480)) or land.contains(Vector2(800,800)) or terrain.has(Vector2i(800,800)):
		failures.append("unrelated scenery cannot fill the entire bounds between distant map sections")
	var finite: bool = true
	for cell: Vector2i in land.patches:
		var center: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*32
		finite = finite and (Rect2(-272,-208,448,384).has_point(center) or Rect2(-128,832,288,288).has_point(center))
	if not finite:
		failures.append("the scenery extension must stay within its bounded shoulder")
	var holder := Node3D.new()
	land.make_base(holder)
	var base := holder.get_child(0) as MeshInstance3D
	var base_arrays: Array = base.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = base_arrays[Mesh.ARRAY_VERTEX]
	var base_normals: PackedVector3Array = base_arrays[Mesh.ARRAY_NORMAL]
	var edges: Dictionary[String,int] = {}
	var base_winding: bool = true
	for i: int in range(0,positions.size(),3):
		base_winding = base_winding and (positions[i+2]-positions[i]).cross(positions[i+1]-positions[i]).dot(base_normals[i])>0
		for j: int in 3:
			var a: String = str(positions[i+j])
			var b: String = str(positions[i+(j+1)%3])
			var key: String = a+"/"+b if a<b else b+"/"+a
			edges[key] = edges.get(key,0)+1
	var closed: bool = true
	for count: int in edges.values():
		closed = closed and count==2
	if not closed or not base_winding:
		failures.append("the irregular soil base must be closed and face outward, including its stepped corners")
	holder.free()
	return {"assertions":7,"failures":failures}
