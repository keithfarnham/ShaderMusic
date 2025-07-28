extends Control

@onready var loadBar = $Panel/loadBar as TextureProgressBar
@onready var buttonGrid = $"../ButtonsPanelContainer/ButtonsScrollContainer/ButtonsGridContainer" as GridContainer

const WAIT_TIME := 5.0

var waited := 0.0
#TODO find a solid way to check that all the shaders I need have compiled and are cached
#func load_shaders():
	##iterate through each shader check for resourceloader has_cached 
	#var allCached := true
	#var numCached := 0
	#for button in buttonGrid.get_children():
		#var shaderScene = button.find_child("SubViewport").find_child("*_scene")
		#if button.name == "avoidthevoid":
			#button.print_tree_pretty()
			#button.find_child("SubViewport").print_tree_pretty()
			#button.find_child("SubViewport").find_child("*_scene").print_tree_pretty()
			#
		#if ResourceLoader.has_cached(shaderScene.get_path()):
			#print(button.name + " is cached")
			#numCached += 1
		#else:
			#allCached = false
			#var sprite = shaderScene.find_child("shader_sprite") as Sprite2D
			#var shaderMaterial = sprite.material as ShaderMaterial
			#var shader = shaderMaterial.shader as Shader
			#print("sprite = " + str(sprite.name) + " material = " + str(shaderMaterial.resource_path) + " and shader = " + str(shader.resource_path))
			#print(button.name + " not cached, loading shader " + shader.resource_path)
			#ResourceLoader.load(shader.resource_path)
	#
	#print("loading percentage " + str(numCached / buttonGrid.get_child_count()) + " = " + str(numCached) + "/" + str(buttonGrid.get_child_count()))
	#loadBar.value = float(numCached / buttonGrid.get_child_count())
	#return allCached
	
func _process(delta):
	waited += delta
	loadBar.value = waited/WAIT_TIME * 100.0
	if waited >= WAIT_TIME:#$load_shaders(): for now this is just a timed wait to allow shaders a chance to load
		#print("all cached, removing loadscreen")
		visible = false
		queue_free()
