extends Control

# ============================================================================
# BATTLE RESULTS - End-of-battle SUCCESS screen
# ============================================================================
# Shows detailed battle completion stats for SUCCESSFUL battles only:
# - Hit breakdown (PERFECT, GOOD, OKAY, MISS counts)
# - Total XP earned and awarded
# - Max combo achieved
# - Level up notifications
# - Battle name and "You did it!" message
#
# Connects to BattleManager.battle_completed signal
# NOTE: Battle FAILURE uses a separate simple dialog (BattleFailure.gd)
#
# SCENE STRUCTURE:
# BattleResults (Control) - this script
# └─ CanvasLayer (always on top)
#     └─ Panel (semi-transparent overlay)
#         └─ VBoxContainer
#             ├─ TitleLabel - "BATTLE COMPLETE!" or "BATTLE FAILED!"
#             ├─ StatsContainer - shows hit counts, combo, strength
#             ├─ LevelUpLabel - shows level up notification
#             └─ ButtonContainer - Continue, Restart, Quit buttons

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var title_label: Label = $CanvasLayer/Panel/VBoxContainer/TitleLabel
@onready var strength_earned_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/StrengthEarnedLabel
@onready var strength_awarded_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/StrengthAwardedLabel
@onready var max_combo_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/MaxComboLabel
@onready var perfect_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/PerfectLabel
@onready var good_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/GoodLabel
@onready var okay_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/OkayLabel
@onready var miss_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/MissLabel
@onready var level_up_label: Label = $CanvasLayer/Panel/VBoxContainer/LevelUpLabel
@onready var continue_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/ContinueButton
@onready var restart_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/RestartButton

# Sound effects
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var restart_sound: AudioStreamPlayer = $RestartSound
@onready var continue_sound: AudioStreamPlayer = $ContinueSound

var battle_results: Dictionary = {}
var fade_rect: ColorRect
var fireworks_layer: Node2D
var fireworks_timer: Timer
var is_showing_fireworks: bool = false

# Firework color palettes
var note_colors = [Color.CYAN, Color.MAGENTA, Color.YELLOW]
var rainbow_colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.PURPLE, Color.MAGENTA]

func _ready():
	# Start hidden - will only show when explicitly called
	visible = false
	if canvas_layer:
		canvas_layer.visible = false

	# Create fade overlay for scene transitions
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.z_index = 1000
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)

	# Create fireworks layer (between fade and canvas layer)
	fireworks_layer = Node2D.new()
	fireworks_layer.z_index = 50  # Behind canvas layer (100) but above fade
	add_child(fireworks_layer)

	# Create timer for spawning fireworks
	fireworks_timer = Timer.new()
	fireworks_timer.wait_time = randf_range(0.3, 0.8)  # Random interval
	fireworks_timer.timeout.connect(_spawn_firework)
	add_child(fireworks_timer)

	# DO NOT auto-connect to BattleManager signal
	# Results will be shown manually by the battle scene when appropriate

	# Connect buttons
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
		restart_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())

func _exit_tree():
	"""Clean up when scene is freed."""
	# Ensure we disconnect any lingering signal connections if they exist
	# (though we don't auto-connect anymore, this is a safety measure)
	if BattleManager and BattleManager.battle_completed.is_connected(Callable(self, "_on_battle_completed")):
		BattleManager.battle_completed.disconnect(Callable(self, "_on_battle_completed"))

func show_battle_results(results: Dictionary):
	"""Show battle results - called manually by battle scene at end."""
	battle_results = results
	show_results()

