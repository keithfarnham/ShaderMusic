extends Node2D

#spectrum analysis code from https://godotshaders.com/shader/spectrum-analyzer/

const VU_COUNT = 100 #match up this value with whatever VU_COUNT is in the shader
const FREQ_MAX = 10000.0
const MIN_DB = 60
const ANIMATION_SPEED = 0.1
const HEIGHT_SCALE = 100.0

@onready var sprite = $shader_sprite
@onready var audioStream = $AudioStreamPlayer
@onready var viewport = $SubViewport
var spectrum
var min_values = []
var max_values = []
var prevFrame : ImageTexture
var prevFrame2 : ImageTexture
var framesToSkip := 60
var framesWaited := 0
var prevVolume := 0.0
var startPlay := false
@export var previewMode := false

func _ready():
	if AudioServer.get_bus_effect_count(0) > 0:
		spectrum = AudioServer.get_bus_effect_instance(0, 0)
	else:
		print("No effects found on bus 0. Please add an effect.")
		spectrum = null
	min_values.resize(VU_COUNT)
	min_values.fill(0.0)
	max_values.resize(VU_COUNT)
	max_values.fill(0.0)
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(delta):
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
	sprite.get_material().set_shader_parameter("freq_data", fft)
	sprite.get_material().set_shader_parameter("previewMode", previewMode)
	
	var image = viewport.get_texture().get_image()
	var image_texture = ImageTexture.create_from_image(image)
	prevFrame2  = prevFrame
	framesWaited += 1
	if framesWaited >= framesToSkip:
		prevFrame = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		sprite.get_material().set_shader_parameter("prevFrame", prevFrame)
		sprite.get_material().set_shader_parameter("prevFrame2", prevFrame2)
		framesWaited = 0
	sprite.get_material().set_shader_parameter("framesWaited", framesWaited)
	sprite.get_material().set_shader_parameter("video", image_texture)
	if startPlay:
		#start playing audio a frame after reducing volume for previewMode
		audioStream.play()
		viewport.get_node("VideoStreamPlayer").play()
		startPlay = false
	

func _on_audio_start_timer_timeout():
	if previewMode:
		prevVolume = audioStream.volume_linear
		audioStream.volume_linear = 0.0
		startPlay = true
	else:
		audioStream.play()
		viewport.get_node("VideoStreamPlayer").play()


func _on_ok_110_bpm_focus_entered():
	audioStream.volume_linear = prevVolume


func _on_ok_110_bpm_focus_exited():
	audioStream.volume_linear = 0.0
