extends Node

# Minimal combat resolver for in-world random encounters.
# Keeps gameplay playable without needing a full combat UI.

func _ready() -> void:
	GameLog.info("CombatSys", "Ready")

func ensure_player_state_defaults() -> void:
	if not (Game.player_state is Dictionary):
		Game.player_state = {}
	if not Game.player_state.has("hp"):
		Game.player_state["hp"] = 10
	if not Game.player_state.has("max_hp"):
		Game.player_state["max_hp"] = 10
	if not Game.player_state.has("money"):
		Game.player_state["money"] = 0

func resolve_encounter(enemy_name: String, tier: int, context_region: String = "") -> Dictionary:
	ensure_player_state_defaults()
	var t := clampi(tier, 1, 5)
	var base_win := 0.62 - float(t - 1) * 0.10
	var bonus := 0.0
	# Small narrative bonuses from flags.
	if WorldFlags.get_bool("CHAPEL_BLESSING_ACCEPTED", false):
		bonus += 0.05
	if WorldFlags.get_bool("companion_lira", false):
		bonus += 0.04
	if WorldFlags.get_bool("hunter_companion", false):
		bonus += 0.04
	var win_chance := clampf(base_win + bonus, 0.15, 0.85)

	var roll := RNG.randf()
	var win := roll < win_chance
	var damage := 0
	var money_delta := 0
	if win:
		money_delta = 5 + RNG.randi_range(0, 7) + (t - 1) * 3
	else:
		damage = 1 + RNG.randi_range(0, 2) + (t - 1)

	var hp := int(Game.player_state.get("hp", 10))
	var max_hp := int(Game.player_state.get("max_hp", 10))
	if not win:
		hp -= damage
		Game.player_state["hp"] = hp
	else:
		Game.player_state["money"] = int(Game.player_state.get("money", 0)) + money_delta

	var defeated := hp <= 0
	if defeated:
		Game.player_state["hp"] = max_hp
		WorldFlags.set_flag("DEFEATED_ON_ROAD", true)
		if not context_region.is_empty():
			WorldFlags.set_flag("DEFEATED_REGION", context_region)
		# Soft fail: return player to a safe hub if available.
		if WorldSys != null and WorldSys.has_method("teleport_player_to_region"):
			WorldSys.teleport_player_to_region("village")

	return {
		"enemy": enemy_name,
		"tier": t,
		"roll": roll,
		"win": win,
		"damage": damage,
		"money": money_delta,
		"defeated": defeated
	}