func show_results():
	"""Display the battle results for successful completion."""
	visible = true
	if canvas_layer:
		canvas_layer.visible = true

	# Start fireworks celebration!
	_start_fireworks()

	# Pause the game
	get_tree().paused = true

	# Update title - Always success (failure uses BattleFailure dialog)
	if title_label:
		title_label.text = "YOU DID IT!"
		title_label.modulate = Color.GREEN

	# Update stats - show "Earned X of Y" where Y is max possible
	var strength_awarded = battle_results.get("strength_awarded", 0)
	var strength_max_possible = battle_results.get("strength_max_possible", 0)

	if strength_earned_label:
		strength_earned_label.text = "Earned %d of %d Strength" % [strength_awarded, strength_max_possible]

	# Hide the redundant second label
	if strength_awarded_label:
		strength_awarded_label.visible = false

	if max_combo_label:
		max_combo_label.text = "Max Combo: %d" % battle_results.get("combo_max", 0)

	# Update hit breakdown
	var hit_counts = battle_results.get("hit_counts", {})
	if perfect_count_label:
		perfect_count_label.text = "PERFECT: %d" % hit_counts.get("PERFECT", 0)
	if good_count_label:
		good_count_label.text = "GOOD: %d" % hit_counts.get("GOOD", 0)
	if okay_count_label:
		okay_count_label.text = "OKAY: %d" % hit_counts.get("OKAY", 0)
	if miss_count_label:
		miss_count_label.text = "MISS: %d" % hit_counts.get("MISS", 0)

	# Check for level up (compare strength before and after)
	if level_up_label and GameManager:
		# The level up already happened in fade_to_title(), just check if we leveled
		# We can't easily track this without storing old level, so hide for now
		# User will see level up in future implementation
		level_up_label.visible = false

	# Hide restart button (only for success - failure has its own dialog)
	if restart_button:
		restart_button.visible = true

func _on_continue_pressed():
	"""Continue to next scene or return to title."""
	if continue_sound:
		continue_sound.play()

	# Fade to black then continue
	_fade_to_black()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	# For now, go to title. Later: navigate to overworld or next battle
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func _on_restart_pressed():
	"""Restart the battle."""
	if restart_sound:
		restart_sound.play()

	# Fade to black then restart
	_fade_to_black()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _start_fireworks():
	"""Start the fireworks celebration effect."""
	is_showing_fireworks = true
	if fireworks_timer:
		fireworks_timer.start()

func _stop_fireworks():
	"""Stop spawning new fireworks."""
	is_showing_fireworks = false
	if fireworks_timer:
		fireworks_timer.stop()

