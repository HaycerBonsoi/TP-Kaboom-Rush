
extends Area2D

var activated = false
@onready var flag = get_node_or_null("Flag")

func _ready() -> void:
	if flag == null:
		push_error("Can't find Flag! Check its node name.")
	else:
		flag.stop()
		flag.frame = 0

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if activated:
		return

	if body.has_method("set_checkpoint"):
		activated = true

		var spawn_point = get_node_or_null("SpawnPoint")

		if spawn_point == null:
			push_error("Can't find SpawnPoint!")
			return

		body.set_checkpoint(spawn_point.global_position)

		if flag != null:
			if flag.sprite_frames.has_animation("rise"):
				flag.play("rise")
			else:
				push_error("Can't find animation named rise!")

		print("CHECKPOINT ACTIVATED!")
