class_name VendorDefinition
extends RefCounted

## feature/vendor.c "vendor_goods": goods key -> item sold. The price is the
## item's own value, so it is not repeated here, unless the vendor's own
## buy_object() asks another one (`price`, e.g. d/snow/npc/smith.c).
var _vendor_id: StringName
var _legacy_source_path: String
var _goods_keys: Array[String] = []
var _goods: Dictionary[String, StringName] = {}
var _prices: Dictionary[String, int] = {}

var vendor_id: StringName:
	get: return _vendor_id
var legacy_source_path: String:
	get: return _legacy_source_path


static func from_record(reader: ContentRecordReader) -> VendorDefinition:
	var definition: VendorDefinition = VendorDefinition.new()
	definition._vendor_id = StringName(reader.required_text("id"))
	definition._legacy_source_path = reader.required_text("legacy_source")
	for goods: ContentRecordReader in reader.children("goods"):
		var key: String = goods.required_text("key")
		var item_id: String = goods.required_text("item")
		var has_price: bool = goods.has("price")
		var price: int = goods.integer("price")
		goods.finish()
		if definition._goods.has(key):
			goods.fail("key", "duplicate goods key '%s'" % key)
			continue
		# buy.c: a price below 1 means the owner will not trade.
		if has_price and price < 1:
			goods.fail("price", "must be at least 1")
			continue
		definition._goods_keys.append(key)
		definition._goods[key] = StringName(item_id)
		if has_price:
			definition._prices[key] = price
	if definition._goods_keys.is_empty():
		reader.fail("goods", "needs at least one entry")
	reader.finish()
	return definition


## Goods keys in authored order.
func goods_keys() -> Array[String]:
	return _goods_keys.duplicate()


## Empty when the vendor does not sell `key`.
func item_definition_id(key: String) -> StringName:
	return _goods.get(key, &"")


## buy.c trades `key`: goods, not money, priced 1 or more (below 1 the owner will not).
func sells(key: String, content: ItemContentDefinition) -> bool:
	return content != null and content.is_valid() and content.currency_definition() == null and price(key, content) >= 1


## What buy.c charges for `key`: the vendor's own price, else the item's value.
func price(key: String, content: ItemContentDefinition) -> int:
	if _prices.has(key):
		return _prices[key]
	return 0 if content == null else content.value
