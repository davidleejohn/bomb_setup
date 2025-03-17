extends Node2D

signal remove_concrete

var concrete_pieces = []
@export var width: int = 8
@export var height: int = 10
var concrete = preload("res://Scenes/concrete_piece.tscn")

func _ready() -> void:
	pass


func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null);
	return array;

func _on_grid_make_concrete(board_position) -> void:
	if concrete_pieces.size() == 0:
		concrete_pieces = make_2d_array()
	var current = concrete.instantiate()
	add_child(current)
	current.position = Vector2(board_position.x * 64 + 64, -board_position.y * 64 + 800)
	concrete_pieces[board_position.x][board_position.y] = current


func _on_grid_damage_concrete(board_position) -> void:
	if concrete_pieces[board_position.x][board_position.y] != null:
		concrete_pieces[board_position.x][board_position.y].take_damage(1)
		if concrete_pieces[board_position.x][board_position.y].health <= 0:
			concrete_pieces[board_position.x][board_position.y].queue_free()
			concrete_pieces[board_position.x][board_position.y] = null
			emit_signal("remove_concrete", board_position)
