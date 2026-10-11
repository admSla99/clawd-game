extends Control

## One button per level in levels/index.json; a click starts scenes/main.tscn on that level.

@onready var list: GridContainer = %Levels


func _ready() -> void:
	Sound.play_music("map")
	for level in JSON.parse_string(FileAccess.get_file_as_string(Main.LEVELS_INDEX)):
		var button := Button.new()
		button.name = level.id
		button.text = "%s\n%s" % [level.id, level.name]
		button.pressed.connect(start.bind(level.id))
		list.add_child(button)
	list.get_child(0).grab_focus()


func start(id: String) -> void:
	Sound.play("confirm")
	Main.start_level = id
	get_tree().change_scene_to_file("res://scenes/main.tscn")
