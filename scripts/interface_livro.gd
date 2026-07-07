extends Control

var paginas: Array[String] = [
	"Página 01\n\nUma folha simples se revela com um texto inicial de teste para validar o efeito de dobra.",
	"Página 02\n\nA segunda página traz uma nova camada visual para mostrar a transição entre os blocos de conteúdo.",
	"Página 03\n\nA terceira página confirma que o livro pode continuar avançando com uma animação fluida e responsiva.",
	"Página 04\n\nA quarta página fecha a demonstração com um texto final e um visual limpo para o ambiente VR."
]

var pagina_atual: int = 0
var tela_shader: TextureRect = null
var material_shader: ShaderMaterial

func _ready() -> void:
	# Sistema de busca robusto que você já tinha implementado
	if has_node("TelaShader"):
		tela_shader = get_node("TelaShader") as TextureRect
	elif has_node("InterfaceLivro/TelaShader"):
		tela_shader = get_node("InterfaceLivro/TelaShader") as TextureRect
	else:
		tela_shader = _find_texture_rect(self)

	if tela_shader == null:
		push_error("TelaShader não encontrado em InterfaceLivro. Verifique a hierarquia da cena.")
		return

	if tela_shader.material is ShaderMaterial:
		material_shader = tela_shader.material
	else:
		material_shader = ShaderMaterial.new()
		material_shader.shader = preload("res://shaders/page_flip.gdshader")
		tela_shader.material = material_shader

	material_shader.set_shader_parameter("progress", 0.0)
	
	# Solicita que a Godot execute a renderização inicial do _draw()
	queue_redraw()

func _find_texture_rect(node: Node) -> TextureRect:
	for child in node.get_children():
		if child is TextureRect:
			return child
		if child.get_child_count() > 0:
			var found := _find_texture_rect(child)
			if found != null:
				return found
	return null

func folhear_pagina(direcao: String) -> void:
	var proxima_pagina: int = pagina_atual
	if direcao == "direita":
		proxima_pagina = min(pagina_atual + 1, paginas.size() - 1)
	elif direcao == "esquerda":
		proxima_pagina = max(pagina_atual - 1, 0)

	if proxima_pagina == pagina_atual:
		return

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material_shader, "shader_parameter/progress", 1.0, 0.6)
	await tween.finished

	pagina_atual = proxima_pagina
	
	# Força o Control a se redesenhar com o novo texto da página
	queue_redraw()
	material_shader.set_shader_parameter("progress", 0.0)

# A MÁGICA DA GODOT 4 acontece aqui: usando a engine gráfica nativa
func _draw() -> void:
	# 1. Desenha o fundo da página (Estilo papel antigo/creme)
	draw_rect(Rect2(0, 0, 1024, 512), Color(0.95, 0.92, 0.86, 1.0))

	# 2. Desenha uma borda/destaque sutil
	var destaque := Rect2(48, 48, 928, 416)
	draw_rect(destaque, Color(0.96, 0.94, 0.88, 1.0))
	draw_rect(destaque, Color(0.35, 0.25, 0.18, 0.2), false, 3.0)

	# 3. Renderiza as strings de texto de forma nativa e leve
	var fonte := ThemeDB.fallback_font
	var texto := paginas[pagina_atual]
	var linhas := texto.split("\n")
	var y_offset: int = 96
	
	for linha in linhas:
		if linha.strip_edges() != "":
			draw_string(fonte, Vector2(96, y_offset), linha, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.2, 0.18, 0.16, 1.0))
		y_offset += 48
