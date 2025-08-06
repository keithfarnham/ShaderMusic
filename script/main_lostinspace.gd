extends SubViewportContainer

#spectrum analysis code from https://godotshaders.com/shader/spectrum-analyzer/

const VU_COUNT = 20 #match up this value with whatever VU_COUNT is in the shader
const FREQ_MAX = 10000.0
const MIN_DB = 100.0
const ANIMATION_SPEED = 0.1
const HEIGHT_SCALE = 100.0
const BPM = 77.0
const MS_PER_BEAT = 60000.0 / BPM
const MS_PER_MEASURE = MS_PER_BEAT * 3 #song is 3/4
const VIDEO_MODE = false
const SONG_DURATION = 161.0; #155sec song duration + 6sec delay

#@onready var sprite = $mainview/Node2D/shader_sprite
@onready var grassMaterial = $mainview/Node2D/grass_sprite.material
@onready var backgroundMaterial = $mainview/Node2D/background_sprite.material
@onready var sunMaterial = $mainview/Node2D/sun_sprite.material
@onready var ditherMaterial = $ditherfilter_sprite.material
@onready var audioStream = $mainview/Node2D/AudioStreamPlayer
@onready var mainViewport = $mainview

var spectrum
var min_values = []
var max_values = []
var prevFrame : ImageTexture
var prevFrame2 : ImageTexture
var msWaited := 0.0
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
	#spriteMaterial.set_shader_parameter("BPM", BPM);
	#spriteMaterial.set_shader_parameter("MS_PER_BEAT", MS_PER_BEAT);
	#spriteMaterial.set_shader_parameter("MS_PER_MEASURE", MS_PER_MEASURE);
	#spriteMaterial.set_shader_parameter("songDuration", SONG_DURATION)
	grassMaterial.set_shader_parameter("songDuration", SONG_DURATION)
	sunMaterial.set_shader_parameter("songDuration", SONG_DURATION)
	backgroundMaterial.set_shader_parameter("songDuration", SONG_DURATION)
	ditherMaterial.set_shader_parameter("songDuration", SONG_DURATION)

	if previewMode:
		prevVolume = audioStream.volume_linear
		audioStream.volume_linear = 0.0
		call_deferred("_start_audio")
	
func _start_audio():
	audioStream.play()
	#vidViewport.get_node("VideoStreamPlayer").play()

func _process(delta):
	visibleInScroll = true if ( VIDEO_MODE or (global_position.y > -488.0 and global_position.y < 900.0) and (Data.currentFullscreen == null or Data.currentFullscreen.name == name) ) else false
	ditherMaterial.set_shader_parameter("previewMode", previewMode)
	grassMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
	sunMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
	backgroundMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
	ditherMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
	var image = mainViewport.get_texture().get_image()
	var image_texture = ImageTexture.create_from_image(image)
	ditherMaterial.set_shader_parameter("video", image_texture)
	
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

	grassMaterial.set_shader_parameter("freq_data", fft)
	sunMaterial.set_shader_parameter("freq_data", fft)

func _on_audio_start_timer_timeout():
	if VIDEO_MODE:
		audioStream.play()

func _on_lostinspace1_mouse_entered():
	previewMode = false
	audioStream.volume_linear = prevVolume

func _on_lostinspace1_mouse_exited():
	previewMode = true
	audioStream.volume_linear = 0.0
