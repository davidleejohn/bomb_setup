extends Node2D

enum {wait, move}
var state

@export var width: int
@export var height: int
@export var x_start: int
@export var y_start: int
@export var offset: int
@export var y_offset: int

@export var empty_spaces: PackedVector2Array
@export var ice_spaces: PackedVector2Array
@export var lock_spaces: PackedVector2Array
@export var concrete_spaces: PackedVector2Array
@export var slime_spaces: PackedVector2Array
var damaged_slime = false

signal damage_ice
signal make_ice
signal make_lock
signal damage_lock
signal make_concrete
signal damage_concrete
signal make_slime
signal damage_slime

@onready var destroy_timer: Timer = $"../destroy_timer"
@onready var collapse_timer: Timer = $"../collapse_timer"
@onready var refill_timer: Timer = $"../refill_timer"



var possible_pieces = [
preload("res://Scenes/blue_piece.tscn"),
preload("res://Scenes/green_piece.tscn"),
preload("res://Scenes/pink_piece.tscn"),
preload("res://Scenes/light_green_piece.tscn"),
preload("res://Scenes/orange_piece.tscn"),
preload("res://Scenes/yellow_piece.tscn")
] 

var all_pieces = []
var current_matches = []

var piece_one = null
var piece_two = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)

var first_touch = Vector2(0,0)
var last_touch = Vector2(0,0)
var controlling = false






func _ready() -> void:
	state = move
	randomize()
	all_pieces = make_2d_array()
	spawn_pieces()
	spawn_ice()
	spawn_lock()
	spawn_concrete()
	spawn_slime()
	
func restricted_fill(place):
	if is_in_array(empty_spaces,place):
		return true
	if is_in_array(concrete_spaces,place):
		return true
	if is_in_array(slime_spaces,place):
		return true
	return false
	
func restricted_move(place):
	if is_in_array(lock_spaces,place):
		return true
	return false
	
func is_in_array(array,item):
	for i in array.size():
		if array[i] == item:
			return true
	return false

func remove_from_array(array,item):
	for i in range(array.size() -1,-1,-1):
		if array[i] == item:
			array.remove_at(i)

func _process(_delta:float) -> void:
	if state == move:
		touch_input()
	
func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null);
	return array;

func spawn_pieces():
	for i in width:
		for j in height:
			if !restricted_fill(Vector2(i,j)):
				var rand = floor(randi_range(0, possible_pieces.size() - 1))
				var loops = 0
				var piece = possible_pieces[rand].instantiate()
				while(match_at(i,j,piece.color) && loops < 100):
					rand = floor(randi_range(0, possible_pieces.size() - 1))
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.set_position(grid_to_pixel(i, j))
				all_pieces[i][j] = piece
			
func spawn_ice():
	for i in ice_spaces.size():
		emit_signal("make_ice", ice_spaces[i])
		
func spawn_lock():
	for i in lock_spaces.size():
		emit_signal("make_lock", lock_spaces[i])
			
func spawn_concrete():
	for i in concrete_spaces.size():
		emit_signal("make_concrete",concrete_spaces[i])
		
func spawn_slime():
	for i in slime_spaces.size():
		emit_signal("make_slime",slime_spaces[i])
			
func match_at(i, j, color):
	if i > 1:
		if all_pieces[i - 1][j] != null && all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].color == color && all_pieces[i - 2][j].color == color:
				return true
	if j > 1:
		if all_pieces[i ][j - 1] != null && all_pieces[i ][j - 2] != null:
			if all_pieces[i ][j - 1].color == color && all_pieces[i][j - 2].color == color:
				return true
			
func grid_to_pixel(column, row):
	var new_x = x_start + offset * column;
	var new_y = y_start + -offset * row;
	return Vector2(new_x, new_y)
	
func pixel_to_grid(pixel_x, pixel_y):
	var new_x =  round((pixel_x - x_start)/offset)
	var new_y = round((pixel_y - y_start)/-offset)
	return Vector2(new_x, new_y)
	
