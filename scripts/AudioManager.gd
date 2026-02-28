extends Node

# AudioManager — procedural sound effects singleton

var _sfx_player: AudioStreamPlayer
var _muted: bool = false
var _volume_db: float = 0.0

func _ready():
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			_muted = !_muted
			AudioServer.set_bus_mute(0, _muted)

func play_sfx(sfx_name: String):
	if _muted:
		return
	var stream = _generate_sfx(sfx_name)
	if stream:
		_sfx_player.stream = stream
		_sfx_player.play()

func _generate_sfx(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"feed":
			return _make_tone_sequence([440, 554, 659], 0.08)
		"heal":
			return _make_tone_sequence([523, 659, 784], 0.12)
		"play":
			return _make_tone_sequence([392, 523, 392, 523], 0.06)
		"coin":
			return _make_tone_sequence([880, 1108], 0.06)
		"menu_navigate":
			return _make_tone_sequence([600], 0.03)
		"menu_select":
			return _make_tone_sequence([523, 784], 0.08)
		"match":
			return _make_tone_sequence([659, 784], 0.08)
		"mismatch":
			return _make_tone_sequence([330, 262], 0.1)
		"win":
			return _make_tone_sequence([523, 659, 784, 1047], 0.12)
		_:
			return null

func _make_tone_sequence(frequencies: Array, note_duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples_per_note: int = int(sample_rate * note_duration)
	var total_samples: int = samples_per_note * frequencies.size()

	var audio = AudioStreamWAV.new()
	audio.mix_rate = sample_rate
	audio.format = AudioStreamWAV.FORMAT_8_BITS

	var data = PackedByteArray()
	data.resize(total_samples)

	for n in range(frequencies.size()):
		var freq: float = frequencies[n]
		for i in range(samples_per_note):
			var t: float = float(i) / sample_rate
			var envelope: float = 1.0 - (float(i) / samples_per_note)
			envelope = envelope * envelope  # quadratic decay
			var sample_val: float = sin(t * freq * TAU) * envelope * 0.4
			var byte_val: int = clampi(int((sample_val + 0.5) * 255), 0, 255)
			data[n * samples_per_note + i] = byte_val

	audio.data = data
	return audio
