@tool
extends EditorPlugin

const WeightGeneratorDock = preload("res://tools/scripts/channel_noise_generator_ui.gd")
var dock

func _enter_tree():
	dock = WeightGeneratorDock.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	remove_control_from_docks(dock)
