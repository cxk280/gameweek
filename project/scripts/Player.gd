extends Node2D
class_name Player
## A single player's avatar (spine = a labeled square). Remote players are moved by
## Main toward `target`; the local player is positioned directly from input.

var target := Vector2.ZERO

@onready var rect: ColorRect = $Rect
@onready var ring: ColorRect = $Ring
@onready var label: Label = $Label


func setup(pname: String, color: Color, is_local: bool) -> void:
	rect.color = color
	label.text = ("▶ " + pname) if is_local else pname
	# White ring behind the square marks "you".
	ring.visible = is_local
