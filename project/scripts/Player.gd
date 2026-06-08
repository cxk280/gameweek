extends Node2D
class_name Player
## A remote player (ghost): self-interpolates toward its last synced position and picks an
## animation from the resulting motion. Only the owning client simulates real physics; here
## we just smooth + animate the synced transform.

var target := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var label: Label = $Label


func setup(pname: String, _color: Color, char_id: String) -> void:
	sprite.sprite_frames = SpriteFactory.make_sprite_frames(CharacterArt.get_char(char_id))
	sprite.play("run")
	label.text = pname


func _process(delta: float) -> void:
	var prev := position
	position = position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
	var v := (position - prev) / maxf(delta, 0.0001)
	if absf(v.x) > 12.0:
		sprite.flip_h = v.x < 0.0
	if v.y < -45.0:
		sprite.play("jump")
	elif absf(v.x) > 20.0:
		sprite.play("run")
	else:
		sprite.play("idle")
