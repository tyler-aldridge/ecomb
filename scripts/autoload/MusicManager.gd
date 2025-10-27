extends Node

## ============================================================================
## MUSIC MANAGER - Preloads music for instant playback with zero stuttering
## ============================================================================
## Critical for web builds where streaming audio can skip on first load.
## Preloads all battle music into memory at game start for instant access.

# Preloaded music cache - loaded once at startup
var music_cache: Dictionary = {}

# Music file paths
const MUSIC_FILES = {
	"main_title": "res://assets/audio/music/Main Title Song.ogg",
	"lesson1": "res://assets/audio/music/DivineFoxPlay-152BPM.ogg"
}

func _ready():
	# Preload all music files on startup
	# This ensures zero lag/skip when battle starts, especially on web
	for music_id in MUSIC_FILES:
		var path = MUSIC_FILES[music_id]
		var stream = preload_music(path)
		if stream:
			music_cache[music_id] = stream
		else:
			push_error("Failed to preload music: " + path)

func preload_music(path: String) -> AudioStream:
	"""Preload a music file into memory."""
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStream:
			return stream
		else:
			push_error("Resource is not an AudioStream: " + path)
	else:
		push_error("Music file does not exist: " + path)
	return null

func get_music(music_id: String) -> AudioStream:
	"""Get a preloaded music stream by ID.

	Args:
		music_id: String - ID from MUSIC_FILES (e.g., "lesson1")

	Returns:
		AudioStream - Preloaded music stream, or null if not found
	"""
	if music_cache.has(music_id):
		return music_cache[music_id]
	else:
		push_warning("Music ID not found in cache: " + music_id)
		return null

func get_music_by_path(path: String) -> AudioStream:
	"""Get a preloaded music stream by file path.

	Useful for legacy code that uses paths instead of IDs.

	Args:
		path: String - Full resource path

	Returns:
		AudioStream - Preloaded music stream, or null if not found
	"""
	# Check if path matches any cached music
	for music_id in MUSIC_FILES:
		if MUSIC_FILES[music_id] == path:
			return music_cache.get(music_id)

	# Not in cache - load it now (fallback for dynamically loaded music)
	push_warning("Music not preloaded, loading now: " + path)
	return preload_music(path)

func is_music_cached(music_id: String) -> bool:
	"""Check if a music file is preloaded."""
	return music_cache.has(music_id)

func get_cache_size() -> int:
	"""Get number of cached music files."""
	return music_cache.size()
