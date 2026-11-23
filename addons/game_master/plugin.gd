@tool
extends EditorPlugin
## Game Master: um dock à direita com as regras do jogo (addons/game_master/dock.gd).

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/game_master/dock.gd").new()
	dock.name = "Game Master"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	print("Game Master: dock carregado (%d parâmetros)" % (dock.cat.get("parametros", []) as Array).size())


func _exit_tree() -> void:
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()
