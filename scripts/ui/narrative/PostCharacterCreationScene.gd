extends "res://scripts/ui/narrative/NarrativeScene.gd"

## ============================================================================
## SCENE 1: POST-CHARACTER CREATION NARRATION
## ============================================================================
## Introduction to Muscle Beach world after character creation.
## 4 messages with typewriter effect, auto-advances to Tutorial Scene.
##
## This scene extends NarrativeScene.gd and just sets the messages.
## ============================================================================

func _ready():
	# Set messages for Scene 1
	messages = [
		"Welcome to Muscle Beach, bro.",
		"The year is 1987. The vibes are immaculate. The gains are... about to be legendary.",
		"You've just stepped off the bus with nothing but a gym bag and an unstoppable urge to find yourself through the ancient art of flexing.",
		"But first, let's learn the fundamentals..."
	]

	# Set next scene path
	next_scene_path = "res://scenes/tutorial/TutorialExplanationScene.tscn"

	# Call parent _ready
	super._ready()
