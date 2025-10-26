extends PanelContainer

# Animated rainbow border for dialog boxes
# Creates a "snake" effect by cycling through rainbow colors

var rainbow_time: float = 0.0
var rainbow_colors = [
	Color(1, 0, 0, 1),      # Red
	Color(1, 0.5, 0, 1),    # Orange
	Color(1, 1, 0, 1),      # Yellow
	Color(0, 1, 0, 1),      # Green
	Color(0, 1, 1, 1),      # Cyan
	Color(0, 0, 1, 1),      # Blue
	Color(0.56, 0, 1, 1)    # Violet
]

func _process(delta):
	# Animate rainbow border
	rainbow_time += delta * 2.0  # Speed of color cycling
	if rainbow_time >= rainbow_colors.size():
		rainbow_time = 0.0

	var style = get_theme_stylebox("panel")
	if style and style is StyleBoxFlat:
		var color_index = int(rainbow_time)
		var next_index = (color_index + 1) % rainbow_colors.size()
		var t = rainbow_time - floor(rainbow_time)
		style.border_color = rainbow_colors[color_index].lerp(rainbow_colors[next_index], t)
