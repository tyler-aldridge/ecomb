extends Node

## ============================================================================
## MUSIC MANAGER - Lazy-loading music system with LRU cache
## ============================================================================
## Scalable music management for games with hundreds of songs.
## Loads music on-demand and keeps recently used songs in memory (LRU cache).
## Automatically unloads old songs when cache is full.
##
## Key Features:
## - Lazy loading: Songs only load when requested (not all at startup)
## - LRU cache: Keeps N most recently used songs in memory
## - Memory efficient: Scales to hundreds of songs without RAM issues
## - Web optimized: First access loads instantly, subsequent plays from cache
## - Backward compatible: Existing code works without changes

# LRU cache settings
const MAX_CACHE_SIZE = 10  # Keep 10 most recently used songs in memory
const PRELOAD_CRITICAL = true  # Preload title/menu music at startup

# Music cache with access order tracking
var music_cache: Dictionary = {}  # music_id -> AudioStream
var cache_access_order: Array = []  # LRU tracking (most recent at end)

# Music registry - add new songs here (NOT preloaded, just paths)
const MUSIC_FILES = {
	"main_title": "res://assets/audio/music/Main Title Song.ogg",
	"PreGameBattleMusic": "res://assets/audio/music/DivineFoxPlay-152BPM.ogg",
	# Add more songs here as you create them - they won't load until needed
	# "SomeBattleMusic": "res://assets/audio/music/SomeBattle.ogg",
	# "OverworldTheme": "res://assets/audio/music/OverworldTheme.ogg",
	# ... hundreds more songs can go here
}

# Critical songs to preload at startup (main menu, title screen, etc.)
const CRITICAL_MUSIC = ["main_title"]

func _ready():
	if PRELOAD_CRITICAL:
		# Only preload critical music (title screen, menus)
		# Battle music loads on-demand when battle starts
		for music_id in CRITICAL_MUSIC:
			if MUSIC_FILES.has(music_id):
				var stream = _load_music(MUSIC_FILES[music_id])
				if stream:
					music_cache[music_id] = stream
					cache_access_order.append(music_id)
				else:
					push_error("Failed to preload critical music: " + music_id)

func _load_music(path: String) -> AudioStream:
	"""Internal: Load a music file from disk."""
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStream:
			return stream
		else:
			push_error("Resource is not an AudioStream: " + path)
	else:
		push_error("Music file does not exist: " + path)
	return null

func _update_lru(music_id: String) -> void:
	"""Internal: Update LRU access order - mark as most recently used."""
	# Remove from current position
	var idx = cache_access_order.find(music_id)
	if idx >= 0:
		cache_access_order.remove_at(idx)
	# Add to end (most recent)
	cache_access_order.append(music_id)

func _evict_oldest() -> void:
	"""Internal: Remove least recently used song from cache."""
	if cache_access_order.size() > 0:
		var oldest_id = cache_access_order[0]
		cache_access_order.remove_at(0)
		music_cache.erase(oldest_id)

func get_music(music_id: String) -> AudioStream:
	"""Get music stream by ID - loads on-demand if not cached.

	This is the main method for getting music. It automatically:
	- Returns cached stream if already loaded (instant)
	- Loads from disk if not cached (first time only)
	- Updates LRU order (marks as recently used)
	- Evicts old songs if cache is full

	Args:
		music_id: String - ID from MUSIC_FILES (e.g., "PreGameBattleMusic")

	Returns:
		AudioStream - Music stream, or null if ID not found

	Example:
		var battle_music = MusicManager.get_music("PreGameBattleMusic")
		conductor.stream = battle_music
	"""
	# Check if music ID exists in registry
	if not MUSIC_FILES.has(music_id):
		push_error("Unknown music ID: " + music_id)
		return null

	# Check cache first (fast path)
	if music_cache.has(music_id):
		_update_lru(music_id)  # Mark as recently used
		return music_cache[music_id]

	# Not cached - load from disk (slow path, first time only)
	var path = MUSIC_FILES[music_id]
	var stream = _load_music(path)

	if stream:
		# Add to cache
		music_cache[music_id] = stream
		_update_lru(music_id)

		# Evict oldest if cache is full
		if music_cache.size() > MAX_CACHE_SIZE:
			_evict_oldest()

		return stream
	else:
		push_error("Failed to load music: " + music_id)
		return null

func get_music_by_path(path: String) -> AudioStream:
	"""Get music stream by file path - for backward compatibility.

	Legacy method for code that uses paths instead of IDs.
	Internally converts path to ID and uses get_music().

	Args:
		path: String - Full resource path (e.g., "res://assets/audio/music/song.ogg")

	Returns:
		AudioStream - Music stream, or null if not found
	"""
	# Find music ID from path
	for music_id in MUSIC_FILES:
		if MUSIC_FILES[music_id] == path:
			return get_music(music_id)  # Use lazy loading

	# Path not in registry - load directly as fallback
	push_warning("Music path not in registry, loading directly: " + path)
	return _load_music(path)

func preload_music(music_id: String) -> void:
	"""Manually preload a specific song into cache.

	Useful for preloading battle music before entering battle
	to avoid the first-load delay.

	Args:
		music_id: String - ID from MUSIC_FILES (e.g., "lesson1")

	Example:
		# Before loading battle scene
		MusicManager.preload_music("lesson1")
	"""
	if music_cache.has(music_id):
		_update_lru(music_id)  # Already cached, just mark as recent
		return

	# Load into cache
	get_music(music_id)  # Uses lazy loading logic

func unload_music(music_id: String) -> void:
	"""Manually remove a song from cache.

	Useful for freeing memory when you know a song won't be used again soon.

	Args:
		music_id: String - ID from MUSIC_FILES
	"""
	if music_cache.has(music_id):
		music_cache.erase(music_id)
		var idx = cache_access_order.find(music_id)
		if idx >= 0:
			cache_access_order.remove_at(idx)

func clear_cache() -> void:
	"""Clear entire music cache (except critical music).

	Useful for freeing memory when transitioning between major game sections.
	Critical music (title screen, etc.) is preserved.
	"""
	var preserved = []
	for music_id in CRITICAL_MUSIC:
		if music_cache.has(music_id):
			preserved.append(music_id)

	music_cache.clear()
	cache_access_order.clear()

	# Restore critical music
	for music_id in preserved:
		if MUSIC_FILES.has(music_id):
			var stream = _load_music(MUSIC_FILES[music_id])
			if stream:
				music_cache[music_id] = stream
				cache_access_order.append(music_id)

func is_music_cached(music_id: String) -> bool:
	"""Check if a music file is currently in cache."""
	return music_cache.has(music_id)

func get_cache_size() -> int:
	"""Get number of songs currently in cache."""
	return music_cache.size()

func get_cache_info() -> Dictionary:
	"""Get detailed cache statistics for debugging.

	Returns:
		Dictionary with keys:
			- size: int - Number of songs in cache
			- max_size: int - Maximum cache capacity
			- cached_songs: Array - List of music IDs in cache (LRU order)
	"""
	return {
		"size": music_cache.size(),
		"max_size": MAX_CACHE_SIZE,
		"cached_songs": cache_access_order.duplicate()
	}