func is_in_grid(grid_position):
	if grid_position.x >= 0 && grid_position.x < width:
		if grid_position.y >= 0 && grid_position.y < height:
			return true
	return false
	
func touch_input():
	var mouse = get_global_mouse_position()
	if Input.is_action_just_pressed("ui_touch"):
		if is_in_grid(pixel_to_grid(mouse.x, mouse.y)):
			first_touch = pixel_to_grid(mouse.x, mouse.y)
			controlling = true

	if Input.is_action_just_released("ui_touch"):
		if is_in_grid(pixel_to_grid(mouse.x, mouse.y)) && controlling:
			controlling = false
			last_touch = pixel_to_grid(mouse.x, mouse.y)
			touch_difference(first_touch, last_touch)
			
func swap_pieces(column, row, direction):
		var first_piece = all_pieces [column][row]
		var other_piece = all_pieces [column + direction.x][row + direction.y]
		if first_piece != null && other_piece != null:
			if !restricted_move(Vector2(column,row)) && !restricted_move(Vector2(column,row) + direction):
				store_info(first_piece, other_piece, Vector2(column, row), direction)
				state = wait
				all_pieces[column][row] = other_piece
				all_pieces[column + direction.x][row + direction.y] = first_piece
				first_piece.move(grid_to_pixel(column + direction.x , row + direction.y))
				other_piece.move(grid_to_pixel(column,row))
				find_matches()
		
func store_info(first_piece, other_piece, place, direction):
	piece_one = first_piece
	piece_two = other_piece
	last_place = place
	last_direction = direction

func swap_back():
	if piece_one != null && piece_two != null:
		swap_pieces(last_place.x,last_place.y, last_direction)
		piece_one = null
		piece_two = null
		last_place = null
		last_direction = null
		print("unswapping!")
	state=move

func touch_difference(grid1, grid2):
	var difference = grid2 - grid1
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(grid1.x, grid1.y, Vector2(1, 0))
		elif difference.x < 0:
			swap_pieces(grid1.x, grid1.y, Vector2(-1, 0))
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(grid1.x, grid1.y, Vector2(0, 1))
		elif difference.y < 0:
			swap_pieces(grid1.x, grid1.y, Vector2(0, -1))
				
func null_piece(column,row):
	if all_pieces[column][row] == null:
		return true
	return false
				
func find_matches():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				var current_color = all_pieces[i][j].color
				if i > 0 && i < width-1:
					if all_pieces[i-1][j] != null && all_pieces[i+1][j] != null:
						if all_pieces[i-1][j].color == current_color && all_pieces[i+1][j].color == current_color:
							create_match_h(i,j)


				if j > 0 && j < height-1:
					if all_pieces[i][j-1] != null && all_pieces[i][j+1] != null:
						if all_pieces[i][j-1].color == current_color && all_pieces[i][j+1].color == current_color:
							create_match_v(i,j)


							
	destroy_timer.start()
	
func find_bombs():
	for i in current_matches.size():
		var current_column = current_matches[i].x
		var current_row = current_matches[i].y
		var current_color = all_pieces[current_column][current_row].color
		var col_matched = 0
		var row_matched = 0
		for j in current_matches.size():
			var this_column = current_matches[j].x
			var this_row = current_matches[j].y
			var this_color = all_pieces[current_column][current_row].color
			if this_column == current_column && current_color == this_color:
				col_matched += 1
			if this_row == current_row && current_color == this_color:
				row_matched += 1
		if col_matched == 4:
			make_bomb(2,current_color)
		if row_matched == 4:
			make_bomb(1,current_color)
			return
		if col_matched == 3 && row_matched == 3:
			make_bomb(0,current_color)
			return
		if row_matched == 5 or col_matched == 5:
			print("color bomb")
			return
			
func make_bomb(bomb_type, color):
	for i in current_matches.size():
		var current_column = current_matches[i].x
		var current_row = current_matches[i].y
		if all_pieces[current_column][current_row] == piece_one and piece_one.color == color:
			piece_one.matched=false
			change_bomb(bomb_type,piece_one)
		if all_pieces[current_column][current_row] == piece_two and piece_two.color == color:
			piece_two.matched=false
			change_bomb(bomb_type,piece_two)
			
