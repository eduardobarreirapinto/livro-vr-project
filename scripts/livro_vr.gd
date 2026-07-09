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
var running_in_xr: bool = false

func _ready() -> void:
	# 1. Inicializa o ecossistema OpenXR na Viewport principal
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		running_in_xr = true
		get_viewport().use_xr = true
	else:
		running_in_xr = false
		print("OpenXR não foi inicializado. Verifique o headset.")
		
	# 2. Vincula e valida os nós do projeto
	mesh_livro = get_node_or_null(mesh_path) as MeshInstance3D
	area_interacao = get_node_or_null(area_path) as Area3D
	subviewport = get_node_or_null(viewport_path) as SubViewport
	raycast = get_node_or_null(raycast_path) as RayCast3D
	if raycast == null:
		# Fallback: procura em toda a árvore por um nó chamado 'RayCastVR'
		raycast = find_child("RayCastVR", true, false) as RayCast3D
	audio_player = get_node_or_null(audio_path) as AudioStreamPlayer3D

	if mesh_livro == null or area_interacao == null or subviewport == null or raycast == null:
		push_error("Algum nó essencial do livro VR não foi encontrado.")
		return

	interface_livro = subviewport.get_node_or_null("InterfaceLivro") as Control
	if interface_livro == null:
		push_error("O nó InterfaceLivro não foi encontrado dentro do SubViewport.")
		return

	# 3. Configurações base da SubViewport de UI
	subviewport.size = Vector2i(1024, 512)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Garante que haja uma camera ativa (útil para testes sem pipeline XR completo)
	if has_node("Camera3D"):
		var cam := get_node("Camera3D") as Camera3D
		if cam != null:
			cam.current = true

	# Debug rápido: confirma que a textura da SubViewport foi gerada
	if subviewport.get_texture() == null:
		print("[livro_vr] SubViewport texture is NULL")
	else:
		print("[livro_vr] SubViewport texture OK:", subviewport.get_texture())

	print("[livro_vr] running_in_xr:", running_in_xr, " viewport.use_xr:", get_viewport().use_xr)

	# Logs adicionais para diagnóstico XR: imprime transforms relevantes
	if has_node("XROrigin3D"):
		var xr_origin := get_node("XROrigin3D")
		if xr_origin != null:
			print("[livro_vr] XROrigin3D transform:", xr_origin.global_transform)
			if xr_origin.has_node("XRCamera3D"):
				var xr_cam := xr_origin.get_node("XRCamera3D")
				print("[livro_vr] XRCamera3D transform:", xr_cam.global_transform)
			if xr_origin.has_node("XRControllerLeft"):
				var xl := xr_origin.get_node("XRControllerLeft")
				print("[livro_vr] XRControllerLeft transform:", xl.global_transform)
			if xr_origin.has_node("XRControllerRight"):
				var xr := xr_origin.get_node("XRControllerRight")
				print("[livro_vr] XRControllerRight transform:", xr.global_transform)
	else:
		print("[livro_vr] XROrigin3D not found in scene tree")

	# Imprime transform da malha do livro
	if is_instance_valid(mesh_livro):
		print("[livro_vr] MeshLivro global_transform:", mesh_livro.global_transform)

	# Fallback: se não estivermos em XR, garanta uma Camera3D para visualização local
	if not running_in_xr:
		if not has_node("Camera3D"):
			var cam := Camera3D.new()
			cam.name = "Camera3D"
			add_child(cam)
			cam.current = true
			if is_instance_valid(mesh_livro):
				cam.global_transform.origin = mesh_livro.global_transform.origin + Vector3(0, 0, 2)
				cam.look_at(mesh_livro.global_transform.origin, Vector3.UP)
			else:
				cam.global_transform.origin = Vector3(0, 0, 2)
				cam.look_at(Vector3.ZERO, Vector3.UP)

	# 4. Executa as configurações procedurais de colisão e malha
	_configurar_mesh_livro()
	_configurar_area_interacao()
	_configurar_raycast()

