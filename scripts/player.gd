class_name Player
extends CharacterBody3D

@export var HEALTH := 100
@export var STAMINA := 500
@export var WALK_SPEED := 4.0
@export var RUN_SPEED := 6.0
@export var JUMP_VELOCITY := 5
@export var SENSITIVITY := 0.006
@export var BOB_FREQUENCY := 2
@export var BOB_DISTANCE := 0.05
@export var FOV := 75.0
@export var INTERACT_DISTANCE := 2.0
@export_category("Camera")
@export var SIDEWAYS_TILT := 1
@export var FALL_TILT_TIME := 0.3
@export var FALL_THRESHOLD := -5.5
@export_category("Weapon")
@export var WEAPON_BOB_H := 1
@export var WEAPON_BOB_V := 4
@export_category("Others")
@export var can_control := false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Recoil/Camera
@onready var animations: AnimationPlayer = $Animations
@onready var crouch_check: ShapeCast3D = $CrouchCheck
@onready var weapons: MeshInstance3D = %Weapons
@onready var ammo: Label = $HUD/Magazine
@onready var total_ammo: Label = $HUD/Ammo
@onready var weapon_name: Label = $"HUD/Weapon Name"
@onready var health: ProgressBar = $HUD/Health/Health
@onready var stamina: ProgressBar = $HUD/Stamina/Stamina
@onready var health_underlay: ProgressBar = $HUD/Health/HealthUnderlay
@onready var stamina_regen_wait: Timer = $"HUD/Stamina/Stamina Regen Wait"
@onready var gate_anims: AnimationPlayer = $"../Navigation/Wall/Gate/AnimationPlayer"
@onready var spawn_points: Node3D = $"../Spawn Points"
@onready var cutscenes: AnimationPlayer = $"../Cutscenes"
@onready var gate_clang: AudioStreamPlayer3D = $"../Gate Clang"
@onready var middle: ColorRect = $HUD/Middle
@onready var up: ColorRect = $HUD/Up
@onready var down: ColorRect = $HUD/Down
@onready var ui: Control = $UI
@onready var boxes: Node3D = $"../Navigation/Boxes"
@onready var death: ColorRect = $UI/Death
@onready var main_music: AudioStreamPlayer3D = $"../Audios/Main Music"
@onready var bg: ColorRect = $"../Credits/BG"
@onready var entry_music: AudioStreamPlayer3D = $"../Audios/Entry Music"

const AK_47 = preload("res://weapon_resource/ak47.tres")
const AUG = preload("res://weapon_resource/aug.tres")
const FAMAS = preload("res://weapon_resource/famas.tres")
const FIVE_SEVEN = preload("res://weapon_resource/five seven.tres")
const GLOCK_18 = preload("res://weapon_resource/glock_18.tres")
const M_4A_1 = preload("res://weapon_resource/m4a1.tres")
const MAC_10 = preload("res://weapon_resource/mac10.tres")
const MP_5 = preload("res://weapon_resource/mp5.tres")
const P_90 = preload("res://weapon_resource/p90.tres")
const SCAR_H = preload("res://weapon_resource/scar-h.tres")
const TEC_9 = preload("res://weapon_resource/tec 9.tres")
const UMP_45 = preload("res://weapon_resource/ump 45.tres")

var speed := 0.0
var time_bob := 0.0
var is_crouching := false
var interact_cast_result
var fall_value := 0.0
var FALL_TILT_TIMER := 0.0
var forward_tilt_max := 1.25
var current_fall_velocity: float 
var current_health := 0
var is_dead:= false
var current_stamina := 0
var stamina_drain := 0.1
var stamina_regen := 75
var is_regening := false

func _ready() -> void:
	if Variables.cutscene_played:
		cutscenes.play("intro")
		entry_music.play()
	else:
		cutscenes.play("restart")
	death.modulate.a = 0
	Variables.is_pauseable = false
	position = Vector3(16, -5, 5)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	crouch_check.add_exception($".")
	current_health = HEALTH
	current_stamina = STAMINA
	health.max_value = HEALTH
	stamina.max_value = STAMINA

func _input(event: InputEvent) -> void:
	if !can_control: return
	if is_dead: return
	if event.is_action_pressed("interact"):
		interact()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or !can_control: return
	# Jump
	if event.is_action_pressed("jump") and !is_crouching:
		jump()
	
	# Crouch
	if event.is_action_pressed("crouch"):
		crouch()
	
	# Rotate Camera
	if event is InputEventMouseMotion and can_control:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(60))

