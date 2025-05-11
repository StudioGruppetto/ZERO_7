extends Node

# Player tool state
var player_has_tool := false
var current_tool_type := ""  # Store the type/name of tool

var player_in_hiding_area: bool = false
var guard_leaving_timer_active: bool = false
var player_is_hidden: bool = false
var guard_position: String = "left" # Can be "left" or "right"
var guard_caught_player: bool = false

var player_in_top_hiding_area: bool = false
var player_in_bottom_hiding_area: bool = false
# Guard leaving timer states
var top_floor_guard_leaving_timer_active: bool = false
var bottom_floor_guard_leaving_timer_active: bool = false

func _ready():
	# For testing: Force player to start with a tool
	set_player_tool("Wrench")
# Call this when player picks up a tool
func set_player_tool(tool_name: String):
	player_has_tool = true
	current_tool_type = tool_name
	print("GameState: Player now has tool: ", tool_name)

# Call this when player drops the tool
func clear_player_tool():
	player_has_tool = false
	current_tool_type = ""
	print("GameState: Player no longer has tool")
