class_name ApplicationMessageCatalog
extends RefCounted

const MESSAGES: Dictionary[StringName, String] = {
	&"save.no_save": "没有找到存档。",
	&"save.continue_available": "有一份存档可以继续。",
	&"save.recovery_required": "主存档无法使用，但有可以恢复的存档。",
	&"save.unusable": "存档无法读取。",
	&"save.incompatible_development": "此存档来自不兼容的开发版本，请开始新游戏。",
	&"save.unsupported": "这份存档来自不支持的版本。",
	&"save.storage_failure": "现在无法检查存档。",
	&"operation.success": "操作完成。",
	&"operation.busy": "还有一项操作没有完成。",
	&"operation.session_failure": "无法开始这段旅程。",
	&"continue.restore_failure": "存档无法恢复。",
	&"continue.map_changed": "这份存档之后地图改过，存档时你站的地方现在站不了人，读不进来。",
	&"new_game.confirm": "手动存档不受影响；新角色第一次自动存档时会覆盖现在的自动存档。",
	&"slot.overwrite_confirm": "覆盖这一位的存档？",
	&"slot.load_confirm": "读取这份存档？上次存档之后的进度会丢失。",
	&"slot.autosave_confirm": "回到上次自动存档？这之后的进度都会丢失。",
	&"save.success": "已存档。",
	&"save.blocked.combat_or_action": "战斗中或动作还没完成时不能存档。",
	&"save.blocked.scene": "这段戏还没演完，看完再存档。",
	&"save.blocked.world_transition": "在两个地区之间移动时不能存档。",
	&"save.blocked.lifecycle": "角色的生死状态还在变化，暂时不能存档。",
	&"save.blocked.temporary_effect": "身上有无法保存的临时效果，暂时不能存档。",
	&"save.blocked.runtime_not_ready": "旅程还没准备好，暂时不能存档。",
	&"save.blocked.position": "这里不能存档，挪一步再试。",
	&"save.blocked.npc_working": "有人正在替你做的事还没完，等一会儿再存档。",
	&"save.capture_failure": "无法整理当前旅程以便存档。",
	&"save.write_failure": "存档无法写入。",
	&"return.confirm": "上次存档之后的进度可能会丢失。",
}
const FALLBACK: String = "操作无法完成。"


static func text_for(message_key: StringName) -> String:
	return TranslationServer.translate(MESSAGES.get(message_key, FALLBACK))