func _physics_process(delta: float) -> void:
	if is_dead: return
	if current_health <= 0:
		is_dead = true
		die()
	
	if Input.is_action_pressed("temp"):
		cutscenes.stop()
		position = Vector3(8.108, -5.086, 5.8)
		rotation = Vector3(0, 90, 0)
		can_control = true
		up.visible = false
		down.visible = false
		middle.visible = false
		weapons.visible = true
		ui.visible = true
		head.rotation = Vector3(0, 0 ,0)
		camera.rotation = Vector3(0, 0 ,0)
		gameplay()
	
	if can_control:
		Variables.can_control = true
	else:
		Variables.can_control = false	
	
	if Variables.reload:
		weapons.reload()
	
	Variables.player_pos = global_position
	
	if Variables.player_hit:
		take_damage(Variables.DAMAGE)
		hit(Variables.dir)
	
	# Handle Movement
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			weapons.weapon_bob(delta, speed, WEAPON_BOB_H * (speed / 1.5), WEAPON_BOB_V)
			weapons.weapon_sway(delta, false)
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			weapons.weapon_sway(delta, true)
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		weapons.weapon_sway(delta, true)
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 5.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 4.0)
	if velocity != Vector3(0, 0, 0):
		weapons.weapon_bob(delta, 2.0, 0.01, 0.025)
	
	# Funcs
	head_bob(delta)
	
	show_hud_data()
	
	fov(delta)
	
	add_gravity(delta)
	
	camera_tilt(delta)
	
	get_ammo()
	
	change_speed(delta)
	
	air_procces()
	
	interact_cast()
	
	out_of_ammo()
	
	move_and_slide()

func add_gravity(delta) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func fov(delta) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z).length()
	var velocity_clamped = clamp(horizontal_velocity, 0.5, RUN_SPEED * 2)
	var target_fov: float = FOV + velocity_clamped * 2
	if is_crouching:
		target_fov *= 0.85
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func crouch() -> void:
	if is_crouching and !crouch_check.is_colliding():
		animations.play_backwards("crouch")
		is_crouching = !is_crouching
	elif !is_crouching:
		animations.play("crouch")
		is_crouching = !is_crouching

func change_speed(delta) -> void:
	if !can_control: return
	if Input.is_action_pressed("run") and current_stamina > 0:
		is_regening = false
		speed = RUN_SPEED
		if velocity.x > 0.01 or velocity.z > 0.01:
			current_stamina -= stamina_drain * delta
			current_stamina = clamp(current_stamina, 0, STAMINA)
	else:
		speed = WALK_SPEED
		if current_stamina < STAMINA and stamina_regen_wait.is_stopped():
			stamina_regen_wait.start()
		if is_regening and current_stamina < STAMINA:
			current_stamina += stamina_regen * delta
			current_stamina = clamp(current_stamina, 0, STAMINA)
	stamina.value = current_stamina
	if is_crouching:
		speed /= 3

func head_bob(delta) -> void:
	time_bob += delta * velocity.length() * float(is_on_floor())
	var pos := Vector3.ZERO
	pos.y = sin(time_bob * BOB_FREQUENCY) * BOB_DISTANCE
	#pos.x = abs(sin(time_bob * BOB_FREQUENCY / 2) * BOB_DISTANCE)
	camera.transform.origin = pos

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func interact():
	if interact_cast_result and interact_cast_result.has_user_signal("interacting"):
		interact_cast_result.emit_signal("interacting")

func interact_cast():
	if is_dead: return
	var space_state := camera.get_world_3d().direct_space_state
	var screen_center: Vector2 = get_viewport().size / 2
	screen_center.x += 1
	screen_center.y += 1
	var origin := camera.project_ray_origin(screen_center)
	var end := origin + camera.project_ray_normal(screen_center) * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	var current_cast_result = result.get("collider")
	if current_cast_result != interact_cast_result:
		if interact_cast_result and interact_cast_result.has_user_signal("unfocused"):
			interact_cast_result.emit_signal("unfocused")
		if current_cast_result and current_cast_result.has_user_signal("focused"):
			current_cast_result.emit_signal("focused")
	interact_cast_result = current_cast_result

func camera_tilt(delta) -> void:
	if !can_control: return
	if is_dead: return
	var angles := camera.rotation
	var offset := Vector3.ZERO
	var right_dot := velocity.dot(camera.global_transform.basis.x)
	var right_tilt := clampf(right_dot * deg_to_rad(SIDEWAYS_TILT), deg_to_rad(-SIDEWAYS_TILT), deg_to_rad(SIDEWAYS_TILT))
	angles.z = lerp(angles.z, -right_tilt, delta * 125)
	FALL_TILT_TIMER -= delta
	var fall_ratio = max(0.0, FALL_TILT_TIMER / FALL_TILT_TIME)
	var fall_kick_amount = fall_ratio * fall_value
	angles.x -= fall_kick_amount
	offset.y -= fall_kick_amount
	camera.position = offset
	camera.rotation = lerp(camera.rotation, angles, delta * 8.0)
	head.rotation.x = lerp(head.rotation.x, 0.0, delta * 8) - fall_kick_amount

