extends Node2D

const TARGET_SCENE_PATH = "res://Scenes/L1S2.tscn"
var time_left := 10.0  # countdown in seconds

@onready var countdown_label: RichTextLabel = $Panel/CountDownTimer

func _ready():
	update_countdown_label()
	set_process(true)

func _process(delta):
	time_left -= delta
	if time_left > 0:
		update_countdown_label()
	else:
		countdown_label.text = "[center][color=red]0[/color][/center]"
		get_tree().change_scene_to_file(TARGET_SCENE_PATH)
		set_process(false)

func update_countdown_label():
	var seconds = round(time_left)
	countdown_label.text = "[center][font_size=30][color=red]" + str(seconds) + "[/color][/font_size][/center]"
