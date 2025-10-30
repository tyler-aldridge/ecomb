extends Node
class_name DataImporter

## ============================================================================
## DATA IMPORTER - TIMING FORMAT CONVERSION UTILITY
## ============================================================================
## Converts between bar/beat notation and floating-point beat numbers.
## Supports both tick-based and beat-based systems.
##
## Current system uses ticks (subdivision units):
## - 4/4 time: subdivision = 2, so 1 beat = 2 ticks
## - Bar 1 Beat 1 = tick 0
## - Bar 8 Beat 1 = tick 56
##
## Industry standard uses floating-point beats:
## - Beat 0.0, Beat 23.5, etc.
##
## This utility supports both for migration purposes.
## ============================================================================

# PPQ (Pulses Per Quarter) resolution for MIDI-style tick conversion
const PPQ_RESOLUTION: int = 480

static func bar_beat_to_ticks(bar: int, beat: Variant, beats_per_bar: int, subdivision: int) -> int:
	"""Convert bar/beat notation to tick position (current system).

	Args:
		bar: Bar number (1-indexed)
		beat: Beat number or string with 'a' for AND (e.g., 3, "1a", 2.5)
		beats_per_bar: Beats per bar from time signature
		subdivision: Subdivision factor (2 for simple, 3 for compound)

	Returns:
		Tick position (0-indexed)

	Examples:
		4/4, Bar 1 Beat 1 → 0
		4/4, Bar 8 Beat 1 → 56
		4/4, Bar 91 Beat 3 → 724
	"""
	var beat_num: float

	# Parse beat notation
	if typeof(beat) == TYPE_STRING:
		if beat.ends_with("a"):
			# AND note: "1a", "2a", etc.
			var base_beat = int(beat.substr(0, beat.length() - 1))
			beat_num = float(base_beat) + 0.5
		else:
			beat_num = float(beat)
	else:
		beat_num = float(beat)

	# Calculate ticks
	var ticks_per_bar = beats_per_bar * subdivision
	var base_ticks = (bar - 1) * ticks_per_bar + (int(beat_num) - 1) * subdivision

	# Add 1 tick for AND notes
	if beat_num != int(beat_num):
		base_ticks += 1

	return base_ticks

static func ticks_to_beats(ticks: int, subdivision: int) -> float:
	"""Convert ticks to floating-point beats.

	Args:
		ticks: Tick position
		subdivision: Subdivision factor (2 for simple, 3 for compound)

	Returns:
		Beat number as float

	Examples:
		ticks=0, subdivision=2 → 0.0
		ticks=56, subdivision=2 → 28.0
		ticks=57, subdivision=2 → 28.5
	"""
	return float(ticks) / float(subdivision)

static func beats_to_ticks(beats: float, subdivision: int) -> int:
	"""Convert floating-point beats to ticks.

	Args:
		beats: Beat number as float
		subdivision: Subdivision factor (2 for simple, 3 for compound)

	Returns:
		Tick position

	Examples:
		beats=0.0, subdivision=2 → 0
		beats=28.0, subdivision=2 → 56
		beats=28.5, subdivision=2 → 57
	"""
	return int(beats * float(subdivision))

static func convert_note_data_to_beat_based(notes: Array, beats_per_bar: int, subdivision: int) -> Array:
	"""Convert tick-based note data to beat-based format.

	This is for future migration to pure beat-based system.
	Currently, we keep tick-based for compatibility.

	Args:
		notes: Array of note dictionaries with beat_position in ticks
		beats_per_bar: Beats per bar from time signature
		subdivision: Subdivision factor

	Returns:
		Array of note dictionaries with 'beat' as float instead of ticks
	"""
	var converted = []

	for note in notes:
		var note_copy = note.duplicate()
		if note_copy.has("beat_position"):
			var ticks = note_copy["beat_position"]
			note_copy["beat"] = ticks_to_beats(ticks, subdivision)
		converted.append(note_copy)

	return converted

static func validate_timing_data(level_data: Dictionary) -> bool:
	"""Validate that level data has required timing information.

	Args:
		level_data: Level data dictionary

	Returns:
		true if valid, false otherwise
	"""
	if not level_data.has("bpm"):
		push_error("Level data missing BPM")
		return false

	if not level_data.has("time_signature_numerator"):
		push_warning("Level data missing time_signature_numerator, defaulting to 4")

	if not level_data.has("time_signature_denominator"):
		push_warning("Level data missing time_signature_denominator, defaulting to 4")

	return true

static func get_time_signature_info(time_sig_numerator: int, time_sig_denominator: int) -> Dictionary:
	"""Get beats_per_bar and subdivision from time signature.

	Args:
		time_sig_numerator: Time signature numerator (e.g., 4 in 4/4)
		time_sig_denominator: Time signature denominator (e.g., 4 in 4/4)

	Returns:
		Dictionary with "beats_per_bar" and "subdivision"
	"""
	# Detect compound meters: 6/8, 9/8, 12/8
	var is_compound = (time_sig_numerator % 3 == 0) and (time_sig_denominator == 8) and (time_sig_numerator >= 6)

	if is_compound:
		return {
			"beats_per_bar": int(time_sig_numerator / 3),
			"subdivision": 3
		}
	else:
		return {
			"beats_per_bar": time_sig_numerator,
			"subdivision": 2
		}

static func convert_logic_pro_ticks(tick: int, ppq: int, target_subdivision: int) -> float:
	"""Convert Logic Pro tick format to our beat system.

	Logic Pro uses PPQ (Pulses Per Quarter note) tick resolution.
	Common values: 480, 960, 3840

	Args:
		tick: Tick value from Logic Pro
		ppq: PPQ resolution (480, 960, etc.)
		target_subdivision: Target subdivision (2 for simple, 3 for compound)

	Returns:
		Beat number in our system (as ticks)
	"""
	# Convert to quarter notes
	var quarter_notes = float(tick) / float(ppq)

	# Convert to our subdivision system
	return quarter_notes * float(target_subdivision)
