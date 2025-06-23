extends Control

@onready var shader = $"../shader_sprite"

func _ready():
	pass

func _on_raymod_y_drag_ended(value_changed):
	var rayDirMod = shader.material.get_shader_parameter("rayDirMod")
	rayDirMod.y = $HBoxContainer/RayMod_y/raymod_y.value
	shader.material.set_shader_parameter("rayDirMod", rayDirMod) 

func _on_raymod_x_drag_ended(value_changed):
	var rayDirMod = shader.material.get_shader_parameter("rayDirMod")
	rayDirMod.x = $HBoxContainer/RayMod_x/raymod_x.value
	shader.material.set_shader_parameter("rayDirMod", rayDirMod) 

func _on_raymod_z_drag_ended(value_changed):
	var rayDirMod = shader.material.get_shader_parameter("rayDirMod")
	rayDirMod.z = $HBoxContainer/RayMod_z/raymod_z.value
	shader.material.set_shader_parameter("rayDirMod", rayDirMod) 


func _on_palette_1_red_drag_ended(value_changed):
	var color = shader.material.get_shader_parameter("paletteColor1")
	color.x = $HBoxContainer/Palette1_red/Palette1_red.value
	shader.material.set_shader_parameter("paletteColor1", color)

func _on_palette_1_green_drag_ended(value_changed):
	var color = shader.material.get_shader_parameter("paletteColor1")
	color.y = $HBoxContainer/Palette1_green/Palette1_green.value
	shader.material.set_shader_parameter("paletteColor1", color)

func _on_palette_1_blue_drag_ended(value_changed):
	var color = shader.material.get_shader_parameter("paletteColor1")
	color.z = $HBoxContainer/Palette1_blue/Palette1_blue.value
	shader.material.set_shader_parameter("paletteColor1", color)


func _on_palette_2_red_drag_ended(value_changed):
	var color = shader.material.get_shader_parameter("paletteColor2")
	color.x = $HBoxContainer/Palette2_red/Palette2_red.value
	shader.material.set_shader_parameter("paletteColor2", color)


func _on_palette_2_green_drag_ended(value_changed):
	var color = shader.material.get_shader_parameter("paletteColor2")
	color.y = $HBoxContainer/Palette2_green/Palette2_green.value
	shader.material.set_shader_parameter("paletteColor2", color)


func _on_palette_2_blue_drag_ended(value_changed):
	var color = shader.material.get_shader_parameter("paletteColor2")
	color.z = $HBoxContainer/Palette2_red/Palette2_red.value
	shader.material.set_shader_parameter("paletteColor2", color)
