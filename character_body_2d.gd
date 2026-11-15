
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var explosion_radius: float = 48.0
@export var explosion_delay: float = 0.5
@export var respawn_delay: float = 1.0

@onready var sprite_2d: AnimatedSprite2D = $Sprite2D
@onready var destructibles: TileMap = $"../Destructibles"

var explosion_timer = 0.0
var is_exploding = false
var is_dead = false
var spawn_position: Vector2

func _ready() -> void:
	spawn_position = global_position
	sprite_2d.sprite_frames.set_animation_loop("BOOM", false)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 10.0 * delta)

	move_and_slide()

	if velocity.x < 0:
		sprite_2d.flip_h = true
	elif velocity.x > 0:
		sprite_2d.flip_h = false

	if Input.is_action_pressed("Explode") and not is_exploding:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explode()
			explosion_timer = explosion_delay
	else:
		explosion_timer = 0.0

	if not is_exploding:
		if not is_on_floor():
			sprite_2d.play("jumping")
		elif abs(velocity.x) > 1:
			sprite_2d.play("walking")
		else:
			sprite_2d.play("default")


func set_checkpoint(new_position: Vector2) -> void:
	spawn_position = new_position
	print("New checkpoint saved!")


func explode() -> void:
	if is_exploding or is_dead:
		return

	is_exploding = true
	is_dead = true

	var death_position = global_position
	var death_flip = sprite_2d.flip_h

	velocity = Vector2.ZERO
	sprite_2d.play("BOOM")

	# Destroy nearby destructible tiles.
	var used_cells = destructibles.get_used_cells(0)

	for cell in used_cells:
		var tile_position = destructibles.to_global(
			destructibles.map_to_local(cell)
		)

		if tile_position.distance_to(death_position) <= explosion_radius:
			destructibles.erase_cell(0, cell)

	# Destroy nearby leftover corpses.
	var corpses = get_tree().get_nodes_in_group("corpses")

	for corpse in corpses:
		if is_instance_valid(corpse):
			if corpse.global_position.distance_to(death_position) <= explosion_radius:
				corpse.queue_free()

	await sprite_2d.animation_finished

	# Get the final frame of the BOOM animation.
	var last_frame = sprite_2d.sprite_frames.get_frame_count("BOOM") - 1
	var corpse_texture = sprite_2d.sprite_frames.get_frame_texture("BOOM", last_frame)

	# Create the leftover corpse.
	var corpse_body = StaticBody2D.new()
	corpse_body.collision_layer = collision_layer
	corpse_body.collision_mask = collision_mask
	corpse_body.add_to_group("corpses")

	var corpse_sprite = Sprite2D.new()
	corpse_sprite.texture = corpse_texture
	corpse_sprite.flip_h = death_flip
	corpse_sprite.scale = sprite_2d.scale
	corpse_body.add_child(corpse_sprite)

	# Create the smaller corpse hitbox.
	var collision = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()

	rectangle.size = Vector2(24, 22) * sprite_2d.scale.abs()
	collision.shape = rectangle

	collision.position.y = (
		corpse_texture.get_height() / 2.0 - 46.0 + 5.0
	) * sprite_2d.scale.y

	corpse_body.add_child(collision)

	get_parent().add_child(corpse_body)
	corpse_body.global_position = death_position
	corpse_body.z_index = z_index

	# Respawn at the latest checkpoint.
	await get_tree().create_timer(respawn_delay).timeout

	global_position = spawn_position
	velocity = Vector2.ZERO
	sprite_2d.play("default")

	is_dead = false
	is_exploding = false
