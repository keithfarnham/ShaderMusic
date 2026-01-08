extends Node2D

#spectrum analysis code from https://godotshaders.com/shader/spectrum-analyzer/

const VU_COUNT = 1 #match up this value with whatever VU_COUNT is in the shader
const FREQ_MAX = 11050.0
const MIN_DB = 60
const ANIMATION_SPEED = 0.1
const HEIGHT_SCALE = 8.0
const VIDEO_MODE = false

@onready var sprite = $shader_sprite
@onready var spriteMaterial = $shader_sprite.material
@onready var audioStream = $AudioStreamPlayer

var spectrum
var min_values = []
var max_values = []
var prevFrame : ImageTexture
var prevFrame2 : ImageTexture
var framesToSkip := 60
var framesWaited := 0
var prevVolume = 0.0
var visibleInScroll := false
@export var previewMode := false

func set_preview_mode(setPreview : bool):
	previewMode = setPreview
	spriteMaterial.set_shader_parameter("previewMode", previewMode)

func _ready():
	var busIndex = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(busIndex) > 0:
		spectrum = AudioServer.get_bus_effect_instance(busIndex, 0)
	else:
		print("No effects found on bus 0. Please add an effect.")
		spectrum = null
	min_values.resize(VU_COUNT)
	min_values.fill(0.0)
	max_values.resize(VU_COUNT)
	max_values.fill(0.0)

	if previewMode:
		prevVolume = audioStream.volume_linear
		audioStream.volume_linear = 0.0
		call_deferred("_start_audio")

func _start_audio():
	audioStream.play()

func _process(delta):
	var prevVisibleInScroll = visibleInScroll
	visibleInScroll = true if (global_position.y > -488.0 and global_position.y < 900.0) and (Data.currentFullscreen == null or Data.currentFullscreen.name == name) else false
	if prevVisibleInScroll != visibleInScroll:
		spriteMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
	
	if previewMode or !visibleInScroll:
		return
	
	var prev_hz = 0
	var data = []
	for i in range(1, VU_COUNT + 1):
		var hz = i * FREQ_MAX / VU_COUNT
		var f = spectrum.get_magnitude_for_frequency_range(prev_hz, hz)
		var energy = clamp((MIN_DB + linear_to_db(f.length())) / MIN_DB, 0.0, 1.0)
		data.append(energy * HEIGHT_SCALE)
		prev_hz = hz
	for i in range(VU_COUNT):
		if data[i] > max_values[i]:
			max_values[i] = data[i]
		else:
			max_values[i] = lerp(max_values[i], data[i], ANIMATION_SPEED)
		if data[i] <= 0.0:
			min_values[i] = lerp(min_values[i], 0.0, ANIMATION_SPEED)
	var fft = []
	for i in range(VU_COUNT):
		fft.append(lerp(min_values[i], max_values[i], ANIMATION_SPEED))
	spriteMaterial.set_shader_parameter("freq_data", fft)

func _on_audio_start_timer_timeout():
	if VIDEO_MODE:
		audioStream.play()

func _on_driftintothesun_mouse_entered():
	previewMode = false
	audioStream.volume_linear = prevVolume

func _on_driftintothesun_mouse_exited():
	previewMode = true
	audioStream.volume_linear = 0.0
