extends RefCounted

## DECISIONS「清水见底」「尸体的样子」: every water has a bed under it, stepping down from the bank;
## its fish keep inside the water and above its bed and never swim backwards; a fight's backdrop
## shuts the water while it is up; what lies where someone died is a body, then rot, then bones,
## never a box.
var assertions: int = 0
var failures: Array[String] = []

const Ambience = preload("res://presentation/voxel/voxel_ambience.gd")
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const Remains = preload("res://presentation/voxel/actors/voxel_remains.gd")
const OPAQUE = preload("res://presentation/voxel/shaders/water_opaque.gdshader")


func run_all(tree: SceneTree) -> Dictionary:
	var pond: Dictionary = await _pond(tree)
	_test_bed(pond)
	_test_fish(pond)
	_test_backdrop_shuts_the_water(pond)
	(pond["holder"] as Node).queue_free()
	_test_remains(tree)
	return {"assertions": assertions, "failures": failures}


## A pond of 40 × 24 cells of `water` ringed by grass, built as a map would build it.
func _pond(tree: SceneTree) -> Dictionary:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var ambience: VoxelAmbience = Ambience.new()
	holder.add_child(ambience)
	var cells: Dictionary[Vector2i, String] = {}
	for y: int in range(-2, 26):
		for x: int in range(-2, 42):
			var inside: bool = x >= 0 and x < 40 and y >= 0 and y < 24
			cells[Vector2i(x*16+8, y*16+8)] = "water" if inside else "grass"
	var water := VoxelWater.new({"kinds": {"water": {"life": {"fish": {"kind": "carp", "per": 40, "max": 12}}}}})
	water.collect(cells)
	var shapes := Shapes.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	await water.build(holder, cells, null, shapes, rng, Callable(), ambience)
	shapes.flush()
	return {"holder": holder, "water": water, "ambience": ambience, "cells": cells}


func _test_bed(pond: Dictionary) -> void:
	var water: VoxelWater = pond["water"]
	var below: bool = true
	var deepest: float = 0.0
	for cell: Vector2i in water.levels:
		below = below and water.beds.has(cell) and water.beds[cell] < water.levels[cell]-0.15
		deepest = maxf(deepest, water.levels[cell]-water.beds[cell])
	_check(below, "every water cell has a bed under it")
	var edge: Vector2i = Vector2i(8, 200)
	var middle: Vector2i = Vector2i(19*16+8, 11*16+8)
	_check(water.levels[edge]-water.beds[edge] < water.levels[middle]-water.beds[middle], "the bed steps down from the bank toward the middle")
	_check(deepest <= float(VoxelWater.BED_DEPTH["water"])+0.05, "no deeper than the kind's bed_depth (%.2f)" % deepest)
	_check(water.banked.size() > 0, "banks down to the bed")


func _test_fish(pond: Dictionary) -> void:
	var water: VoxelWater = pond["water"]
	var ambience: VoxelAmbience = pond["ambience"]
	var swimmers: Array[Dictionary] = ambience._swimmers
	_check(swimmers.size() >= 4, "fish swim in the pond (%d)" % swimmers.size())
	var inside: bool = true
	var above_bed: bool = true
	var closest: float = INF
	var forward: bool = true
	for fish: Dictionary in swimmers:
		var rate: float = float(fish["rate"])
		var wobble: float = 0.35*minf(1.0, absf(rate)/0.16)*0.41
		forward = forward and wobble < absf(rate)
	for step: int in 120:
		ambience.clock = step*0.5
		ambience.advance(0.0)
		for fish: Dictionary in swimmers:
			var at: Vector3 = (fish["node"] as Node3D).position
			var cell := Vector2i(floori(at.x*32.0/16.0)*16+8, floori(at.z*32.0/16.0)*16+8)
			inside = inside and water.levels.has(cell)
			if water.beds.has(cell):
				closest = minf(closest, at.y-water.beds[cell])
				above_bed = above_bed and at.y > water.beds[cell]+0.08
	_check(inside, "over a minute the fish never leave the water")
	_check(above_bed, "nor go under its bed (closest %.3f over it)" % closest)
	_check(forward, "and their speed only swells and ebbs, never turning them back")


func _test_backdrop_shuts_the_water(pond: Dictionary) -> void:
	var water: VoxelWater = pond["water"]
	var surfaces: Array = water._surfaces.keys()
	var backdrop := VoxelBackdrop.new()
	backdrop.water = water
	(pond["holder"] as Node3D).add_child(backdrop)
	backdrop.amount = 0.5
	var shut: bool = true
	for surface: MeshInstance3D in surfaces:
		shut = shut and ((surface.material_override as ShaderMaterial).shader == OPAQUE)
	_check(not surfaces.is_empty() and shut, "the backdrop up: the water is shut (the backdrop's copy of the screen holds it)")
	backdrop.amount = 0.0
	var open: bool = true
	for surface: MeshInstance3D in surfaces:
		open = open and ((surface.material_override as ShaderMaterial).shader != OPAQUE)
	_check(open, "the backdrop gone: the water is clear again")
	backdrop.amount = 0.5
	backdrop.queue_free()
	(pond["holder"] as Node3D).remove_child(backdrop)
	var reopened: bool = true
	for surface: MeshInstance3D in surfaces:
		reopened = reopened and ((surface.material_override as ShaderMaterial).shader != OPAQUE)
	_check(reopened, "a backdrop taken away while up leaves the water clear")


func _test_remains(tree: SceneTree) -> void:
	var looks: Dictionary = {
		"person": {"coat": "7a5a3a", "pants": "344047"},
		"beast": {"animal": true, "fur": ["a88a60", "846747", "725638"], "tail": true},
		"snake": {"body": "snake"},
		"crawler": {"body": "crawler"},
		"flyer": {"body": "flyer"},
	}
	for name: String in looks:
		for stage: int in [CorpseState.Stage.FRESH, CorpseState.Stage.ROTTEN, CorpseState.Stage.SKELETON]:
			var node := Node3D.new()
			tree.root.add_child(node)
			Remains.build(node, looks[name], stage, NAN, 11)
			var drawn: int = _meshes(node)
			# A flying thing leaves only its two wings.
			_check(drawn > (1 if name == "flyer" and stage == CorpseState.Stage.SKELETON else 2), "%s at stage %d: drawn as more than a box (%d parts)" % [name, stage, drawn])
			if name == "person":
				_check(node.has_node("Body") == (stage == CorpseState.Stage.FRESH), "person at stage %d: a dressed body only while fresh" % stage)
			node.queue_free()


func _meshes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.find_children("*", "GeometryInstance3D", true, false):
		if child is MultiMeshInstance3D:
			count += (child as MultiMeshInstance3D).multimesh.instance_count
		else:
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
