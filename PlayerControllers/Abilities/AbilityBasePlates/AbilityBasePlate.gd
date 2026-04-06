@abstract class_name Ability extends Node3D

var currently_active = false
@abstract func activate(delta, abilities : Array[Ability])

@export_group("Ability Mapping")
@export_enum(
	"None",
	# --- LETTERS ---
	"E", "Q", "F", "R",
	"G", "H", "V", "B", "N", "M", "T", "Y", "X", "C", "Z",
	# --- NUMBERS ---
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
	# --- MODIFIERS ---
	"Shift", "Ctrl", "Alt", "Space", "Tab", "CapsLock", "Enter",
	# --- UI & MISC ---
	"F1", "F2", "F3", "F4", "F5", "F6", "F12"
) var trigger_key: String = "None"
