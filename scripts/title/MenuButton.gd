extends Control

signal pressed

@onready var hitbox: Area2D = $HitBox
@onready var sprite: Sprite2D = $ButtonImage
@onready var anim: AnimationPlayer = $ButtonJiggle

func _ready():
	if hitbox:
		hitbox.input_pickable = true
		hitbox.input_event.connect(_on_input_event)
		hitbox.mouse_entered.connect(_on_mouse_entered)
		hitbox.mouse_exited.connect(_on_mouse_exited)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit()

func _on_mouse_entered():
	if anim and anim.has_animation("hover_jiggle"):  # Changed from "hover"
		anim.play("hover_jiggle")
	else:
		modulate = Color(1.2, 1.2, 1.2, 1.0)

func _on_mouse_exited():
	if anim:
		anim.stop()  # Stop whatever's playing
		if anim.has_animation("RESET"):
			anim.play("RESET")
		else:
			# Manual reset if no RESET animation
			sprite.rotation = 0
			sprite.scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
