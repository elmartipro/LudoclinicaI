extends MarginContainer

func _ready():
	# Example: 20px horizontal padding
	add_theme_constant_override("margin_left", 20)
	add_theme_constant_override("margin_right", 20)
