extends SubViewportContainer

#spectrum analysis code from https://godotshaders.com/shader/spectrum-analyzer/

const VU_COUNT = 100 #match up this value with whatever VU_COUNT is in the shader
const FREQ_MAX = 10000.0
const MIN_DB = 60
const ANIMATION_SPEED = 0.1
const HEIGHT_SCALE = 100.0
const VIDEO_MODE = false

@onready var sprite = $mainview/Node2D/shader_sprite
@onready var spriteMaterial = $mainview/Node2D/shader_sprite.material
@onready var audioStream = $mainview/Node2D/AudioStreamPlayer
@onready var viewport = $mainview/Node2D/SubViewport as SubViewport
@onready var mainview = $mainview

var spectrum
var min_values = []
var max_values = []
var prevFrame : ImageTexture
var prevFrame2 : ImageTexture
var framesToSkip := 60
var framesWaited := 0
var prevVolume := 0.0
var visibleInScroll := false
@export var previewMode := false

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
	viewport.get_node("VideoStreamPlayer").play()

func _process(delta):
	visibleInScroll = true if (global_position.y > -488.0 and global_position.y < 900.0) and (Data.currentFullscreen == null or Data.currentFullscreen.name == name) else false
	spriteMaterial.set_shader_parameter("previewMode", previewMode)
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
	
	var image = viewport.get_texture().get_image()
	var image_texture = ImageTexture.create_from_image(image)
	prevFrame2  = prevFrame
	framesWaited += 1
	if framesWaited >= framesToSkip:
		prevFrame = ImageTexture.create_from_image(mainview.get_texture().get_image())
		spriteMaterial.set_shader_parameter("prevFrame", prevFrame)
		spriteMaterial.set_shader_parameter("prevFrame2", prevFrame2)
		framesWaited = 0
	spriteMaterial.set_shader_parameter("framesWaited", framesWaited)
	spriteMaterial.set_shader_parameter("video", image_texture)

func _on_audio_start_timer_timeout():
	if VIDEO_MODE:
		audioStream.play()
		viewport.get_node("VideoStreamPlayer").play()

func _on_foginthetv_mouse_entered():
	previewMode = false
	audioStream.volume_linear = prevVolume

func _on_foginthetv_mouse_exited():
	previewMode = true
	audioStream.volume_linear = 0.0
