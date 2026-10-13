extends RefCounted




const NOISE_MIX_RATE: = 22050




static func ensure_bus(bus_name: String, reverb_wet: float = 0.18, room_size: float = 0.4) -> int:
	var idx: = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	var reverb: = AudioEffectReverb.new()
	reverb.room_size = room_size
	reverb.damping = 0.45
	reverb.wet = reverb_wet
	reverb.dry = 1.0 - reverb_wet
	reverb.spread = 0.35
	AudioServer.add_bus_effect(idx, reverb)
	return idx



static func make_noise(amplitude: float = 0.08) -> AudioStreamWAV:
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	var seconds: = 2.0
	var sample_count: = int(seconds * NOISE_MIX_RATE)
	var data: = PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var s: = rng.randf_range(-1.0, 1.0) * amplitude
		var v: = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 255
		data[i * 2 + 1] = (v >> 8) & 255
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = NOISE_MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	return wav



static func add_noise(parent: Node, bus_name: String, volume_db: float, amplitude: float) -> AudioStreamPlayer:
	var p: = AudioStreamPlayer.new()
	p.name = "PSXNoise"
	p.bus = bus_name
	p.stream = make_noise(amplitude)
	p.volume_db = volume_db
	parent.add_child(p)
	return p
