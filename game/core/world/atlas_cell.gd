class_name AtlasCell
extends RefCounted

## One place on the 地图 page (data/common/atlas.json; DECISIONS「总图」): the map that stands
## for it, its name and where it lies on the 沙盘, in world units east and south of the 沙盘's
## origin. The maps with no row of their own are folded into the nearest one (AtlasTable).
var _map_id: StringName
var _name: String
var _at: Vector2

var map_id: StringName:
	get: return _map_id
var name: String:
	get: return _name
var at: Vector2:
	get: return _at


static func from_record(reader: ContentRecordReader) -> AtlasCell:
	var cell := AtlasCell.new()
	cell._map_id = StringName(reader.required_text("map"))
	cell._name = reader.required_text("name")
	cell._at = Vector2(reader.required_integer("x"), reader.required_integer("y"))
	reader.finish()
	return cell
