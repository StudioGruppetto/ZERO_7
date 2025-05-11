extends Node2D

@onready var panel = $"../CanvasLayer/Panel"
@onready var quit_button = panel.get_node("Button")
@onready var label = panel.get_node("Label")

func _ready():
	panel.visible = false
	connect("body_entered", Callable(self, "_on_body_entered"))
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_body_entered(body):
	if body.name == "Player":  # Adjust this to match your player's node name
		panel.visible = true
		label.text = "Game is finished"

func _on_quit_button_pressed():
	get_tree().quit()