func change_bomb(bomb_type,piece):
	if bomb_type == 0:
		piece.make_adjacent_bomb()
	elif bomb_type == 1:
		piece.make_row_bomb()
	elif bomb_type == 2:
		piece.make_column_bomb()
			
		

func add_to_array(value, array_to_add=current_matches):
	if !array_to_add.has(value):
		array_to_add.append(value)

func create_match_h(i,j):
	match_dim(all_pieces[i-1][j])
	match_dim(all_pieces[i][j])
	match_dim(all_pieces[i+1][j])
	add_to_array(Vector2(i,j))
	add_to_array(Vector2(i+1,j))
	add_to_array(Vector2(i-1,j))
	return

func create_match_v(i,j):
	match_dim(all_pieces[i][j-1])
	match_dim(all_pieces[i][j])
	match_dim(all_pieces[i][j+1])
	add_to_array(Vector2(i,j))
	add_to_array(Vector2(i,j+1))
	add_to_array(Vector2(i,j-1))
	return
	
func match_dim(item):
	item.matched = true
	item.dim()

	
func destroy_matched():
	find_bombs()
	var match_detect = false
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					damage_special(i,j)
					match_detect = true
					all_pieces[i][j].queue_free()
					all_pieces[i][j] = null
	if match_detect == true:
		collapse_timer.start()
	else:
	#	state = move
		swap_back()
	current_matches.clear()
	
		
func check_concrete(column,row):
	if column < width-1:
		emit_signal("damage_concrete", Vector2(column+1, row))
	if column > 0:
		emit_signal("damage_concrete", Vector2(column-1, row))
	if row < height-1:
		emit_signal("damage_concrete", Vector2(column, row+1))
	if row > 0:
		emit_signal("damage_concrete", Vector2(column, row-1))
		
func check_slime(column,row):
	if column < width-1:
		emit_signal("damage_slime", Vector2(column+1, row))
	if column > 0:
		emit_signal("damage_slime", Vector2(column-1, row))
	if row < height-1:
		emit_signal("damage_slime", Vector2(column, row+1))
	if row > 0:
		emit_signal("damage_slime", Vector2(column, row-1))
		
func damage_special(column,row):
	emit_signal("damage_ice", Vector2(column,row))
	emit_signal("damage_lock", Vector2(column,row))
	check_slime(column,row)
	check_concrete(column,row)

