class_name PlayerItemContentDefinitions
extends RefCounted

## Display metadata for the already supported public item catalog. All values
## and equipment definitions still come from the existing authored definitions.
static func content(id: StringName) -> OldPineItemContentDefinition:
	var existing := OldPineItemContentDefinitions.content_by_id(id)
	if existing != null: return existing
	if id == SourcePlayerCloth.DEFINITION_ID:
		return OldPineItemContentDefinition.new(id, SourcePlayerCloth.DISPLAY_NAME,
			"一件普通的粗布衣服，不值什么钱。", OldPineItemContentDefinitions.CATEGORY_ARMOR,
			SourcePlayerCloth.OWN_WEIGHT, &"", 0, false, false, false, 0, 0,
			[SourcePlayerCloth.LEGACY_SOURCE_PATH], SourcePlayerCloth.armor_definition())
	if id == SourceDumpling.DEFINITION_ID:
		return OldPineItemContentDefinition.new(id, SourceDumpling.DISPLAY_NAME,
			"一个香喷喷、热腾腾的大包子。", &"food", SourceDumpling.OWN_WEIGHT,
			&"", 0, false, false, false, 0, 0, [SourceDumpling.LEGACY_SOURCE_PATH])
	if id == SourceWineskin.DEFINITION_ID:
		return OldPineItemContentDefinition.new(id, SourceWineskin.DISPLAY_NAME,
			"一个牛皮缝的大酒袋，大概装得八、九升的酒。", &"liquid", SourceWineskin.OWN_WEIGHT,
			&"", 0, false, false, false, 0, 0, [SourceWineskin.LEGACY_SOURCE_PATH])
	var source: GDScript = SourceCurrencyDefinitions.source(SourceCurrencyDefinitions.identify(id))
	if source != null:
		return OldPineItemContentDefinition.new(id, source.DISPLAY_NAME, source.DISPLAY_NAME,
			OldPineItemContentDefinitions.CATEGORY_CURRENCY, source.BASE_WEIGHT,
			&"", 0, false, false, true, source.BASE_WEIGHT, source.BASE_VALUE, [source.LEGACY_SOURCE_PATH])
	return null