func _spawn_firework():
	"""Spawn a single firework that launches and explodes."""
	if not is_showing_fireworks:
		return

	# Randomize next firework spawn time - HALF the previous rate
	if fireworks_timer:
		fireworks_timer.wait_time = randf_range(0.4, 1.0)

	# Random launch position at bottom of screen
	var viewport_size = get_viewport().get_visible_rect().size
	var launch_x = randf_range(viewport_size.x * 0.15, viewport_size.x * 0.85)
	var launch_pos = Vector2(launch_x, viewport_size.y + 20)

	# Random target position (where firework will explode)
	var target_x = randf_range(viewport_size.x * 0.1, viewport_size.x * 0.9)
	var target_y = randf_range(viewport_size.y * 0.15, viewport_size.y * 0.65)
	var target_pos = Vector2(target_x, target_y)

	# Choose explosion type (3 types) and color palette FIRST so trail can match
	var explosion_type = randi() % 3  # 0=sunburst, 1=weeping willow, 2=chaos
	var use_rainbow = randf() > 0.5
	var color_palette = rainbow_colors if use_rainbow else note_colors
	var trail_color = color_palette[randi() % color_palette.size()]

	# Create thicker, colored trail particle for the ascending firework
	var trail = ColorRect.new()
	trail.size = Vector2(12, 12)  # Bigger trail
	trail.position = launch_pos
	trail.color = trail_color  # Colored to match explosion
	fireworks_layer.add_child(trail)

	# Animate firework to target position with arc
	var ascent_time = randf_range(0.7, 1.0)
	var tween = create_tween()
	tween.tween_property(trail, "position", target_pos, ascent_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# CRITICAL: Queue explosion callback AFTER trail reaches target position
	# This ensures fireworks ALWAYS explode at the right time
	tween.tween_callback(_create_firework_explosion.bind(target_pos, explosion_type, color_palette))

	# Fade out trail after explosion triggered
	tween.tween_property(trail, "modulate:a", 0.0, 0.1)
	tween.tween_callback(trail.queue_free)

func _create_firework_explosion(explosion_pos: Vector2, explosion_type: int, color_palette: Array):
	"""Create an explosion of particles at the given position with gravity."""
	# Vary size - some explosions are bigger than others
	var size_multiplier = randf_range(0.8, 1.5)

	# Number of particles varies by explosion type
	var particle_count = 0
	match explosion_type:
		0:  # Sunburst (perfectly even circular explosion)
			particle_count = int(60 * size_multiplier)
			_create_sunburst_explosion(explosion_pos, particle_count, color_palette, size_multiplier)
		1:  # Weeping Willow (drooping arms like the tree)
			particle_count = int(50 * size_multiplier)
			_create_weeping_willow_explosion(explosion_pos, particle_count, color_palette, size_multiplier)
		2:  # Chaos (varied length arms, mostly circular but irregular)
			particle_count = int(70 * size_multiplier)
			_create_chaos_explosion(explosion_pos, particle_count, color_palette, size_multiplier)

func _create_sunburst_explosion(explosion_pos: Vector2, count: int, colors: Array, size_mult: float):
	"""Create a perfectly even circular sunburst explosion with gravity."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8) * size_mult
		particle.position = explosion_pos
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Even circular distribution - all particles same speed
		var angle = (i / float(count)) * TAU
		var speed = 300 * size_mult  # Same speed for perfect circle
		var direction = Vector2(cos(angle), sin(angle))

		# Calculate trajectory with gravity
		var initial_velocity = direction * speed
		var explosion_time = 1.0
		var gravity = 400.0  # Gravity constant
		var mid_point = explosion_pos + initial_velocity * explosion_time
		var fall_distance = gravity * explosion_time * 0.5
		var end_point = Vector2(mid_point.x, mid_point.y + fall_distance)

		var tween = create_tween()
		# Explode outward
		tween.tween_property(particle, "position", mid_point, explosion_time).set_ease(Tween.EASE_OUT)
		# Fall with gravity
		tween.tween_property(particle, "position", end_point, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Fade during fall (more decay delay)
		tween.tween_property(particle, "modulate:a", 0.0, 1.2).set_delay(0.8)
		tween.tween_callback(particle.queue_free)

func _create_weeping_willow_explosion(explosion_pos: Vector2, count: int, colors: Array, size_mult: float):
	"""Create weeping willow explosion with drooping arms like the tree."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 14) * size_mult  # Elongated for willow effect
		particle.position = explosion_pos
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Create "arms" that droop - more upward angles, graceful arcs
		var angle = (i / float(count)) * TAU
		var upward_bias = -0.3  # Slight upward bias
		var direction = Vector2(cos(angle + upward_bias), sin(angle + upward_bias))
		var speed = randf_range(200, 350) * size_mult

		# Arc upward then droop down gracefully
		var initial_velocity = direction * speed
		var arc_time = 0.8
		var gravity = 500.0  # Stronger gravity for drooping effect
		var arc_peak = explosion_pos + initial_velocity * arc_time
		var droop_distance = gravity * 1.5  # Long droop
		var end_point = Vector2(arc_peak.x, arc_peak.y + droop_distance)

		var tween = create_tween()
		# Arc to peak
		tween.tween_property(particle, "position", arc_peak, arc_time).set_ease(Tween.EASE_OUT)
		# Droop down like willow branches
		tween.tween_property(particle, "position", end_point, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Long fade with decay delay
		tween.tween_property(particle, "modulate:a", 0.0, 1.5).set_delay(0.9)
		tween.tween_callback(particle.queue_free)

func _create_chaos_explosion(explosion_pos: Vector2, count: int, colors: Array, size_mult: float):
	"""Create chaotic explosion with varied arm lengths - mostly circular but irregular."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(7, 7) * size_mult
		particle.position = explosion_pos
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Irregular distribution - vary speeds significantly for chaos
		var angle = (i / float(count)) * TAU + randf_range(-0.2, 0.2)  # Add angle variation
		var speed = randf_range(150, 500) * size_mult  # HUGE speed variation for chaos
		var direction = Vector2(cos(angle), sin(angle))

		# Random trajectory with gravity
		var initial_velocity = direction * speed
		var explosion_time = randf_range(0.8, 1.3)  # Varied timing adds chaos
		var gravity = 450.0
		var mid_point = explosion_pos + initial_velocity * explosion_time
		var fall_distance = gravity * randf_range(0.8, 1.2)  # Varied fall adds chaos
		var end_point = Vector2(mid_point.x, mid_point.y + fall_distance)

		var tween = create_tween()
		# Explode with chaos
		tween.tween_property(particle, "position", mid_point, explosion_time).set_ease(Tween.EASE_OUT)
		# Fall with gravity
		tween.tween_property(particle, "position", end_point, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Varied fade timing for more chaos
		tween.tween_property(particle, "modulate:a", 0.0, randf_range(1.0, 1.5)).set_delay(randf_range(0.6, 1.0))
		tween.tween_callback(particle.queue_free)

func _fade_to_black():
	"""Fade overlay to black for scene transition."""
	# Stop fireworks when fading out
	_stop_fireworks()

	if not is_instance_valid(fade_rect):
		return
	fade_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
