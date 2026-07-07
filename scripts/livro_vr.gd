extends Node3D

@export_node_path("MeshInstance3D") var mesh_path: NodePath = NodePath("MeshLivro")
@export_node_path("Area3D") var area_path: NodePath = NodePath("AreaInteracao")
@export_node_path("SubViewport") var viewport_path: NodePath = NodePath("SubViewportControl")
@export_node_path("RayCast3D") var raycast_path: NodePath = NodePath("RayCastVR")
@export_node_path("AudioStreamPlayer3D") var audio_path: NodePath = NodePath("SomPagina")

var mesh_livro: MeshInstance3D
var area_interacao: Area3D
var subviewport: SubViewport
var raycast: RayCast3D
var audio_player: AudioStreamPlayer3D
var interface_livro: Control
var trigger_apertado: bool = false

func _ready() -> void:
	mesh_livro = get_node_or_null(mesh_path) as MeshInstance3D
	area_interacao = get_node_or_null(area_path) as Area3D
	subviewport = get_node_or_null(viewport_path) as SubViewport
	raycast = get_node_or_null(raycast_path) as RayCast3D
	audio_player = get_node_or_null(audio_path) as AudioStreamPlayer3D

	if mesh_livro == null or area_interacao == null or subviewport == null or raycast == null:
		push_error("Algum nó essencial do livro VR não foi encontrado.")
		return

	interface_livro = subviewport.get_node_or_null("InterfaceLivro") as Control
	if interface_livro == null:
		push_error("O nó InterfaceLivro não foi encontrado dentro do SubViewport.")
		return

	subviewport.size = Vector2i(1024, 512)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_configurar_mesh_livro()
	_configurar_area_interacao()
	_configurar_raycast()

func _process(_delta: float) -> void:
	if not is_instance_valid(raycast) or not raycast.is_colliding():
		trigger_apertado = false
		return

	var hit_point: Vector3 = raycast.get_collision_point()
	var pos_viewport: Vector2 = _world_to_viewport(hit_point)
	if pos_viewport == Vector2(-1, -1):
		trigger_apertado = false
		return

	var trigger_pressionado: bool = Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if trigger_pressionado and not trigger_apertado:
		var direcao: String = ""
		if pos_viewport.x < 0.18 * float(subviewport.size.x):
			direcao = "esquerda"
		elif pos_viewport.x > 0.82 * float(subviewport.size.x):
			direcao = "direita"

		if direcao != "":
			_injetar_click_virtual(pos_viewport)
			interface_livro.call("folhear_pagina", direcao)
			_tocar_som_pagina()

	trigger_apertado = trigger_pressionado

func _configurar_mesh_livro() -> void:
	if mesh_livro == null:
		return

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(1.8, 1.2)
	quad_mesh.orientation = PlaneMesh.FACE_Z

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = subviewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	mesh_livro.mesh = quad_mesh
	mesh_livro.material_override = material
	mesh_livro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _configurar_area_interacao() -> void:
	if area_interacao == null:
		return

	var shape: CollisionShape3D = area_interacao.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null:
		shape = CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		area_interacao.add_child(shape)
		shape.owner = self

	if shape.shape == null:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.8, 1.2, 0.02)
		shape.shape = box_shape

func _configurar_raycast() -> void:
	if raycast == null:
		return

	raycast.target_position = Vector3(0.0, 0.0, -2.0)
	raycast.enabled = true
	raycast.collision_mask = 1

func _world_to_viewport(hit_point: Vector3) -> Vector2:
	if mesh_livro == null or mesh_livro.mesh == null:
		return Vector2(-1, -1)

	var local_hit: Vector3 = mesh_livro.to_local(hit_point)
	var quad_size: Vector2 = Vector2(1.8, 1.2)
	if mesh_livro.mesh is QuadMesh:
		quad_size = (mesh_livro.mesh as QuadMesh).size

	var uv_hit: Vector2 = Vector2(local_hit.x, local_hit.y) / quad_size
	uv_hit += Vector2(0.5, 0.5)
	uv_hit.x = clampf(uv_hit.x, 0.0, 1.0)
	uv_hit.y = clampf(uv_hit.y, 0.0, 1.0)

	return Vector2(uv_hit.x * float(subviewport.size.x), uv_hit.y * float(subviewport.size.y))

func _injetar_click_virtual(posicao: Vector2) -> void:
	if subviewport == null:
		return

	var motion := InputEventMouseMotion.new()
	motion.position = posicao
	motion.global_position = posicao
	subviewport.push_input(motion)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = posicao
	click.global_position = posicao
	subviewport.push_input(click)

	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = posicao
	click.global_position = posicao
	subviewport.push_input(click)

func _tocar_som_pagina() -> void:
	if is_instance_valid(audio_player) and audio_player.stream != null:
		audio_player.play()
