class_name Arena
extends Node3D
## The script of game/level/arena.tscn. The scene holds the geometry, the lights, the stations, and the spawn markers.
## This script reads the markers and bakes the navigation mesh from the scene geometry.

## Every static body under it is walkable or is an obstacle for the bake.
@onready var navigation: NavigationRegion3D = $Navigation
## The origin is the player feet. The player faces the -Z axis of the marker.
@onready var player_spawn: Transform3D = ($PlayerSpawn as Marker3D).transform

var zombie_spawns: Array[Vector3] = []
## In scene tree order.
var stations: Array[Station] = []
var box: MysteryBox = null


## Bakes at once, so zombies can path on the first physics tick. The children are ready, so the box crate is in the bake.
func _ready() -> void:
	for marker: Node in $ZombieSpawns.get_children():
		zombie_spawns.append((marker as Marker3D).position)
	for node: Node in find_children("*", "Area3D"):
		var station: Station = node as Station
		if station != null:
			stations.append(station)
		if station is MysteryBox:
			box = station as MysteryBox
	navigation.bake_navigation_mesh(false)
	if navigation.navigation_mesh.get_polygon_count() == 0:
		push_error("Arena: the navigation bake gave an empty mesh. Zombies cannot find a path.")
