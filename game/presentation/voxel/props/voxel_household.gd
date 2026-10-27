extends RefCounted

## Household goods that make a room look lived in (game/data/common/room_life.json): heaps and
## stacks stood against a wall (blocked boxes the map painter places), things hung on walls,
## what is left on a table and small litter on the floor. Wall things stand on the wall's face
## with +z into the room; `seed` varies a piece without changing where it stands.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var data: Dictionary
var rng := RandomNumberGenerator.new()
## Lamp flames that flicker (null where nothing moves).
var ambience: VoxelAmbience

const WALL_KINDS: Array[String] = ["tool_hooks","string_hang","ledger_hook","new_year_print","couplet","clothes_peg",
	"straw_cape","calendar","wall_lamp","wall_shelf","weapon_pegs","menu_boards","notices","banner_cloth","plaques","mural",
	"meat_hooks","double_happiness","animal_hide"]

func draw(shapes: Shapes, parent: Node3D, look: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	data = look
	rng.seed = hash(int(look.get("seed",0)))
	match String(look["kind"]):
		"sacks": _sacks(w,d)
		"baskets": _baskets(w,d)
		"rope_coil": _rope_coil(w,d)
		"crocks": _crocks(w,d)
		"bedding": _bedding(w,d)
		"chest_stack": _chest_stack(w,d)
		"old_furniture": _old_furniture(w,d)
		"iron_goods": _iron_goods(w,d)
		"coal_heap": _coal_heap(w,d)
		"lumber": _lumber(w,d)
		"prayer_cushions": _prayer_cushions(w,d)
		"tool_hooks": _tool_hooks(w)
		"string_hang": _string_hang()
		"ledger_hook": _ledger_hook()
		"new_year_print": _new_year_print()
		"couplet": _couplet()
		"clothes_peg": _clothes_peg()
		"straw_cape": _straw_cape()
		"calendar": _calendar()
		"wall_lamp": _wall_lamp()
		"wall_shelf": _wall_shelf(w)
		"weapon_pegs": _weapon_pegs(w)
		"menu_boards": _boards(w,["e8dcc0","d9cba6","e8dcc0","c9b48a"],"3a3530")
		"notices": _boards(w,["e3d6b0","d6c48f","efe6cc"],"55504a",true)
		"banner_cloth": _banner_cloth()
		"plaques": _plaques(w)
		"mural": _mural(w)
		"stone_slabs": _stone_slabs(w,d)
		"cloth_bolts": _cloth_bolts(w,d)
		"whetstone": _whetstone(w,d)
		"paper_money": _paper_money(w,d)
		"meat_hooks": _meat_hooks(w)
		"double_happiness": _double_happiness()
		"animal_hide": _animal_hide()
		_:
			return false
	return true

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

func _jitter(amount: float) -> float:
	return rng.randf_range(-amount,amount)

# --- Heaps and stacks against a wall (their back, -z, to the wall) ------------------------------

## 麻袋: sacks of grain or charcoal, two or three on the floor and one slumped on top, tied at
## the neck, some patched.
func _sacks(w: float, d: float) -> void:
	var cloth: String = String(data.get("cloth","a8946a"))
	var shades: Array = [cloth,Color(cloth).darkened(0.12).to_html(false),Color(cloth).lightened(0.08).to_html(false)]
	var count: int = maxi(1,floori(w/0.62))
	for i: int in count:
		var at := Vector3(-w/2+(i+0.5)*w/count+_jitter(0.05),0,_jitter(d*0.1))
		var h: float = rng.randf_range(0.55,0.75)
		s.shard(root,at+Vector3(0,h/2,0),Vector3(w/count*0.92,h,d*0.78),_pick(shades),rng.randi(),_jitter(0.3))
		s.box(root,at+Vector3(0,h+0.05,0),Vector3(0.16,0.1,0.14),"79684a")
		if rng.randf()<0.4:
			s.box(root,at+Vector3(_jitter(0.1),h*0.5,d*0.39),Vector3(0.18,0.16,0.01),"7d6e4c")
	if count>1:
		s.tilted_box(root,Vector3(_jitter(0.15),0.95,-d*0.05),Vector3(w*0.55,0.36,d*0.62),_pick(shades),Vector3(0,_jitter(0.3),0.18))
	if rng.randf()<0.5:
		for grain: int in 6:
			s.box(root,Vector3(_jitter(w*0.45),0.012,d*0.48+rng.randf()*0.15),Vector3(0.05,0.012,0.04),"d8c48e")

## 竹筐: bamboo baskets stacked and one tipped, with what they hold (`sewing`: thread and cloth).
func _baskets(w: float, d: float) -> void:
	var cane: Array = ["a68a55","b39a62","98804e"]
	var size: float = minf(w,d)*0.62
	s.box(root,Vector3(-w*0.12,size*0.42,0),Vector3(size,size*0.84,size),_pick(cane))
	s.box(root,Vector3(-w*0.12,size*0.86,0),Vector3(size*1.04,0.05,size*1.04),"8a7044")
	s.box(root,Vector3(-w*0.12,size*1.1,0),Vector3(size*0.85,size*0.5,size*0.85),_pick(cane))
	var tipped := Node3D.new()
	tipped.position = Vector3(w*0.26,size*0.3,d*0.12)
	tipped.rotation = Vector3(0,_jitter(0.6),1.2)
	root.add_child(tipped)
	s.box(tipped,Vector3.ZERO,Vector3(size*0.7,size*0.55,size*0.7),_pick(cane))
	if data.get("sewing",false):
		for spool: int in 3:
			s.box(root,Vector3(-w*0.12+(spool-1)*0.1,size*1.38,0),Vector3(0.08,0.1,0.08),["b23a2b","4a6f8f","d6b862"][spool])
		s.box(root,Vector3(-w*0.12,size*1.36,0.08),Vector3(size*0.6,0.04,0.2),"c9b98e")
	else:
		s.box(root,Vector3(-w*0.12,size*1.36,0),Vector3(size*0.7,0.06,size*0.7),_pick(["c9b98e","6f9a4e","d28a3a","b8a374"]))

## 坛罐: big and small clay crocks, one with a cloth over its mouth (`scrolls`: a tall vase of
## rolled paintings, as a study keeps them).
func _crocks(w: float, d: float) -> void:
	var clay: Array = ["6b4a35","7b5a3e","5d6b60","8b5440","9a8466"]
	if data.get("scrolls",false):
		s.box(root,Vector3(0,0.42,-d*0.08),Vector3(0.46,0.84,0.46),_pick(["5d7f78","9a8466","4f6a73"]))
		s.box(root,Vector3(0,0.86,-d*0.08),Vector3(0.34,0.06,0.34),"3c3a33")
		for roll: int in 5:
			s.tilted_box(root,Vector3(_jitter(0.1),1.05,-d*0.08+_jitter(0.1)),Vector3(0.07,0.6,0.07),_pick(["d9cfb0","c8b48a","b29c75"]),Vector3(_jitter(0.25),0,_jitter(0.25)))
		return
	var big: float = minf(w,d)*0.72
	s.box(root,Vector3(-w*0.15,big*0.45,-d*0.05),Vector3(big,big*0.82,big),_pick(clay))
	s.box(root,Vector3(-w*0.15,big*0.12,-d*0.05),Vector3(big*0.78,big*0.24,big*0.78),_pick(clay))
	s.box(root,Vector3(-w*0.15,big*0.9,-d*0.05),Vector3(big*0.6,0.08,big*0.6),"4a3a2c")
	if rng.randf()<0.6:
		s.box(root,Vector3(-w*0.15,big*0.96,-d*0.05),Vector3(big*0.72,0.04,big*0.72),_pick(["b23a2b","c9b98e","6b5a4a"]))
	s.box(root,Vector3(w*0.28,0.18,d*0.18),Vector3(0.3,0.34,0.3),_pick(clay))
	s.box(root,Vector3(w*0.28,0.37,d*0.18),Vector3(0.18,0.05,0.18),"4a3a2c")

## 铺盖: bedding rolled and tied, a spare quilt folded on top.
func _bedding(w: float, d: float) -> void:
	for i: int in 2:
		s.box(root,Vector3(0,0.16+i*0.3,_jitter(0.05)),Vector3(w*0.88,0.3,d*0.6),_pick(["6f8f86","8a6a5a","b8a374","5a6e86"]))
		for x: float in [-w*0.25,w*0.25]:
			s.box(root,Vector3(x,0.16+i*0.3,0),Vector3(0.05,0.32,d*0.62),"6a5a40")

## 箱笼: a big chest with a smaller one and a bundle on it, brass corners.
func _chest_stack(w: float, d: float) -> void:
	var wood: Array = ["7a573c","6a4a34","8d6744","5c3f2b"]
	var low: String = _pick(wood)
	s.box(root,Vector3(0,0.3,0),Vector3(w*0.92,0.6,d*0.82),low)
	s.box(root,Vector3(0,0.62,0),Vector3(w*0.95,0.06,d*0.85),Color(low).lightened(0.1).to_html(false))
	s.box(root,Vector3(0,0.42,d*0.42),Vector3(0.12,0.14,0.03),"c2a666")
	var top: String = _pick(wood)
	s.box(root,Vector3(_jitter(0.1),0.85,-d*0.05),Vector3(w*0.6,0.42,d*0.6),top)
	s.box(root,Vector3(0,0.9,d*0.26),Vector3(0.1,0.1,0.03),"c2a666")
	if rng.randf()<0.6:
		s.shard(root,Vector3(_jitter(0.12),1.15,0),Vector3(0.36,0.2,0.3),_pick(["6b5a4a","4a6f8f","8a3a3a","a08a5a"]),rng.randi())

## 旧家具: a broken stool on its side, a chair with a split back, a cracked basin, dust.
func _old_furniture(w: float, d: float) -> void:
	var wood: String = _pick(["6e5a42","7a6248","5f4c38"])
	var stool := Node3D.new()
	stool.position = Vector3(-w*0.15,0.25,0)
	stool.rotation = Vector3(0,_jitter(0.5),PI/2)
	root.add_child(stool)
	s.box(stool,Vector3(0,0.22,0),Vector3(0.44,0.08,0.44),wood)
	for x: float in [-0.15,0.15]:
		s.box(stool,Vector3(x,0,0.15),Vector3(0.07,0.42,0.07),wood)
	s.box(stool,Vector3(-0.15,-0.06,-0.15),Vector3(0.07,0.3,0.07),wood)
	s.box(root,Vector3(w*0.22,0.5,-d*0.2),Vector3(0.42,1.0,0.07),wood)
	s.tilted_box(root,Vector3(w*0.22,1.0,-d*0.18),Vector3(0.2,0.3,0.05),wood,Vector3(0,0,0.5))
	s.box(root,Vector3(w*0.22,0.06,d*0.15),Vector3(0.36,0.1,0.36),"8a8270")
	s.box(root,Vector3(w*0.22,0.1,d*0.15),Vector3(0.26,0.02,0.26),"4a443a")

## 铁器: hoes, spades and hammers leant on the wall, half-made heads on the floor
## (`heap`: "heads" a low heap of heads only, "pots" iron pots and pans, "blades" blanks and choppers).
func _iron_goods(w: float, d: float) -> void:
	var iron: Array = ["4e5657","5d6667","6f7879","3f4647"]
	var handle: Array = ["a58456","8f6f45","b29462"]
	match String(data.get("heap","tools")):
		"pots":
			for i: int in 3:
				var at := Vector3(_jitter(w*0.25),0.14+i*0.2,_jitter(d*0.15))
				s.box(root,at,Vector3(0.5-i*0.08,0.2,0.5-i*0.08),_pick(iron))
				s.box(root,at+Vector3(0,0.09,0),Vector3(0.38-i*0.08,0.02,0.38-i*0.08),"2a2e2f")
			s.tilted_box(root,Vector3(w*0.3,0.3,-d*0.3),Vector3(0.45,0.45,0.04),_pick(iron),Vector3(0.3,0,0))
		"heads":
			# Finished and half-made heads in a low heap: hoe blades, hammer heads, spade plates.
			for i: int in 10:
				var at := Vector3(_jitter(w*0.38),0.04+(i%3)*0.06,_jitter(d*0.32))
				var size: Vector3 = [Vector3(0.26,0.06,0.2),Vector3(0.16,0.12,0.12),Vector3(0.22,0.04,0.28)][i%3]
				s.tilted_box(root,at,size,_pick(iron),Vector3(_jitter(0.2),rng.randf()*TAU,_jitter(0.2)))
			s.tilted_box(root,Vector3(_jitter(w*0.2),0.2,0),Vector3(0.05,0.05,0.7),_pick(handle),Vector3(0,rng.randf()*TAU,0.15))
		"blades":
			for i: int in 5:
				s.tilted_box(root,Vector3(-w*0.4+i*w*0.2,0.45,-d*0.32),Vector3(0.1,0.8,0.03),"8f9a9b",Vector3(0.2,0,_jitter(0.12)))
				s.box(root,Vector3(-w*0.4+i*w*0.2,0.08,-d*0.2),Vector3(0.12,0.16,0.08),_pick(handle))
			for i: int in 4:
				s.box(root,Vector3(_jitter(w*0.35),0.03+i*0.035,d*0.12+_jitter(0.08)),Vector3(0.5,0.03,0.12),_pick(iron))
		_:
			for i: int in maxi(3,floori(w/0.3)):
				var x: float = -w*0.42+i*w*0.84/maxf(1,maxi(3,floori(w/0.3))-1)
				s.tilted_box(root,Vector3(x,0.62,-d*0.3),Vector3(0.06,1.2,0.06),_pick(handle),Vector3(0.22,0,_jitter(0.1)))
				var head: int = rng.randi_range(0,2)
				var size: Vector3 = [Vector3(0.24,0.08,0.18),Vector3(0.2,0.3,0.04),Vector3(0.16,0.14,0.14)][head]
				s.box(root,Vector3(x,1.2,-d*0.42),size,_pick(iron))
			for i: int in 4:
				s.box(root,Vector3(_jitter(w*0.38),0.05+(i%2)*0.07,d*0.15+_jitter(0.1)),Vector3(0.22,0.07,0.16),_pick(iron))
			s.box(root,Vector3(_jitter(w*0.2),0.04,d*0.3),Vector3(0.6,0.05,0.07),"6f7879")

## 煤堆: a heap of coal against the wall, a shovel stuck in it, dust round its foot.
func _coal_heap(w: float, d: float) -> void:
	for i: int in 9:
		var r: float = 1.0-i/9.0
		s.shard(root,Vector3(_jitter(w*0.35*r),0.08+i*0.07,_jitter(d*0.3*r)-d*0.05),Vector3(w*0.5*r+0.18,0.18,d*0.45*r+0.15),_pick(["2a2826","34312d","1f1e1c"]),rng.randi(),rng.randf()*TAU)
	s.tilted_box(root,Vector3(w*0.18,0.7,0),Vector3(0.05,1.0,0.05),"8f6f45",Vector3(0.1,0,0.5))
	s.tilted_box(root,Vector3(w*0.02,0.32,0),Vector3(0.22,0.04,0.26),"4e5657",Vector3(0,0,0.5))
	s.box(root,Vector3(0,0.006,d*0.35),Vector3(w*0.9,0.012,d*0.4),"3a3631")

## 石板: slabs a mason has cut, stacked flat in neat piles of a few, or (`lean`) stood on edge in
## a row against the wall, sizes and greys a little different, chips at their foot.
func _stone_slabs(w: float, d: float) -> void:
	var stones: Array = data.get("colors",["8f9084","9b9b8e","85877b","a3a294"])
	if data.get("lean",false):
		for slab: int in maxi(3,floori(w/0.16)):
			var x: float = -w/2+0.1+slab*0.16
			var tall: float = rng.randf_range(0.8,1.3)
			s.tilted_box(root,Vector3(x,tall/2,-d*0.15),Vector3(0.07,tall,minf(d*0.7,0.9)),_pick(stones),Vector3(-0.18,0,0))
	else:
		for pile: int in maxi(1,floori(w/0.75)):
			var x: float = -w/2+(pile+0.5)*w/maxi(1,floori(w/0.75))
			for layer: int in rng.randi_range(3,6):
				s.box(root,Vector3(x+_jitter(0.03),0.05+layer*0.085,_jitter(0.03)),Vector3(minf(0.68,w*0.9),0.075,d*0.78),_pick(stones))
	for chip: int in 4:
		s.box(root,Vector3(_jitter(w*0.45),0.01,d*0.4+_jitter(0.05)),Vector3(0.07,0.02,0.05),_pick(stones))

## 木料: planks and poles leant on the wall (`staves`: a bundle of practice staves).
func _lumber(w: float, d: float) -> void:
	var wood: Array = ["a3845d","8c6e4c","b2946a","7a5f43"]
	var count: int = maxi(3,floori(w/0.22))
	for i: int in count:
		var x: float = -w*0.42+i*w*0.84/maxf(1,count-1)
		var length: float = rng.randf_range(1.6,2.4)
		if data.get("staves",false):
			s.tilted_box(root,Vector3(x,length/2,-d*0.3),Vector3(0.06,length,0.06),_pick(["a58456","8f6f45"]),Vector3(0.16,0,_jitter(0.08)))
		else:
			s.tilted_box(root,Vector3(x,length/2,-d*0.28),Vector3(0.2,length,0.05),_pick(wood),Vector3(0.18,0,_jitter(0.06)))
	s.box(root,Vector3(0,0.006,d*0.2),Vector3(w*0.7,0.012,d*0.4),"c9ad7c")

## 布卷 (a 布庄's stock): bolts of cloth stacked in a pyramid against the wall, one unrolled a
## little on top (`colors` the cloths).
func _cloth_bolts(w: float, d: float) -> void:
	var cloths: Array = data.get("colors",["3d5a7a","8a3a3a","c9b98e","4a6f4a","7a5a8c","b8864a","e8e0cc","5a6e86"])
	var length: float = d*0.9
	var rows: int = 3 if w>=1.4 else 2
	for row: int in rows:
		var across: int = maxi(1,floori((w-row*0.22)/0.24))
		for i: int in across:
			var x: float = -(across-1)*0.12+i*0.24+_jitter(0.015)
			s.tilted_box(root,Vector3(x,0.12+row*0.2,_jitter(0.03)),Vector3(0.2,0.2,length),_pick(cloths),Vector3(0,0,_jitter(0.05)))
	# One bolt pulled out and left unrolled a little, its tail on the floor in front.
	var loose: String = _pick(cloths)
	s.tilted_box(root,Vector3(_jitter(w*0.2),0.12+rows*0.2,-d*0.1),Vector3(0.2,0.2,length*0.8),loose,Vector3(0,_jitter(0.2),0))
	s.box(root,Vector3(_jitter(w*0.2),0.015,d*0.5+0.1),Vector3(0.22,0.03,0.3),loose)

## 磨石 (a 兵器局's): a grey whetstone on a low trestle, a bucket of water beside it, a blade
## left lying across the stone and the wet dark patch under it.
func _whetstone(w: float, d: float) -> void:
	s.box(root,Vector3(-w*0.12,0.18,0),Vector3(0.6,0.08,0.3),"6a5039")
	for x: float in [-w*0.12-0.24,-w*0.12+0.24]:
		for z: float in [-0.1,0.1]:
			s.box(root,Vector3(x,0.07,z),Vector3(0.06,0.14,0.06),"6a5039")
	s.box(root,Vector3(-w*0.12,0.3,0),Vector3(0.5,0.16,0.2),_pick(["7d7f78","8a8c85","6f716a"]))
	s.box(root,Vector3(-w*0.12,0.39,0),Vector3(0.4,0.02,0.14),"5f615b")
	s.tilted_box(root,Vector3(-w*0.12+0.05,0.42,0.02),Vector3(0.7,0.025,0.08),"c6cfcb",Vector3(0,_jitter(0.3),0))
	s.box(root,Vector3(w*0.3,0.16,d*0.1),Vector3(0.28,0.32,0.28),"8a6a45")
	s.box(root,Vector3(w*0.3,0.31,d*0.1),Vector3(0.22,0.02,0.22),"3e5f63:gloss")
	s.box(root,Vector3(-w*0.1,0.008,0.05),Vector3(0.7,0.012,0.5),"4e4a44")
	for fleck: int in 5:
		s.box(root,Vector3(_jitter(w*0.4),0.015,_jitter(d*0.4)),Vector3(0.05,0.012,0.04),"8f9a9b")

## 纸钱 (a 棺材铺's): stacks of yellow and white joss paper, round holes stamped through them,
## a bundle tied with hemp and a few loose sheets on the floor.
func _paper_money(w: float, d: float) -> void:
	var papers: Array = ["e6d27a","efe6c8","d8c45a","f0ebd8"]
	var stacks: int = maxi(1,floori(w/0.42))
	for i: int in stacks:
		var x: float = -(stacks-1)*0.21+i*0.42
		var tall: float = rng.randf_range(0.2,0.45)
		var tone: String = _pick(papers)
		s.tilted_box(root,Vector3(x,tall/2,_jitter(0.04)),Vector3(0.34,tall,0.26),tone,Vector3(0,_jitter(0.15),0))
		s.box(root,Vector3(x,tall+0.004,0),Vector3(0.3,0.008,0.22),Color(tone).darkened(0.08).to_html(false))
		for hole: int in 3:
			s.box(root,Vector3(x-0.08+hole*0.08,tall+0.006,0),Vector3(0.04,0.008,0.04),"5a4a34")
		if i%2==1:
			s.box(root,Vector3(x,tall*0.5,0),Vector3(0.36,0.03,0.28),"8a7a52")
	for sheet: int in 3:
		s.tilted_box(root,Vector3(_jitter(w*0.4),0.006+sheet*0.003,d*0.4+_jitter(0.1)),Vector3(0.16,0.006,0.12),_pick(papers),Vector3(0,rng.randf()*TAU,0))

## 蒲团: worn cushions stacked by the wall, one set down before it.
func _prayer_cushions(w: float, d: float) -> void:
	for i: int in 3:
		var at := Vector3(-w*0.2,0.06+i*0.12,_jitter(0.04)) if i<2 else Vector3(w*0.24,0.06,d*0.1)
		var size: float = minf(w,d)*0.7
		s.box(root,at,Vector3(size,0.12,size*0.92),_pick(["8f7a4c","a28b58","7a6a44"]))
		s.box(root,at+Vector3(0,0.065,0),Vector3(size*0.6,0.02,size*0.55),"6e5d3a")

# --- On walls -----------------------------------------------------------------------------------

## Pegs on a board with tools hung from them (`tools`: hammers and tongs, horseshoes, sickles).
func _tool_hooks(w: float) -> void:
	var width: float = minf(w,1.6)
	s.box(root,Vector3(0,1.9,0.03),Vector3(width,0.12,0.05),"6a5039")
	var kind: String = String(data.get("tools","hammers"))
	for i: int in maxi(3,floori(width/0.3)):
		var x: float = -width*0.4+i*width*0.8/maxf(1,maxi(3,floori(width/0.3))-1)
		s.box(root,Vector3(x,1.9,0.09),Vector3(0.04,0.04,0.08),"3a3530")
		match kind:
			"horseshoes":
				s.box(root,Vector3(x,1.72,0.09),Vector3(0.18,0.04,0.03),"5d6667")
				for side: float in [-0.08,0.08]:
					s.box(root,Vector3(x+side,1.66,0.09),Vector3(0.04,0.16,0.03),"5d6667")
			"sickles":
				s.box(root,Vector3(x,1.66,0.09),Vector3(0.05,0.42,0.04),"8f6f45")
				s.tilted_box(root,Vector3(x+0.1,1.88,0.09),Vector3(0.28,0.04,0.02),"8f9a9b",Vector3(0,0,-0.6))
			"chisels":
				# A mason's: chisels, a point and a mallet on alternate pegs.
				if i%3==2:
					s.box(root,Vector3(x,1.7,0.1),Vector3(0.05,0.34,0.05),"a58456")
					s.box(root,Vector3(x,1.52,0.1),Vector3(0.2,0.14,0.14),"8a6a45")
				else:
					s.box(root,Vector3(x,1.68,0.1),Vector3(0.04,0.4,0.04),"6f7879")
					s.box(root,Vector3(x,1.47,0.1),Vector3(0.06,0.04,0.03),"9aa3a4")
			"cleavers":
				# A butcher's: broad cleavers and a bone saw, their edges dark with use.
				if i%3==2:
					s.box(root,Vector3(x,1.66,0.09),Vector3(0.05,0.4,0.03),"8a6a45")
					s.box(root,Vector3(x+0.08,1.4,0.09),Vector3(0.24,0.08,0.02),"8f9a9b")
				else:
					s.box(root,Vector3(x,1.72,0.09),Vector3(0.05,0.28,0.04),"6b4a35")
					s.box(root,Vector3(x,1.42,0.09),Vector3(0.2,0.34,0.025),_pick(["8f9a9b","7d8889"]))
					s.box(root,Vector3(x,1.26,0.1),Vector3(0.2,0.03,0.02),"5a3a30")
			"axes":
				# A woodshed's: felling axes and a hatchet, a billhook between.
				s.box(root,Vector3(x,1.6,0.09),Vector3(0.05,0.56,0.05),"8f6f45")
				if i%2==0:
					s.box(root,Vector3(x+0.07,1.84,0.09),Vector3(0.22,0.14,0.04),"4e5657")
					s.box(root,Vector3(x+0.17,1.84,0.09),Vector3(0.03,0.16,0.045),"9aa3a4")
				else:
					s.tilted_box(root,Vector3(x+0.08,1.86,0.09),Vector3(0.26,0.05,0.03),"6f7879",Vector3(0,0,0.5))
			_:
				var handle: float = rng.randf_range(0.4,0.6)
				s.box(root,Vector3(x,1.88-handle/2,0.1),Vector3(0.05,handle,0.05),"a58456")
				if i%2==0:
					s.box(root,Vector3(x,1.88-handle-0.06,0.1),Vector3(0.18,0.12,0.1),"4e5657")
				else:
					s.tilted_box(root,Vector3(x+0.04,1.88-handle-0.1,0.1),Vector3(0.04,0.26,0.04),"4e5657",Vector3(0,0,0.25))

## A string of chillies, garlic, maize cobs or herbs hung from a nail (`goods`).
func _string_hang() -> void:
	var goods: String = String(data.get("goods","chili"))
	s.box(root,Vector3(0,2.3,0.04),Vector3(0.05,0.05,0.08),"3a3530")
	s.box(root,Vector3(0,1.95,0.06),Vector3(0.02,0.7,0.02),"b8a46c")
	for i: int in 8:
		var at := Vector3(sin(i*2.1)*0.07,2.2-i*0.09,0.09+cos(i*1.7)*0.02)
		match goods:
			"garlic":
				s.box(root,at,Vector3(0.12,0.1,0.12),_pick(["e8e0cc","dcd2b8","efe8d8"]))
			"corn":
				if i%2==0:
					s.box(root,at+Vector3(0,-0.06,0),Vector3(0.1,0.24,0.1),_pick(["e0b040","d49a32","e8c45a"]))
			"herbs":
				s.tilted_box(root,at,Vector3(0.05,0.2,0.05),_pick(["6f7f4a","7d8a55","5e6b3e"]),Vector3(0,0,_jitter(0.4)))
			_:
				s.tilted_box(root,at,Vector3(0.05,0.16,0.05),_pick(["b8322a","c4402e","a52a22"]),Vector3(0,0,_jitter(0.5)))

## Account books on a nail and an abacus hung beside them.
func _ledger_hook() -> void:
	s.box(root,Vector3(-0.15,2.2,0.04),Vector3(0.05,0.05,0.08),"3a3530")
	for i: int in 3:
		s.box(root,Vector3(-0.15+_jitter(0.02),1.95-i*0.03,0.06+i*0.02),Vector3(0.36,0.46,0.03),_pick(["c9b98e","b8a374","d8ccaa"]))
		s.box(root,Vector3(-0.15,2.15-i*0.03,0.08+i*0.02),Vector3(0.36,0.04,0.012),"4e6967")
	s.box(root,Vector3(0.28,1.85,0.04),Vector3(0.46,0.26,0.04),"4b4031")
	for row: int in 3:
		for bead: int in 5:
			s.box(root,Vector3(0.12+bead*0.075,1.78+row*0.07,0.07),Vector3(0.05,0.045,0.04),"b79c66")

## 年画: a new-year print, its red border faded, a door god or a fat child with a fish.
func _new_year_print() -> void:
	var faded: bool = rng.randf()<0.5
	s.box(root,Vector3(0,1.95,0.025),Vector3(0.62,0.82,0.02),"b8564a" if faded else "c23a2e")
	s.box(root,Vector3(0,1.95,0.04),Vector3(0.5,0.68,0.012),"e6d6b0" if faded else "efe2c0")
	s.box(root,Vector3(0,1.86,0.05),Vector3(0.26,0.36,0.01),_pick(["c0392b","3f6f8f","d6a33a"]))
	s.box(root,Vector3(0,2.12,0.05),Vector3(0.16,0.16,0.01),"e6c6a0")
	s.box(root,Vector3(0.12,1.76,0.055),Vector3(0.18,0.08,0.01),"d4743a")
	if rng.randf()<0.4:
		s.tilted_box(root,Vector3(0.22,2.3,0.05),Vector3(0.14,0.1,0.01),"e6d6b0",Vector3(0,0,0.5))

## 对联: two red strips with black writing either side of something (a door, an altar), a short
## one across the top.
## A rope coiled on the floor (halfhole.c's 缚仙绳: `colors` its strands, gold for that one).
func _rope_coil(w: float, d: float) -> void:
	var strands: Array = data.get("colors",["b89a5a","a88a4a"])
	var r: float = minf(w,d)*0.4
	for ring: int in 3:
		for i: int in 10:
			var a: float = i*TAU/10.0+ring*0.3
			var rr: float = r*(0.5+ring*0.25)
			s.tilted_box(root,Vector3(cos(a)*rr,0.03+ring*0.03,sin(a)*rr),Vector3(rr*0.62,0.05,0.06),String(strands[(i+ring)%strands.size()]),Vector3(0,-a+PI/2,0))
	s.tilted_box(root,Vector3(r*0.6,0.04,r*0.9),Vector3(0.06,0.05,0.5),String(strands[0]),Vector3(0,0.6,0))

func _couplet() -> void:
	var red: String = "b8463a" if rng.randf()<0.5 else "c8342a"
	for side: float in [-0.5,0.5]:
		s.box(root,Vector3(side,1.75,0.025),Vector3(0.2,1.2,0.012),red)
		for c: int in 5:
			s.box(root,Vector3(side,2.22-c*0.22,0.035),Vector3(0.1,0.1,0.006),"2a2622")
	s.box(root,Vector3(0,2.5,0.025),Vector3(0.7,0.18,0.012),red)

## Clothes on wooden pegs: a coat, a hat, a cloth bag.
func _clothes_peg() -> void:
	s.box(root,Vector3(0,2.05,0.03),Vector3(1.0,0.1,0.05),"6a5039")
	var coat: String = _pick(["5a6e86","6b5a4a","4a5a4a","8a5a48","7a7a6a"])
	s.box(root,Vector3(-0.25,1.6,0.08),Vector3(0.42,0.8,0.08),coat)
	s.box(root,Vector3(-0.25,1.95,0.1),Vector3(0.5,0.14,0.08),coat)
	s.box(root,Vector3(-0.25,1.55,0.13),Vector3(0.06,0.6,0.01),Color(coat).darkened(0.25).to_html(false))
	if rng.randf()<0.6:
		s.box(root,Vector3(0.25,1.92,0.1),Vector3(0.34,0.12,0.18),_pick(["3a3530","6b5a4a","b8a374"]))
	else:
		s.box(root,Vector3(0.25,1.75,0.09),Vector3(0.26,0.32,0.08),_pick(["8a7a5a","6b5a4a"]))

## 蓑衣斗笠: a straw rain cape and a bamboo hat on a nail.
func _straw_cape() -> void:
	s.box(root,Vector3(0,2.25,0.04),Vector3(0.05,0.05,0.08),"3a3530")
	for row: int in 4:
		s.box(root,Vector3(0,2.05-row*0.2,0.07+row*0.015),Vector3(0.42+row*0.1,0.22,0.06),_pick(["9a8a5a","a8986a","8a7a4c"]))
	s.box(root,Vector3(0.36,1.7,0.08),Vector3(0.5,0.08,0.5),"c4ad72")
	s.box(root,Vector3(0.36,1.76,0.08),Vector3(0.22,0.1,0.22),"b39a62")

## 黄历: a small almanac hung on the wall, a few leaves torn off.
func _calendar() -> void:
	s.box(root,Vector3(0,1.95,0.025),Vector3(0.3,0.42,0.02),"e3d6b0")
	s.box(root,Vector3(0,2.12,0.04),Vector3(0.3,0.08,0.01),"b23a2b")
	s.box(root,Vector3(0,1.9,0.04),Vector3(0.14,0.14,0.006),"2a2622")
	s.box(root,Vector3(0,2.18,0.03),Vector3(0.32,0.03,0.03),"6a5039")

## A bracket oil lamp on the wall, lit day and night, its flame wavering and the wall above it
## smoked (the room's soot comes from the life layer).
func _wall_lamp() -> void:
	s.box(root,Vector3(0,1.75,0.06),Vector3(0.08,0.36,0.1),"4a3a2c")
	s.box(root,Vector3(0,1.6,0.16),Vector3(0.08,0.06,0.24),"4a3a2c")
	s.box(root,Vector3(0,1.66,0.26),Vector3(0.18,0.08,0.18),"7a6a54")
	s.box(root,Vector3(0,1.74,0.26),Vector3(0.04,0.08,0.04),"ffd88a")
	var light := OmniLight3D.new()
	light.position = Vector3(0,1.9,0.4)
	light.light_color = Color("ffc27d")
	light.omni_range = 4.5
	light.set_meta("day_energy",0.35)
	light.set_meta("night_energy",1.2)
	light.set_meta("flicker",0.12)
	root.add_child(light)

## A shelf board on brackets with bowls, a jar and a bundle on it.
func _wall_shelf(w: float) -> void:
	var width: float = minf(w,1.4)
	s.box(root,Vector3(0,1.7,0.18),Vector3(width,0.06,0.32),"7a5f43")
	for x: float in [-width*0.35,width*0.35]:
		s.tilted_box(root,Vector3(x,1.58,0.1),Vector3(0.05,0.24,0.05),"6a5039",Vector3(0.6,0,0))
	var x: float = -width*0.4
	while x < width*0.4:
		match rng.randi_range(0,3):
			0:
				for b: int in 3:
					s.box(root,Vector3(x+0.1,1.76+b*0.05,0.2),Vector3(0.2,0.045,0.2),"d8d2c2")
				x += 0.26
			1:
				s.box(root,Vector3(x+0.1,1.88,0.2),Vector3(0.2,0.3,0.2),_pick(["6b4a35","5d7f78","8b5440"]))
				x += 0.26
			2:
				s.box(root,Vector3(x+0.12,1.8,0.2),Vector3(0.26,0.14,0.22),_pick(["c9b98e","6b5a4a","a68a55"]))
				x += 0.3
			_:
				x += 0.15

## Swords and sabres on pegs, wiped bright (a weapon store).
func _weapon_pegs(w: float) -> void:
	var width: float = minf(w,1.6)
	for y: float in [1.55,2.25]:
		s.box(root,Vector3(0,y,0.03),Vector3(width,0.08,0.05),"6a5039")
	for i: int in maxi(2,floori(width/0.4)):
		var x: float = -width*0.38+i*width*0.76/maxf(1,maxi(2,floori(width/0.4))-1)
		s.tilted_box(root,Vector3(x,1.9,0.09),Vector3(0.06,0.95,0.025),"c6cfcb",Vector3(0,0,0.04))
		s.box(root,Vector3(x+0.02,2.42,0.09),Vector3(0.16,0.05,0.05),"b8923e")
		s.box(root,Vector3(x+0.03,2.55,0.09),Vector3(0.06,0.2,0.06),_pick(["6b2a24","3a3530","5a4130"]))

## Boards hung in a row: an inn's 水牌 of dishes, a post's notices pinned up (`loose`: some
## askew, one corner curling).
func _boards(w: float, papers: Array, ink: String, loose: bool = false) -> void:
	var count: int = mini(5,maxi(2,floori(minf(w,2.0)/0.32)))
	for i: int in count:
		var board := Node3D.new()
		board.position = Vector3(-(count-1)*0.16+i*0.32,2.0+(_jitter(0.1) if loose else 0.0),0.03)
		board.rotation.z = _jitter(0.12) if loose else 0.0
		root.add_child(board)
		s.box(board,Vector3.ZERO,Vector3(0.24,0.62 if not loose else 0.4,0.02),_pick(papers))
		for c: int in 4:
			s.box(board,Vector3(0,0.2-c*0.13,0.012),Vector3(0.08,0.06,0.006),ink)
	if not loose:
		s.box(root,Vector3(0,2.35,0.03),Vector3(count*0.32+0.1,0.06,0.05),"6a5039")

## 檀木匾额 (heal_room.c: 两侧的墙璧上挂了许许多多的檀木扁额): rows of dark sandalwood boards
## given by the grateful, four gilt characters across each, the giver's name small in the corner;
## a few hung a little askew. `rows` of them, as many across as the wall takes.
func _plaques(w: float) -> void:
	var across: int = maxi(1,floori(w/1.0))
	for row: int in int(data.get("rows",2)):
		for i: int in across:
			var board := Node3D.new()
			board.position = Vector3(-(across-1)*0.5+i*1.0,2.6-row*0.6,0.03)
			board.rotation.z = _jitter(0.05)
			root.add_child(board)
			s.box(board,Vector3.ZERO,Vector3(0.86,0.42,0.04),_pick(["4a2c20","5a3424","3e2418"]))
			s.box(board,Vector3(0,0,0.022),Vector3(0.78,0.34,0.01),_pick(["5e3a28","6a4430"]))
			for c: int in 4:
				s.box(board,Vector3(-0.27+c*0.18,0.03,0.03),Vector3(0.11,0.12,0.008),"d8b04a")
			s.box(board,Vector3(0.28,-0.12,0.03),Vector3(0.12,0.03,0.006),"c8a048")

## 壁画 (back_temple.c: 四周的墙上唯妙唯肖地彩绘著十八罗汉, 每个罗汉的旁边并写著他得道升天的过程;
## corridor1.c: 观世音菩萨救苦救难的事迹): a long painted band on old plaster, figures in robes
## (`robes`) with their halos, clouds between, a column of writing beside each; the paint faded
## and flaked low down where hands and shoulders rub it. `figures` across, else one a unit.
func _mural(w: float) -> void:
	var robes: Array = data.get("robes",["a8483a","c88a3a","4a6a8a","6a8a5a","8a5a7a","c8b890"])
	var count: int = int(data.get("figures",maxi(1,floori(w/1.0))))
	var step: float = w/count
	s.box(root,Vector3(0,1.85,0.02),Vector3(w,1.5,0.02),String(data.get("ground","d8ccb0")))
	s.box(root,Vector3(0,2.64,0.03),Vector3(w,0.08,0.02),"8a3a2a")
	s.box(root,Vector3(0,1.06,0.03),Vector3(w,0.08,0.02),"8a3a2a")
	for i: int in count:
		var x: float = -w/2+(i+0.5)*step
		var robe: String = String(robes[(i+int(data.get("seed",0)))%robes.size()])
		var lean: float = _jitter(0.15)
		# A seated figure on a rock: the robe spread over his knees, arms, face and dark hair,
		# the halo behind his head.
		s.box(root,Vector3(x,1.36,0.032),Vector3(step*0.5,0.2,0.008),"8a8478")
		s.box(root,Vector3(x,1.56,0.035),Vector3(step*0.46,0.22,0.01),robe)
		s.box(root,Vector3(x+lean*0.2,1.9,0.035),Vector3(step*0.3,0.56,0.01),robe)
		var tone := Color(robe.get_slice(":",0))
		s.box(root,Vector3(x+lean*0.2,1.9,0.04),Vector3(step*0.06,0.5,0.006),tone.darkened(0.3).to_html(false))
		for arm: float in [-1.0,1.0]:
			s.box(root,Vector3(x+arm*step*0.17,1.78,0.04),Vector3(step*0.07,0.3,0.006),tone.darkened(0.15).to_html(false))
		s.box(root,Vector3(x,2.33,0.036),Vector3(step*0.26,0.26,0.008),"e8c86a")
		s.box(root,Vector3(x,2.3,0.04),Vector3(step*0.14,0.16,0.008),"d8b090")
		s.box(root,Vector3(x,2.4,0.044),Vector3(step*0.15,0.05,0.006),"2a2622")
		s.box(root,Vector3(x+step*0.3,1.9,0.036),Vector3(0.04,0.7,0.006),"3a3028")
		if i%2==0:
			s.box(root,Vector3(x+step*0.5,2.45,0.035),Vector3(step*0.3,0.1,0.006),"e8e4dc")
	for flake: int in maxi(2,floori(w/0.8)):
		s.box(root,Vector3(_jitter(w*0.45),rng.randf_range(1.15,1.5),0.04),Vector3(rng.randf_range(0.12,0.3),rng.randf_range(0.06,0.14),0.006),"b8ad96")

## 肉钩 (butchery.c: 肉架上挂满了血淋淋的生肉): iron hooks on a beam with a side of meat, a string
## of sausages and a hock hanging from them, drips dark on the wall below.
func _meat_hooks(w: float) -> void:
	var width: float = minf(w,1.5)
	s.box(root,Vector3(0,2.3,0.08),Vector3(width,0.1,0.12),"4a3a2c")
	var hooks: int = maxi(2,floori(width/0.4))
	for i: int in hooks:
		var x: float = -width*0.38+i*width*0.76/maxf(1,hooks-1)
		s.box(root,Vector3(x,2.18,0.14),Vector3(0.03,0.16,0.03),"3a3530")
		s.box(root,Vector3(x+0.03,2.1,0.14),Vector3(0.07,0.03,0.03),"3a3530")
		match (i+int(data.get("seed",0)))%3:
			0:
				# A side of pork, pale fat over red meat.
				s.shard(root,Vector3(x,1.76,0.16),Vector3(0.26,0.66,0.14),"b9403a",rng.randi())
				s.box(root,Vector3(x,1.76,0.235),Vector3(0.22,0.6,0.012),"e8cfb8")
				s.box(root,Vector3(x,1.5,0.17),Vector3(0.2,0.1,0.13),"8a2a28")
			1:
				# A string of sausages looped twice over the hook.
				for k: int in 7:
					s.tilted_box(root,Vector3(x+(k-3)*0.05,2.0-absf(k-3)*0.1-float(k%2)*0.04,0.16),Vector3(0.07,0.14,0.07),_pick(["8a3a30","9a4536","7a3028"]),Vector3(0,0,_jitter(0.3)))
			_:
				# A hock and a rack of ribs.
				s.box(root,Vector3(x,1.9,0.16),Vector3(0.12,0.32,0.12),"c47a5a")
				s.box(root,Vector3(x,1.64,0.16),Vector3(0.2,0.24,0.1),"b9403a")
				for rib: int in 4:
					s.box(root,Vector3(x-0.07+rib*0.047,1.64,0.215),Vector3(0.02,0.22,0.01),"e8dcc6")
		for drip: int in 3:
			s.box(root,Vector3(x+_jitter(0.1),1.2-drip*0.12,0.025),Vector3(0.03,0.1,0.01),"5a2320")
	s.box(root,Vector3(0,0.012,0.2),Vector3(width*0.8,0.012,0.3),"5a2a26")

## 囍 (a 红娘庄's): a red paper square hung as a diamond, the double-happiness character in gold
## across it, a bit of red cord above; `faded` where it has hung since the last wedding.
func _double_happiness() -> void:
	var faded: bool = rng.randf()<0.4
	var red: String = "b8463a" if faded else "c8342a"
	var gold: String = "d8b04a" if faded else "e8c45a"
	var paper := Node3D.new()
	paper.position = Vector3(0,2.0,0.025)
	paper.rotation.z = PI/4+_jitter(0.04)
	root.add_child(paper)
	s.box(paper,Vector3.ZERO,Vector3(0.62,0.62,0.015),red)
	s.box(paper,Vector3.ZERO,Vector3(0.54,0.54,0.016),Color(red).lightened(0.06).to_html(false))
	# The character: two 喜 side by side, each a stack of bars.
	for side: float in [-0.12,0.12]:
		for bar: int in 5:
			var wide: float = [0.16,0.1,0.18,0.1,0.14][bar]
			s.box(root,Vector3(side,2.2-bar*0.1,0.045),Vector3(wide,0.035,0.01),gold)
		s.box(root,Vector3(side,2.0,0.045),Vector3(0.03,0.42,0.01),gold)
	s.box(root,Vector3(0,2.48,0.03),Vector3(0.03,0.08,0.012),"c8342a")

## 兽皮 (keep3.c's hall of bear skin and bones): a pelt stretched on the wall with pegs at its
## four legs, the fur in two tones (`fur`), a bald patch where it has worn.
func _animal_hide() -> void:
	var furs: Array = data.get("fur",[["5a4332","4a3628"],["6b5a44","5a4a36"],["8a6a4a","7a5a3c"],["3a3028","4a3a30"]])
	var fur: Array = furs[rng.randi_range(0,furs.size()-1)]
	var spread := Node3D.new()
	spread.position = Vector3(0,1.9,0.04)
	spread.rotation.z = _jitter(0.08)
	root.add_child(spread)
	s.box(spread,Vector3.ZERO,Vector3(0.9,0.74,0.03),String(fur[0]))
	s.box(spread,Vector3(-0.06,0.06,0.016),Vector3(0.64,0.44,0.02),String(fur[1]))
	s.box(spread,Vector3(0.14,-0.1,0.03),Vector3(0.2,0.14,0.012),Color(String(fur[1])).lightened(0.3).to_html(false))
	for leg: Vector2 in [Vector2(-0.52,0.38),Vector2(0.52,0.38),Vector2(-0.52,-0.36),Vector2(0.52,-0.36)]:
		s.tilted_box(spread,Vector3(leg.x,leg.y,0.0),Vector3(0.14,0.3,0.03),String(fur[0]),Vector3(0,0,-leg.x*0.5))
		s.box(spread,Vector3(leg.x*1.1,leg.y*1.3,0.02),Vector3(0.04,0.04,0.05),"3a3530")
	# The head end, a little lower, its dark muzzle.
	s.box(spread,Vector3(0,-0.47,0.01),Vector3(0.3,0.2,0.04),String(fur[0]))
	s.box(spread,Vector3(0,-0.54,0.035),Vector3(0.12,0.06,0.02),"2a2420")

## A cloth banner hung on the wall, smoke-darkened at the top (a temple's 幡; `cloth` its colour).
func _banner_cloth() -> void:
	s.box(root,Vector3(0,2.6,0.05),Vector3(0.5,0.05,0.05),"6a5039")
	var cloth: String = String(data.get("cloth",_pick(["a8322a","c49a3a","8a3a2a"])))
	s.box(root,Vector3(0,2.0,0.06),Vector3(0.36,1.1,0.02),cloth)
	s.box(root,Vector3(0,2.45,0.07),Vector3(0.36,0.2,0.012),Color(cloth).darkened(0.35).to_html(false))
	for strip: int in 3:
		s.box(root,Vector3(-0.12+strip*0.12,1.36,0.06),Vector3(0.08,0.2,0.02),cloth)

# --- On tables ----------------------------------------------------------------------------------

## What is left on a table top `top` high, `w` x `d` (a meal half eaten, wine, a ledger...). Its
## own `variant` decides where things lie; the table drawn first, these above it.
func table_set(shapes: Shapes, parent: Node3D, top: float, w: float, d: float, contents: String, variant: int) -> void:
	s = shapes
	root = parent
	rng.seed = hash(variant)
	match contents:
		"meal":
			for i: int in rng.randi_range(2,4):
				var at := Vector3(_jitter(w*0.36),top,_jitter(d*0.32))
				s.box(root,at+Vector3(0,0.04,0),Vector3(0.18,0.08,0.18),"d8d2c2")
				if rng.randf()<0.6:
					s.box(root,at+Vector3(0,0.085,0),Vector3(0.13,0.02,0.13),_pick(["efe8d8","c9a35e","8a4a2a"]))
				s.tilted_box(root,at+Vector3(0.12,0.015,0.04),Vector3(0.025,0.02,0.26),"c9a35e",Vector3(0,_jitter(0.6),0))
			s.box(root,Vector3(_jitter(w*0.15),top+0.03,_jitter(d*0.15)),Vector3(0.34,0.05,0.34),"d8d2c2")
			s.box(root,Vector3(_jitter(w*0.15),top+0.065,_jitter(d*0.15)),Vector3(0.22,0.04,0.22),_pick(["b8743a","6f8a4a","9e3a32"]))
		"wine":
			var tipped := Node3D.new()
			tipped.position = Vector3(_jitter(w*0.3),top+0.1,_jitter(d*0.25))
			tipped.rotation = Vector3(0,rng.randf()*TAU,PI/2 if rng.randf()<0.5 else 0.0)
			root.add_child(tipped)
			s.box(tipped,Vector3(0,0.05,0),Vector3(0.2,0.3,0.2),"6b4a35")
			s.box(tipped,Vector3(0,0.24,0),Vector3(0.1,0.08,0.1),"b23a2b")
			for c: int in rng.randi_range(2,3):
				s.box(root,Vector3(_jitter(w*0.38),top+0.035,_jitter(d*0.34)),Vector3(0.08,0.07,0.08),"d9cfb4")
			s.box(root,Vector3(_jitter(w*0.2),top+0.005,_jitter(d*0.2)),Vector3(0.3,0.008,0.2),"6a3a2a")
			s.box(root,Vector3(_jitter(w*0.3),top+0.02,_jitter(d*0.3)),Vector3(0.12,0.03,0.08),"e0c890")
		"tea_used":
			s.box(root,Vector3(_jitter(w*0.25),top+0.13,_jitter(d*0.2)),Vector3(0.26,0.24,0.26),_pick(["6c9690","a0835b","5d6b60"]))
			for c: int in rng.randi_range(2,4):
				var tilt: bool = rng.randf()<0.25
				s.tilted_box(root,Vector3(_jitter(w*0.38),top+0.04,_jitter(d*0.34)),Vector3(0.09,0.08,0.09),"e3d5b4",Vector3(PI/2 if tilt else 0.0,0,0))
			s.box(root,Vector3(_jitter(w*0.3),top+0.004,_jitter(d*0.3)),Vector3(0.22,0.006,0.16),"7a5a3a")
		"ledger":
			s.box(root,Vector3(-w*0.15,top+0.035,_jitter(0.05)),Vector3(0.5,0.06,0.36),"c9b98e")
			s.box(root,Vector3(-w*0.15,top+0.07,0),Vector3(0.5,0.012,0.012),"4e6967")
			s.box(root,Vector3(w*0.2,top+0.03,_jitter(0.05)),Vector3(0.46,0.05,0.24),"4b4031")
			for bead: int in 6:
				s.box(root,Vector3(w*0.2-0.17+bead*0.07,top+0.07,0),Vector3(0.05,0.04,0.18),"b79c66")
			s.tilted_box(root,Vector3(_jitter(w*0.3),top+0.02,d*0.25),Vector3(0.03,0.03,0.3),"b99b68",Vector3(0,_jitter(0.8),0))
		"sewing":
			s.box(root,Vector3(_jitter(w*0.2),top+0.06,_jitter(d*0.15)),Vector3(0.4,0.1,0.32),"a68a55")
			for spool: int in 3:
				s.box(root,Vector3(_jitter(w*0.3),top+0.05,_jitter(d*0.3)),Vector3(0.07,0.09,0.07),["b23a2b","4a6f8f","d6b862"][spool])
			s.tilted_box(root,Vector3(_jitter(w*0.25),top+0.01,_jitter(d*0.25)),Vector3(0.5,0.015,0.36),_pick(["486981","8a5a48","c9b98e"]),Vector3(0,_jitter(0.5),0))
		"books":
			for i: int in rng.randi_range(2,3):
				s.box(root,Vector3(w*0.25+_jitter(0.03),top+0.04+i*0.07,_jitter(0.04)),Vector3(0.4,0.06,0.3),_pick(["4e6967","ad8055","c9b98e","65738a"]))
			s.tilted_box(root,Vector3(-w*0.15,top+0.02,_jitter(0.08)),Vector3(0.5,0.02,0.36),"e4d8af",Vector3(0,_jitter(0.3),0))
		"medicine":
			for i: int in rng.randi_range(3,5):
				s.box(root,Vector3(_jitter(w*0.38),top+0.04,_jitter(d*0.3)),Vector3(0.16,0.07,0.14),_pick(["cbbb8f","b8a374","d8ccaa"]))
			s.box(root,Vector3(w*0.25,top+0.03,0),Vector3(0.06,0.05,0.4),"6a5039")
			s.box(root,Vector3(w*0.25,top+0.1,-0.16),Vector3(0.14,0.02,0.14),"b8923e")
		"tools":
			s.tilted_box(root,Vector3(_jitter(w*0.25),top+0.05,_jitter(d*0.2)),Vector3(0.08,0.08,0.5),"a58456",Vector3(0,_jitter(0.8),0))
			s.box(root,Vector3(_jitter(w*0.3),top+0.06,_jitter(d*0.25)),Vector3(0.2,0.12,0.12),"4e5657")
			s.box(root,Vector3(_jitter(w*0.3),top+0.02,_jitter(d*0.25)),Vector3(0.4,0.03,0.1),"6f7879")
		"offering":
			for i: int in 3:
				var at := Vector3((i-1)*w*0.28,top,_jitter(0.05))
				s.box(root,at+Vector3(0,0.03,0),Vector3(0.24,0.05,0.24),"d8d2c2")
				s.box(root,at+Vector3(0,0.09,0),Vector3(0.16,0.08,0.16),["d28a3a","e6d6b0","b8322a"][i])
		"dice":
			# 骰盅 (duchang.c): the dice cup upturned, dice spilt, loose silver and copper, a wine
			# pot and cups, a bet slip.
			s.box(root,Vector3(_jitter(w*0.2),top+0.1,_jitter(d*0.15)),Vector3(0.18,0.2,0.18),"3a3028")
			s.box(root,Vector3(_jitter(w*0.2),top+0.21,_jitter(d*0.15)),Vector3(0.2,0.02,0.2),"5a4a3a")
			for die: int in 3:
				s.tilted_box(root,Vector3(_jitter(w*0.35),top+0.035,_jitter(d*0.3)),Vector3(0.06,0.06,0.06),"efe8d8",Vector3(0,rng.randf()*TAU,0))
			for coin: int in rng.randi_range(4,7):
				s.tilted_box(root,Vector3(_jitter(w*0.4),top+0.012,_jitter(d*0.35)),Vector3(0.07,0.02,0.06),_pick(["d9d4c4","c8c2b0","b08a48"]),Vector3(0,rng.randf()*TAU,0))
			s.shard(root,Vector3(_jitter(w*0.3),top+0.05,_jitter(d*0.3)),Vector3(0.12,0.08,0.1),"c8c2b0",rng.randi())
			s.box(root,Vector3(_jitter(w*0.3),top+0.14,_jitter(d*0.3)),Vector3(0.16,0.26,0.16),"6b4a35")
			for c: int in 2:
				s.box(root,Vector3(_jitter(w*0.38),top+0.035,_jitter(d*0.34)),Vector3(0.08,0.07,0.08),"d9cfb4")
			s.tilted_box(root,Vector3(_jitter(w*0.3),top+0.006,_jitter(d*0.3)),Vector3(0.16,0.006,0.1),"e3d6b0",Vector3(0,_jitter(0.6),0))
		"rouge":
			# 脂粉 (jiyuan.c): a bronze mirror on its stand, rouge and powder boxes, a comb, a
			# hairpin and a cup of wine left beside them.
			s.box(root,Vector3(-w*0.2,top+0.03,-d*0.1),Vector3(0.22,0.06,0.1),"6a4c33")
			s.box(root,Vector3(-w*0.2,top+0.2,-d*0.1),Vector3(0.22,0.28,0.02),"b8923e")
			s.box(root,Vector3(-w*0.2,top+0.2,-d*0.1+0.012),Vector3(0.17,0.22,0.008),"d9d4c4")
			for i: int in 3:
				var at := Vector3(_jitter(w*0.3),top+0.03,_jitter(d*0.3))
				s.box(root,at,Vector3(0.1,0.06,0.1),_pick(["c0392b","8a3a5a","e8c0c4","3f6f8f"]))
				s.box(root,at+Vector3(0.04,0.04,0.03),Vector3(0.09,0.012,0.09),_pick(["e6b0a0","f0e6d8"]))
			s.tilted_box(root,Vector3(_jitter(w*0.3),top+0.015,_jitter(d*0.3)),Vector3(0.16,0.02,0.05),"4b4031",Vector3(0,_jitter(0.8),0))
			s.tilted_box(root,Vector3(_jitter(w*0.3),top+0.01,_jitter(d*0.3)),Vector3(0.18,0.012,0.012),"d8b04a",Vector3(0,_jitter(0.8),0))
			s.box(root,Vector3(w*0.28,top+0.035,d*0.2),Vector3(0.08,0.07,0.08),"d9cfb4")
			for fleck: int in 4:
				s.box(root,Vector3(_jitter(w*0.35),top+0.006,_jitter(d*0.3)),Vector3(0.04,0.004,0.03),"efd6d0")
		"betrothal":
			# 礼单 (marry_room.c): the gift list on red paper, a brush and ink, two red candles in
			# brass holders, tea cups for the two families.
			s.box(root,Vector3(-w*0.12,top+0.006,_jitter(0.05)),Vector3(0.5,0.008,0.36),"c8342a")
			for line: int in 4:
				s.box(root,Vector3(-w*0.12-0.16+line*0.1,top+0.012,_jitter(0.02)),Vector3(0.03,0.004,0.26),"2a2622")
			s.tilted_box(root,Vector3(_jitter(w*0.3),top+0.02,d*0.25),Vector3(0.03,0.03,0.3),"b99b68",Vector3(0,_jitter(0.8),0))
			s.box(root,Vector3(w*0.2,top+0.02,-d*0.2),Vector3(0.12,0.04,0.12),"2a2622")
			for x: float in [w*0.3,-w*0.32]:
				s.box(root,Vector3(x,top+0.03,-d*0.25),Vector3(0.1,0.06,0.1),"b8923e")
				s.box(root,Vector3(x,top+0.22,-d*0.25),Vector3(0.05,0.32,0.05),"c8342a")
				s.box(root,Vector3(x,top+0.4,-d*0.25),Vector3(0.03,0.05,0.03),"ffd88a")
			for c: int in 2:
				s.box(root,Vector3(_jitter(w*0.35),top+0.035,d*0.3+_jitter(0.05)),Vector3(0.08,0.07,0.08),"e3d5b4")
		"tailoring":
			# 剪刀、尺 (tailory.c): big iron shears, a bamboo rule, chalk marks on a cloth laid
			# out, pins in a cushion, thread ends.
			var cloth: String = _pick(["486981","8a5a48","c9b98e","3d5a7a","7a5a8c"])
			s.tilted_box(root,Vector3(_jitter(w*0.15),top+0.012,_jitter(d*0.15)),Vector3(w*0.8,0.015,d*0.75),cloth,Vector3(0,_jitter(0.2),0))
			for mark: int in 3:
				s.box(root,Vector3(_jitter(w*0.3),top+0.022,_jitter(d*0.3)),Vector3(rng.randf_range(0.1,0.3),0.004,0.012),"efe8d8")
			var shears := Node3D.new()
			shears.position = Vector3(_jitter(w*0.3),top+0.03,_jitter(d*0.3))
			shears.rotation.y = rng.randf()*TAU
			root.add_child(shears)
			for blade: float in [-0.03,0.03]:
				s.tilted_box(shears,Vector3(blade*2,0,0.1),Vector3(0.035,0.02,0.3),"8f9a9b",Vector3(0,blade*2,0))
				s.tilted_box(shears,Vector3(blade*3,0.01,-0.12),Vector3(0.05,0.03,0.14),"3a3530",Vector3(0,blade*3,0))
			s.tilted_box(root,Vector3(_jitter(w*0.3),top+0.025,_jitter(d*0.3)),Vector3(0.6,0.02,0.04),"c4ad72",Vector3(0,_jitter(0.5),0))
			s.box(root,Vector3(w*0.25,top+0.045,-d*0.2),Vector3(0.12,0.06,0.12),"8a3a3a")
			for pin: int in 4:
				s.box(root,Vector3(w*0.25+_jitter(0.04),top+0.09,-d*0.2+_jitter(0.04)),Vector3(0.008,0.05,0.008),"c6cfcb")
			for thread: int in 4:
				s.tilted_box(root,Vector3(_jitter(w*0.4),top+0.02,_jitter(d*0.35)),Vector3(0.12,0.006,0.008),_pick(["b23a2b","4a6f8f","d6b862","efe8d8"]),Vector3(0,rng.randf()*TAU,0))
		"vegetarian":
			# 素斋 (monky.c): bowls of rice and greens, chopsticks, a pot of plain tea, no wine.
			for i: int in rng.randi_range(2,3):
				var at := Vector3(_jitter(w*0.36),top,_jitter(d*0.32))
				s.box(root,at+Vector3(0,0.04,0),Vector3(0.18,0.08,0.18),"d8d2c2")
				s.box(root,at+Vector3(0,0.085,0),Vector3(0.13,0.02,0.13),_pick(["efe8d8","6f8a4a","8aa05a"]))
				s.tilted_box(root,at+Vector3(0.12,0.015,0.04),Vector3(0.025,0.02,0.26),"c9a35e",Vector3(0,_jitter(0.6),0))
			s.box(root,Vector3(_jitter(w*0.15),top+0.03,_jitter(d*0.15)),Vector3(0.3,0.05,0.3),"d8d2c2")
			s.box(root,Vector3(_jitter(w*0.15),top+0.065,_jitter(d*0.15)),Vector3(0.2,0.04,0.2),"6f8a4a")
			s.box(root,Vector3(w*0.28,top+0.11,-d*0.2),Vector3(0.2,0.2,0.2),_pick(["5d6b60","9a8466"]))
			s.box(root,Vector3(w*0.1,top+0.035,-d*0.28),Vector3(0.08,0.07,0.08),"e3d5b4")
		"lamp":
			s.box(root,Vector3(_jitter(w*0.25),top+0.08,_jitter(d*0.2)),Vector3(0.14,0.16,0.14),"7a6a54")
			s.box(root,Vector3(0,top+0.2,0),Vector3(0.035,0.07,0.035),"ffd88a")
			var light := OmniLight3D.new()
			light.position = Vector3(0,top+0.5,0)
			light.light_color = Color("ffc27d")
			light.omni_range = 3.5
			light.set_meta("day_energy",0.2)
			light.set_meta("night_energy",0.9)
			light.set_meta("flicker",0.1)
			root.add_child(light)

# --- On the floor -------------------------------------------------------------------------------

## A little litter at `at` (floor level): food scraps, grains, chips, straw, paper, cinders,
## iron scale, husks, ash. Flat; nothing to walk round.
func scatter(shapes: Shapes, parent: Node3D, at: Vector3, kind: String, variant: int) -> void:
	s = shapes
	rng.seed = hash(variant)
	var colors: Array
	var size := Vector2(0.06,0.05)
	var count: int = 4
	match kind:
		"shreds": colors = ["d8ccaa","8a6a3a","c9a35e","efe8d8"]
		"grains": colors = ["e0d2a0","d8c48e","efe2b8"]; size = Vector2(0.035,0.03); count = 9
		"chips": colors = ["c9ad7c","b2946a","d8be8c"]; size = Vector2(0.08,0.04)
		"straw":
			for i: int in 6:
				s.tilted_box(parent,at+Vector3(_jitter(0.22),0.012,_jitter(0.22)),Vector3(0.03,0.012,rng.randf_range(0.15,0.3)),_pick(["a49667","b6aa7a","c4b484"]),Vector3(0,rng.randf()*TAU,0))
			return
		"paper": colors = ["e3d6b0","efe6cc","d6c48f"]; size = Vector2(0.14,0.1); count = 2
		"cinders": colors = ["2a2826","3a3631","5a3a2a"]; size = Vector2(0.06,0.05); count = 7
		"scrap": colors = ["4e5657","6f7879","5d6667"]; size = Vector2(0.09,0.03); count = 4
		"husks": colors = ["c4ad72","b39a62","d8c48e"]; size = Vector2(0.05,0.03); count = 10
		"ash": colors = ["8e8a84","a19c94","7a7670"]; size = Vector2(0.12,0.1); count = 3
		"dust": colors = ["b8b0a0","a8a090","c4bcac"]; size = Vector2(0.1,0.08); count = 4
		"stone_chips": colors = ["9a9a8c","a8a798","85877b"]; size = Vector2(0.07,0.05); count = 7
		"blood":
			# Dried dark drops and a smear on a butcher's floor.
			colors = ["5a2320","6a2a26","4a1c1a"]; size = Vector2(0.09,0.07); count = 5
		"threads":
			# Thread ends and snippets of cloth under a tailor's table.
			for i: int in 5:
				s.tilted_box(parent,at+Vector3(_jitter(0.22),0.012,_jitter(0.22)),Vector3(0.012,0.008,rng.randf_range(0.1,0.22)),_pick(["b23a2b","4a6f8f","d6b862","efe8d8","3d5a7a"]),Vector3(0,rng.randf()*TAU,0))
			colors = ["486981","8a5a48","c9b98e"]; size = Vector2(0.06,0.05); count = 2
		"shavings":
			# 刨花: pale curls of wood off a coffin maker's plane.
			for i: int in 6:
				s.tilted_box(parent,at+Vector3(_jitter(0.22),0.02,_jitter(0.22)),Vector3(0.05,0.035,0.1),_pick(["e0c89a","d4b888","ead4a8"]),Vector3(rng.randf_range(-0.5,0.5),rng.randf()*TAU,rng.randf_range(-0.5,0.5)))
			colors = ["d4b888","c9ad7c"]; size = Vector2(0.08,0.04); count = 2
		_: return
	for i: int in count:
		s.tilted_box(parent,at+Vector3(_jitter(0.24),0.008+i*0.0004,_jitter(0.24)),Vector3(size.x*rng.randf_range(0.7,1.3),0.01,size.y*rng.randf_range(0.7,1.3)),_pick(colors),Vector3(0,rng.randf()*TAU,0))
