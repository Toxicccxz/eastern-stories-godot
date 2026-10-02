class_name FamilyDefinition
extends RefCounted

## A family (门派) by its ES2 family_name. Characters keep the ID (FamilyState);
## NPC records name the family as their create_family() does.
var family_id: StringName
var display_name: String


func _init(p_family_id: StringName = &"", p_display_name: String = "") -> void:
	family_id = p_family_id
	display_name = p_display_name


static func from_record(reader: ContentRecordReader) -> FamilyDefinition:
	var definition := FamilyDefinition.new(StringName(reader.required_text("id")), reader.required_text("name"))
	reader.finish()
	return definition
