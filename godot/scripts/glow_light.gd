class_name GlowLight
extends Node3D

## A warm point light for the pixel shaders (no Godot light): Main collects the visible ones in the
## group "lights" every frame and passes the nearest to Level.set_lights(). The terrain lights the pixels
## within `radius` metres in four discrete steps.

@export var radius := 3.0
@export var energy := 1.0


func _enter_tree() -> void:
	add_to_group("lights")
