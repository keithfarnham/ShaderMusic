extends SubViewportContainer

#spectrum analysis code from https://godotshaders.com/shader/spectrum-analyzer/

const VU_COUNT = 20 #match up this value with whatever VU_COUNT is in the shader
const FREQ_MAX = 10000.0
const MIN_DB = 100.0
const ANIMATION_SPEED = 0.1
const HEIGHT_SCALE = 100.0
const BPM = 79.0
const MS_PER_BEAT = 60000.0 / BPM
const MS_PER_MEASURE = MS_PER_BEAT * 4 #song is 4/4
const VIDEO_MODE = false
const SONG_DURATION = 161.0 #155 + 6sec delay
const SONG2_DURATION = 124.0

#@onready var grassMaterial = $mainview/Node2D/grass_sprite.material
@onready var backgroundMaterial = $mainview/Node2D/background_sprite.material
@onready var ditherMaterial = $ditherfilter_sprite.material
@onready var audioStream = $mainview/Node2D/AudioStreamPlayer
@onready var audioStream2 = $mainview/Node2D/AudioStreamPlayer2
@onready var mainViewport = $mainview
@onready var video1Viewport = $mainview/Node2D/Video1SubViewport
@onready var video2Viewport = $mainview/Node2D/Video2SubViewport

var spectrum
var min_values = []
var max_values = []
var prevFrame : ImageTexture
var prevFrame2 : ImageTexture
var msWaited := 0.0
var prevVolume := 0.0
var visibleInScroll := false
var part2 := true
@export var previewMode := false

func set_preview_mode(setPreview : bool):
	previewMode = setPreview
	backgroundMaterial.set_shader_parameter("previewMode", previewMode)
	ditherMaterial.set_shader_parameter("previewMode", previewMode)

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
	ditherMaterial.set_shader_parameter("songDuration", SONG_DURATION)
	backgroundMaterial.set_shader_parameter("part2", part2)
	ditherMaterial.set_shader_parameter("part2", part2)

	if previewMode:
		prevVolume = audioStream.volume_linear
		audioStream.volume_linear = 0.0
		audioStream2.volume_linear = 0.0
		call_deferred("_start_audio")
	
func _start_audio():
	audioStream.play()

func _process(delta):
	var prevVisibleInScroll = visibleInScroll
	visibleInScroll = true if ( VIDEO_MODE or (global_position.y > -488.0 and global_position.y < 900.0) and (Data.currentFullscreen == null or Data.currentFullscreen.name == name) ) else false
	if prevVisibleInScroll != visibleInScroll:
		backgroundMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
		ditherMaterial.set_shader_parameter("visibleInScroll", visibleInScroll)
	
	if previewMode or !visibleInScroll:
		$ditherfilter_sprite.visible = false
		return
	
	$ditherfilter_sprite.visible = true
	
	var mainImage = mainViewport.get_texture().get_image()
	var mainImage_texture = ImageTexture.create_from_image(mainImage)
	ditherMaterial.set_shader_parameter("mainImage", mainImage_texture)

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
		fft.append(lerp(min_values[i], max_values[i], ANIMATION_SPEED) / 10.0)

	backgroundMaterial.set_shader_parameter("freq_data", fft)

	if !part2:
		var vidImage = video1Viewport.get_texture().get_image()
		var vidImage_texture = ImageTexture.create_from_image(vidImage)
		ditherMaterial.set_shader_parameter("vid1Image", vidImage_texture)
		vidImage = video2Viewport.get_texture().get_image()
		vidImage_texture = ImageTexture.create_from_image(vidImage)
		ditherMaterial.set_shader_parameter("vid2Image", vidImage_texture)

func _on_audio_start_timer_timeout():
	if VIDEO_MODE:
		audioStream.play()

func _on_lostinspace_23_mouse_entered():
	previewMode = false
	backgroundMaterial.set_shader_parameter("previewMode", previewMode)
	ditherMaterial.set_shader_parameter("previewMode", previewMode)
	audioStream.volume_linear = prevVolume
	audioStream2.volume_linear = prevVolume

func _on_lostinspace_23_mouse_exited():
	previewMode = true
	backgroundMaterial.set_shader_parameter("previewMode", previewMode)
	ditherMaterial.set_shader_parameter("previewMode", previewMode)
	audioStream.volume_linear = 0.0
	audioStream2.volume_linear = 0.0

func _on_audio_stream_player_finished():
	#start the second song
	part2 = false
	backgroundMaterial.set_shader_parameter("part2", part2)
	ditherMaterial.set_shader_parameter("part2", part2)
	$Title.text = "LOST IN SPACE - PART 3"
	audioStream2.play()
	video1Viewport.get_node("Video1StreamPlayer").play()
	video2Viewport.get_node("Video2StreamPlayer").play()
	ditherMaterial.set_shader_parameter("songDuration", SONG2_DURATION)

func _on_audio_stream_player_2_finished():
	part2 = true
	backgroundMaterial.set_shader_parameter("part2", part2)
	ditherMaterial.set_shader_parameter("part2", part2)
	$Title.text = "LOST IN SPACE - PART 2"
	audioStream.play()
	video1Viewport.get_node("Video1StreamPlayer").stop()
	video2Viewport.get_node("Video2StreamPlayer").stop()
	ditherMaterial.set_shader_parameter("songDuration", SONG_DURATION)