func collapse_column():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null && !restricted_fill(Vector2(i,j)):
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						all_pieces[i][k].move(grid_to_pixel(i,j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	refill_timer.start()
	
func refill_column():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null && !restricted_fill(Vector2(i,j)):
				var rand = floor(randi_range(0, possible_pieces.size() - 1))
				var loops = 0
				var piece = possible_pieces[rand].instantiate()
				while(match_at(i,j,piece.color) && loops < 100):
					rand = floor(randi_range(0, possible_pieces.size() - 1))
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.set_position(grid_to_pixel(i, j - y_offset))
				piece.move(grid_to_pixel(i,j))
				all_pieces[i][j] = piece
	after_refill()

func after_refill():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if match_at(i,j, all_pieces[i][j].color):
					find_matches()
					destroy_timer.start()
					return
	if !damaged_slime:
		generate_slime()
	state = move
	damaged_slime = false

func generate_slime():
	if slime_spaces.size() > 0:
		var slime_made = false
		var tracker = 0
		while !slime_made and tracker < 100:
			var random_num = floor(randi_range(0, slime_spaces.size() - 1))
			var curr_x = slime_spaces[random_num].x
			var curr_y = slime_spaces[random_num].y
			var neighbor = find_normal_neighbor(Vector2(curr_x,curr_y))
			if neighbor != null:
				all_pieces[neighbor.x][neighbor.y].queue_free()
				all_pieces[neighbor.x][neighbor.y] = null
				slime_spaces.append(Vector2(neighbor.x,neighbor.y))
				emit_signal("make_slime", Vector2(neighbor.x,neighbor.y))
				slime_made = true
			tracker += 1

func find_normal_neighbor(grid_pos):
	var random_num = floor(randi_range(0, 3))

# I hate this. Almost surely there is a way to have it randomize the direction it first checks or to 
# have it choose the if statements in a random order. This note is for future me or anyone who wonders wtf this is.

	if random_num == 0:
		if is_in_grid(Vector2(grid_pos.x+1,grid_pos.y)):
			if all_pieces[grid_pos.x+1][grid_pos.y] != null:
				return Vector2(grid_pos.x+1,grid_pos.y)
		if is_in_grid(Vector2(grid_pos.x-1,grid_pos.y)):
			if all_pieces[grid_pos.x-1][grid_pos.y] != null:
				return Vector2(grid_pos.x-1,grid_pos.y)
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y+1)):
			if all_pieces[grid_pos.x][grid_pos.y+1] != null:
				return Vector2(grid_pos.x,grid_pos.y+1)
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y-1)):
			if all_pieces[grid_pos.x][grid_pos.y-1] != null:
				return Vector2(grid_pos.x,grid_pos.y-1)
	if random_num == 1:
		if is_in_grid(Vector2(grid_pos.x-1,grid_pos.y)):
			if all_pieces[grid_pos.x-1][grid_pos.y] != null:
				return Vector2(grid_pos.x-1,grid_pos.y)
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y+1)):
			if all_pieces[grid_pos.x][grid_pos.y+1] != null:
				return Vector2(grid_pos.x,grid_pos.y+1)
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y-1)):
			if all_pieces[grid_pos.x][grid_pos.y-1] != null:
				return Vector2(grid_pos.x,grid_pos.y-1)
		if is_in_grid(Vector2(grid_pos.x+1,grid_pos.y)):
			if all_pieces[grid_pos.x+1][grid_pos.y] != null:
				return Vector2(grid_pos.x+1,grid_pos.y)
	if random_num == 2:
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y+1)):
			if all_pieces[grid_pos.x][grid_pos.y+1] != null:
				return Vector2(grid_pos.x,grid_pos.y+1)
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y-1)):
			if all_pieces[grid_pos.x][grid_pos.y-1] != null:
				return Vector2(grid_pos.x,grid_pos.y-1)
		if is_in_grid(Vector2(grid_pos.x+1,grid_pos.y)):
			if all_pieces[grid_pos.x+1][grid_pos.y] != null:
				return Vector2(grid_pos.x+1,grid_pos.y)
		if is_in_grid(Vector2(grid_pos.x-1,grid_pos.y)):
			if all_pieces[grid_pos.x-1][grid_pos.y] != null:
				return Vector2(grid_pos.x-1,grid_pos.y)
	if random_num == 3:
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y-1)):
			if all_pieces[grid_pos.x][grid_pos.y-1] != null:
				return Vector2(grid_pos.x,grid_pos.y-1)
		if is_in_grid(Vector2(grid_pos.x+1,grid_pos.y)):
			if all_pieces[grid_pos.x+1][grid_pos.y] != null:
				return Vector2(grid_pos.x+1,grid_pos.y)
		if is_in_grid(Vector2(grid_pos.x-1,grid_pos.y)):
			if all_pieces[grid_pos.x-1][grid_pos.y] != null:
				return Vector2(grid_pos.x-1,grid_pos.y)
		if is_in_grid(Vector2(grid_pos.x,grid_pos.y+1)):
			if all_pieces[grid_pos.x][grid_pos.y+1] != null:
				return Vector2(grid_pos.x,grid_pos.y+1)



	

	
func _on_destroy_timer_timeout() -> void:
	destroy_matched()

func _on_collapse_timer_timeout() -> void:
	collapse_column()

func _on_refill_timer_timeout() -> void:
	refill_column()

func _on_lock_holder_remove_lock(place) -> void:
	remove_from_array(lock_spaces,place)


func _on_concrete_holder_remove_concrete(place) -> void:
	remove_from_array(concrete_spaces,place)


func _on_slime_holder_remove_slime(place) -> void:
	damaged_slime = true
	remove_from_array(slime_spaces,place)