func add_fall_kick(fall_strength: float) -> void:
	if is_dead: return
	fall_value = deg_to_rad(fall_strength)
	FALL_TILT_TIMER = FALL_TILT_TIME

func check_fall_speed() -> bool:
	return current_fall_velocity < FALL_THRESHOLD

func air_procces() -> void:
	if is_dead: return
	if is_on_floor():
		if check_fall_speed():
			var fall_strength = abs(current_fall_velocity) * 0.35
			add_fall_kick(fall_strength)
	current_fall_velocity = velocity.y

func show_hud_data() -> void:
	weapon_name.text = str(weapons.weapon.weapon_name)
	ammo.text = str(weapons.magazine_count)
	total_ammo.text = str(weapons.total_ammo_count)

func hit(dir) -> void:
	if is_dead: return
	dir.y *= 0 
	velocity += dir * 10
	Variables.player_hit = false

func die() -> void:
	
	cutscenes.play("die")
	await get_tree().create_timer(3.5).timeout
	get_tree().reload_current_scene()

func take_damage(damage) -> void:
	current_health -= damage
	current_health = clamp(current_health, 0, HEALTH)
	health.value = current_health
	await get_tree().create_timer(0.5).timeout
	while health_underlay.value > health.value:
		health_underlay.value -= 1
		await get_tree().create_timer(0.01).timeout

func _on_stamina_regen_wait_timeout() -> void:
	is_regening = true

func intro_method() -> void:
	gate_anims.play_backwards("close")
	await get_tree().create_timer(10).timeout
	Variables.is_pauseable = true
	main_music.playing = true

func outro_method() -> void:
	camera.rotation = Vector3(0, 0, 0)
	head.rotation = Vector3(0, 0, 0)
	await get_tree().create_timer(3.5).timeout
	gate_anims.play("open")

func remove_velo_aftet_cut() -> void:
	velocity.y = 0

func wave_manager(zombies, z_health, wait, atp) -> void:
	Variables.zombies_alive = zombies
	Variables.zombie_health = z_health
	for i in range(zombies):
		await get_tree().create_timer(wait).timeout
		var point = spawn_points.get_child(randi_range(0, spawn_points.get_child_count() - 1))
		point.spawn_zombie()
		if Variables.zombies_alive > atp:
			await get_tree().process_frame
	await get_tree().create_timer(5).timeout
	while Variables.zombies_alive > 0:
		await get_tree().process_frame

func ending() -> void:
	Variables.is_pauseable = false
	cutscenes.play("ending")
	await get_tree().create_timer(33).timeout
	get_tree().change_scene_to_file("res://scenes/main menu.tscn")

func gameplay() -> void:
	await get_tree().create_timer(5).timeout
	await wave_manager(8, 15, 2.8, 3)
	weapons.weapon = FIVE_SEVEN
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(16, 17, 2.6, 6)
	weapons.weapon = TEC_9
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(24, 19, 2.4, 8)
	weapons.weapon = MAC_10
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(32, 21, 2.2, 10)
	weapons.weapon = UMP_45
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(35, 23, 2.0, 12)
	weapons.weapon = MP_5
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(40, 25, 1.8, 12)
	weapons.weapon = P_90
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(50, 27, 1.6, 15)
	weapons.weapon = FAMAS
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(55, 29, 1.4, 15)
	weapons.weapon = AK_47
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(60, 31, 1.2, 16)
	weapons.weapon = AUG
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(65, 33, 1.0, 17)
	weapons.weapon = SCAR_H
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(70, 35, 0.75, 18)
	weapons.weapon = M_4A_1
	weapons.load_weapon()
	await get_tree().create_timer(10).timeout
	await wave_manager(75, 37, 0.5, 20) 
	await get_tree().create_timer(2).timeout
	can_control = false
	ending() 

func ammo_boxes(yesorno: bool) -> void:
	if yesorno == false:
		for i in range(boxes.get_child_count()):
			var box = boxes.get_child(i)
			box.visible = false
			box.get_child(2).disabled = true
	if yesorno == true:
		for i in range(boxes.get_child_count()):
			var box = boxes.get_child(i)
			box.visible = true
			box.get_child(2).disabled = false

func out_of_ammo() -> void:
	if weapons.total_ammo_count < 11:
		ammo_boxes(true)
	else:
		ammo_boxes(false)

func get_ammo() -> void:
	if Variables.give_ammo:
		weapons.total_ammo_count += 50
		Variables.give_ammo = false
