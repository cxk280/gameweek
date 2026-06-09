extends Node
## Autoload "Sfx" — tiny pooled sound player for the procedural chiptune SFX.
## No-ops safely on the headless server (no audio device).

const NAMES := ["jump", "dash", "land", "checkpoint", "beep", "go", "finish"]
const POOL := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _idx := 0


func _ready() -> void:
	for n in NAMES:
		var s := load("res://audio/%s.wav" % n)
		if s != null:
			_streams[n] = s
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String, volume_db := -6.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
