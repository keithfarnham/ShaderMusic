extends Node2D

@onready var buttonsPanel = $ButtonsPanelContainer
@onready var backButton = $BackButton as Button
@onready var fullPanel = $fullscreenPanel
@onready var backgroundTexture = $fullscreenPanel/background
@onready var splashPanel = $splash

var selectedButton
var currentFullscreen
var backgroundNode

func _on_back_button_pressed():
	if selectedButton == null or currentFullscreen == null:
		print("cached button/scene are null")
		return
	#buttonsPanel.get_tree().paused = false
	buttonsPanel.visible = true
	backButton.visible = false
	fullPanel.visible = false
	var audio = currentFullscreen.find_child("AudioStreamPlayer") as AudioStreamPlayer
	audio.volume_linear = 0.0
	currentFullscreen.previewMode = true
	currentFullscreen.reparent(selectedButton.get_node("SubViewport"))
	selectedButton = null
	currentFullscreen = null

func previewPressed(buttonPressed, shaderScene):
	buttonsPanel.visible = false
	backButton.visible = true
	fullPanel.visible = true
	selectedButton = buttonPressed
	shaderScene.reparent(fullPanel)
	#buttonsPanel.get_tree().paused = true
	currentFullscreen = shaderScene
	var audio = shaderScene.find_child("AudioStreamPlayer") as AudioStreamPlayer
	audio.volume_linear = shaderScene.prevVolume
	currentFullscreen.previewMode = false

func _on_start_pressed():
	splashPanel.visible = false
	splashPanel.queue_free()

func _on_mute_pressed():
	var busIndex = AudioServer.get_bus_index("Master")
	var isMute = AudioServer.is_bus_mute(busIndex)
	AudioServer.set_bus_mute(busIndex, !isMute)
	$Mute.text = "Unmute" if !isMute else "Mute"

func _on_driftintothesun_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/driftintothesun
	var scene = buttonNode.get_node("SubViewport/driftintothesun_scene")
	previewPressed(buttonNode, scene)

func _on_spydungeon_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/spydungeon
	var scene = buttonNode.get_node("SubViewport/spydungeon_scene")
	previewPressed(buttonNode, scene)

func _on_foginthetv_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/foginthetv
	var scene = buttonNode.get_node("SubViewport/foginthetv_scene")
	previewPressed(buttonNode, scene)

func _on_avoidthevoid_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/avoidthevoid
	var scene = buttonNode.get_node("SubViewport/avoidthevoid_scene")
	previewPressed(buttonNode, scene)

func _on_ok_110_bpm_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/ok110bpm
	var scene = buttonNode.get_node("SubViewport/ok110bpm_scene")
	previewPressed(buttonNode, scene)

func _on_scaryrobotnoise_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/scaryrobotnoise
	var scene = buttonNode.get_node("SubViewport/scaryrobotnoise_scene")
	previewPressed(buttonNode, scene)

func _on_simulatedspace_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/simulatedspace
	var scene = buttonNode.get_node("SubViewport/simulatedspace_scene")
	previewPressed(buttonNode, scene)

func _on_symbioteinmycomputer_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/symbioteinmycomputer
	var scene = buttonNode.get_node("SubViewport/symbiote_scene")
	previewPressed(buttonNode, scene)

func _on_spookybells_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/spookybells
	var scene = buttonNode.get_node("SubViewport/spookybells_scene")
	previewPressed(buttonNode, scene)

func _on_secretagent_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/secretagent
	var scene = buttonNode.get_node("SubViewport/secretagent_scene")
	previewPressed(buttonNode, scene)
	
func _on_darkalley_pressed():
	var buttonNode = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/darkalley
	var scene = buttonNode.get_node("SubViewport/darkalley_scene")
	previewPressed(buttonNode, scene)

func _on_151bpmsong_pressed():
	var buttonNode = $"ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/151bpmsong"
	var scene = buttonNode.get_node("SubViewport/151bpmsong_scene")
	previewPressed(buttonNode, scene)
	
func _on_rad_148_bpm_pressed():
	var buttonNode = $"ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/rad148bpm"
	var scene = buttonNode.get_node("SubViewport/rad148bpm_scene")
	previewPressed(buttonNode, scene)


##TODO fix background texture
#func _on_spydungeon_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/spydungeon/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_foginthetv_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/foginthetv/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_avoidthevoid_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/avoidthevoid/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_ok_110_bpm_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/ok110bpm/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_scaryrobotnoise_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/scaryrobotnoise/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_symbioteinmycomputer_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/symbioteinmycomputer/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_spookybells_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/spookybells/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_simulatedspace_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/simulatedspace/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_secretagent_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/secretagent/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_driftintothesun_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/driftintothesun/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_darkalley_mouse_entered():
	#var subviewport = $ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/darkalley/SubViewport as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_151bpmsong_mouse_entered():
	#var subviewport = $"ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/151bpmsong/SubViewport" as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
#
#func _on_rad_148_bpm_mouse_entered():
	#var subviewport = $"ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer/rad148bpm/SubViewport" as SubViewport
	#var viewport_texture = ViewportTexture.new()
	#viewport_texture.viewport_path = subviewport.get_path()
	#backgroundTexture.texture = viewport_texture
