class_name EncounterRuntime
extends RefCounted

# A tiny runtime for dynamic, random road encounters.
# DialogOverlay can open this via open_runtime().

var encounter_id: String = ""
var enemy_name: String = ""
var tier: int = 1
var region_id: String = ""

var _step: int = 0
var _resolved: bool = false
var _result: Dictionary = {}

func _init(_enemy_name: String = "Wanderer", _tier: int = 1, _region_id: String = "") -> void:
	enemy_name = _enemy_name
	tier = _tier
	region_id = _region_id
	encounter_id = "%s_t%d" % [enemy_name.to_lower().replace(" ", "_"), tier]

func is_finished() -> bool:
	return _resolved and _step >= 2

func get_speaker() -> String:
	if _step == 0:
		return "Roadside"
	if _step == 1:
		return enemy_name
	return "Aftermath"

func get_text() -> String:
	if _step == 0:
		return "A shape moves between broken trees. Not quite an ambush—more like a decision hunting for a body."
	if _step == 1 and not _resolved:
		return "%s steps into your path." % enemy_name
	# resolved
	if bool(_result.get("defeated", false)):
		return "Pain, then distance. You wake with your breath returned to you—somewhere safer."
	if bool(_result.get("win", false)):
		var m := int(_result.get("money", 0))
		return "You keep your footing. The road releases you. (+%d money)" % m
	var dmg := int(_result.get("damage", 0))
	return "You escape, but it costs you. (-%d HP)" % dmg

func get_choices() -> Array:
	if _step == 1 and not _resolved:
		return [
			{"text": "Fight", "kind": "fight"},
			{"text": "Flee", "kind": "flee"},
			{"text": "Talk your way out", "kind": "talk"}
		]
	return []

func choose(choice_index_1_based: int) -> bool:
	var choices := get_choices()
	if choices.is_empty():
		return false
	var i := choice_index_1_based - 1
	if i < 0 or i >= choices.size():
		return false
	var c: Dictionary = choices[i]
	var kind := str(c.get("kind", ""))
	match kind:
		"fight":
			_result = CombatSys.resolve_encounter(enemy_name, tier, region_id)
			_resolved = true
			_step = 2
			WorldFlags.set_flag("LAST_ENCOUNTER", enemy_name)
			WorldFlags.set_flag("LAST_ENCOUNTER_WON", bool(_result.get("win", false)))
			return true
		"flee":
			# Flee always works, sometimes costs HP.
			var took := RNG.randf() < 0.35 + float(tier - 1) * 0.10
			var dmg := 0
			if took:
				dmg = 1 + RNG.randi_range(0, 1) + (tier - 1)
				CombatSys.ensure_player_state_defaults()
				Game.player_state["hp"] = int(Game.player_state.get("hp", 10)) - dmg
				if int(Game.player_state["hp"]) <= 0:
					Game.player_state["hp"] = int(Game.player_state.get("max_hp", 10))
					if WorldSys != null and WorldSys.has_method("teleport_player_to_region"):
						WorldSys.teleport_player_to_region("village")
			_result = {"win": false, "damage": dmg, "money": 0, "defeated": false}
			_resolved = true
			_step = 2
			WorldFlags.set_flag("LAST_ENCOUNTER", enemy_name)
			WorldFlags.set_flag("LAST_ENCOUNTER_WON", false)
			return true
		"talk":
			# Talk works better with certain narrative flags.
			var chance := 0.40
			if WorldFlags.get_bool("HC_DISGUISED", false):
				chance += 0.15
			if WorldFlags.get_bool("VILLAGE_MET_ELDER", false):
				chance += 0.05
			if WorldFlags.get_bool("CHAPEL_BLESSING_ACCEPTED", false):
				chance += 0.05
			var ok := RNG.randf() < clampf(chance - float(tier - 1) * 0.07, 0.10, 0.75)
			if ok:
				_result = {"win": true, "damage": 0, "money": 0, "defeated": false}
				WorldFlags.set_flag("LAST_ENCOUNTER_TALKED_OUT", true)
			else:
				_result = CombatSys.resolve_encounter(enemy_name, tier, region_id)
			_resolved = true
			_step = 2
			WorldFlags.set_flag("LAST_ENCOUNTER", enemy_name)
			WorldFlags.set_flag("LAST_ENCOUNTER_WON", bool(_result.get("win", false)))
			return true
		_:
			return false

func advance() -> bool:
	if is_finished():
		return false
	_step += 1
	return true
