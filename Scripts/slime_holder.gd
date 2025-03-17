extends Node2D

signal remove_slime

var slime_pieces = []
@export var width: int = 8
@export var height: int = 10
var slime = preload("res://Scenes/slime_piece.tscn")

func _ready() -> void:
	pass


func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null);
	return array;

func _on_grid_make_slime(board_position) -> void:
	if slime_pieces.size() == 0:
		slime_pieces = make_2d_array()
	var current = slime.instantiate()
	add_child(current)
	current.position = Vector2(board_position.x * 64 + 64, -board_position.y * 64 + 800)
	slime_pieces[board_position.x][board_position.y] = current


func _on_grid_damage_slime(board_position) -> void:
	if slime_pieces[board_position.x][board_position.y] != null:
		slime_pieces[board_position.x][board_position.y].take_damage(1)
		if slime_pieces[board_position.x][board_position.y].health <= 0:
			slime_pieces[board_position.x][board_position.y].queue_free()
			slime_pieces[board_position.x][board_position.y] = null
			emit_signal("remove_slime", board_position)
