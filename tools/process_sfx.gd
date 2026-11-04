extends SceneTree
## Godot port of the `sfx` branch of tools/process_audio.py for machines without Python and GStreamer:
## decodes an AI sound (mp3 or ogg; Godot cannot read flac), mixes to mono 44.1 kHz, trims leading and trailing
## silence (-48 dB below peak, 2 ms windows), caps the length, fades in 2 ms and out 20-80 ms, normalizes the peak
## to -3 dBFS and writes a 16-bit wav. Prints one JSON line like process_audio.py.
## Run: tools/godot.sh --headless --path . -s res://tools/process_sfx.gd -- <src.mp3|ogg> <out.wav> [--max=1.0]

const SR := 44100
const PEAK_DB := -3.0
const SILENCE_DB := -48.0
const CHUNK := 4096


func _initialize() -> void:
	var paths: Array[String] = []
	var max_sec := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--max="):
			max_sec = float(a.substr(6))
		else:
			paths.append(a)
	if paths.size() != 2:
		push_error("Cần <src.mp3|ogg> <out.wav>")
		quit(1)
		return
	var stream: AudioStream = null
	var src := _abs(paths[0])
	match src.get_extension().to_lower():
		"mp3":
			stream = AudioStreamMP3.load_from_file(src)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(src)
	if stream == null:
		push_error("Không đọc được " + paths[0])
		quit(1)
		return
	if int(AudioServer.get_mix_rate()) != SR:
		push_error("Cần mix rate %d, đang là %d" % [SR, AudioServer.get_mix_rate()])
		quit(1)
		return
	var s := _trim_silence(_decode_mono(stream))
	s.resize(mini(s.size(), int(SR * max_sec)))
	_fade(s, 0.002, minf(0.08, maxf(0.02, 0.25 * s.size() / SR)))
	var pk := _peak(s)
	var gain := pow(10.0, PEAK_DB / 20.0) / pk if pk > 0.0 else 1.0
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	var sum := 0.0
	for i in s.size():
		var v := clampi(int(s[i] * gain * 32768.0), -32768, 32767)
		data.encode_s16(i * 2, v)
		sum += float(v * v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	if wav.save_to_wav(_abs(paths[1])) != OK:
		push_error("Không ghi được " + paths[1])
		quit(1)
		return
	var rms := sqrt(sum / maxf(1.0, s.size())) / 32768.0
	print(JSON.stringify({"channels": 1, "seconds": snappedf(float(s.size()) / SR, 0.001),
		"peak_db": snappedf(_db(_peak(s) * gain), 0.01), "rms_db": snappedf(_db(rms), 0.01)}))
	quit(0)


func _decode_mono(stream: AudioStream) -> PackedFloat32Array:
	var pb := stream.instantiate_playback()
	pb.start(0.0)
	var total := int(ceil(stream.get_length() * SR))
	var out := PackedFloat32Array()
	while out.size() < total:
		var frames := pb.mix_audio(1.0, mini(CHUNK, total - out.size()))
		if frames.is_empty():
			break
		for f in frames:
			out.append((f.x + f.y) * 0.5)
	pb.stop()
	return out


@warning_ignore("integer_division")
func _trim_silence(s: PackedFloat32Array, pre_ms: float = 2.0, post_ms: float = 10.0) -> PackedFloat32Array:
	var thr := _peak(s) * pow(10.0, SILENCE_DB / 20.0)
	var win := int(SR * 0.002)
	var n := s.size()
	var first := 0
	var last := n
	for i in range(0, n, win):
		if _peak(s.slice(i, i + win)) > thr:
			first = i
			break
	for i in range(((n - 1) / win) * win, -1, -win):
		if _peak(s.slice(i, mini(n, i + win))) > thr:
			last = mini(n, i + win)
			break
	first = maxi(0, first - int(SR * pre_ms / 1000.0))
	last = mini(n, last + int(SR * post_ms / 1000.0))
	return s.slice(first, last)


func _fade(s: PackedFloat32Array, in_s: float, out_s: float) -> void:
	var n := s.size()
	var fi := mini(n, int(SR * in_s))
	var fo := mini(n, int(SR * out_s))
	for i in fi:
		s[i] *= sin(0.5 * PI * i / fi)
	for i in fo:
		s[n - fo + i] *= cos(0.5 * PI * i / fo)


func _peak(s: PackedFloat32Array) -> float:
	var m := 0.0
	for v in s:
		m = maxf(m, absf(v))
	return m


func _db(x: float) -> float:
	return 20.0 * log(x) / log(10.0) if x > 0.0 else -999.0


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p