func _process(_delta: float) -> void:
	# Se o RayCast não estiver colidindo com nada, limpa o estado do gatilho e sai
	if not is_instance_valid(raycast) or not raycast.is_colliding():
		trigger_apertado = false
		return

	var hit_point: Vector3 = raycast.get_collision_point()
	var pos_viewport: Vector2 = _world_to_viewport(hit_point)
	
	# Se a conversão de coordenadas falhar, sai
	if pos_viewport == Vector2(-1, -1):
		trigger_apertado = false
		return

	# Injeta constantemente a posição para simular o "Hover" do mouse na interface 2D
	_injetar_mouse_motion(pos_viewport)

	# Captura o input de ambos os gatilhos mapeados e mantém suporte ao clique do mouse para testes no PC
	var trigger_pressionado: bool = (
		Input.is_action_pressed("xr_standard_trigger") or 
		Input.is_action_pressed("xr_standard_trigger_esquerdo") or 
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	)
	
	# Lógica de clique único (Debounce)
	if trigger_pressionado and not trigger_apertado:
		var direcao: String = ""
		
		# Detecta toque nas extremidades laterais do livro (18% das bordas esquerda/direita)
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
	var sv_tex = null
	if subviewport != null:
		sv_tex = subviewport.get_texture()
	if sv_tex == null:
		print("[livro_vr] Aviso: SubViewport texture ausente ao configurar material; pulando aplicação de textura.")
	else:
		material.albedo_texture = sv_tex
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
	raycast.collision_mask = 1 # Garanta que a AreaInteracao está na Layer 1

func _world_to_viewport(hit_point: Vector3) -> Vector2:
	if mesh_livro == null or mesh_livro.mesh == null:
		return Vector2(-1, -1)

	# Transforma o ponto global de colisão em coordenada local da malha do livro
	var local_hit: Vector3 = mesh_livro.to_local(hit_point)
	var quad_size: Vector2 = Vector2(1.8, 1.2)
	if mesh_livro.mesh is QuadMesh:
		quad_size = (mesh_livro.mesh as QuadMesh).size

	# Normaliza a posição transformando de centro (0,0) para escala UV (0 a 1)
	var uv_hit: Vector2 = Vector2(local_hit.x, local_hit.y) / quad_size
	uv_hit += Vector2(0.5, 0.5)
	
	# Correção Crítica: Inverte o eixo Y porque na UI 2D o (0,0) fica no canto superior esquerdo
	uv_hit.y = 1.0 - uv_hit.y 
	
	uv_hit.x = clampf(uv_hit.x, 0.0, 1.0)
	uv_hit.y = clampf(uv_hit.y, 0.0, 1.0)

	return Vector2(uv_hit.x * float(subviewport.size.x), uv_hit.y * float(subviewport.size.y))

func _injetar_mouse_motion(posicao: Vector2) -> void:
	if subviewport == null:
		return

	# Evita enviar eventos de picking quando o Viewport está em stereo
	# mas a interface XR não está realmente inicializada (estado intermediário)
	if get_viewport().use_xr and not running_in_xr:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = posicao
	motion.global_position = posicao
	subviewport.push_input(motion)

func _injetar_click_virtual(posicao: Vector2) -> void:
	if subviewport == null:
		return

	# Evita enviar eventos de picking quando o Viewport está em stereo
	# mas a interface XR não está realmente inicializada
	if get_viewport().use_xr and not running_in_xr:
		return

	# Pressiona o botão esquerdo do mouse virtual na interface 2D
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = posicao
	click.global_position = posicao
	subviewport.push_input(click)

	# Solta o botão esquerdo do mouse virtual
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = posicao
	click.global_position = posicao
	subviewport.push_input(click)

func _tocar_som_pagina() -> void:
	if is_instance_valid(audio_player) and audio_player.stream != null:
		audio_player.play()
