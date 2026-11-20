extends Control
## Criar personagem (ciclo 4: igual ao original). Fonte C: página /create-character do cliente — CSS `.cc-*` (fundo em
## gradiente radial com a splash art a 7%, título Cinzel dourado, cartões de 208 px com halo da cor do tipo, "✓ Escolhido"
## e borda dourada no escolhido, "ESCOLHA SEU TREINADOR" com Menino/Menina, nome de 3 a 16 letras, botão de começar,
## versão no canto) e os textos `createCharacter` do pacote; A: o vídeo do usuário (referencia_visual/quadros/
## 03_criar_personagem). Só os três iniciais do original (o Geodude saiu no ciclo 4). Ao começar: "Carregando…" e a cidade
## recarrega com o tutorial do Professor Oak. Regras em sim/servico_novo_jogo.gd (EstadoJogo.novo_jogo).
## Fora do offline: "‹ Voltar (trocar conta)" (não há conta).

const T := preload("res://textos.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
const Outfits := preload("res://render/outfits.gd")
const CINZEL: Font = preload("res://assets/interface/fiel/cinzel_extrabold.ttf")
const CINZEL_B: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const BARLOW: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const OURO := Color("c9a86a")
const TIPO_COR := {"GRASS": Color("63bc5a"), "FIRE": Color("ff9d55"), "WATER": Color("4d90d5"), "POISON": Color("ab6ac8")}
const TIPO_NOME := {"GRASS": "Planta", "FIRE": "Fogo", "WATER": "Água", "POISON": "Veneno"}
const GENEROS := [["male", 159], ["female", 160]]   # A (outfits-index): "Trainer" masculino 159 e feminino 160
const CORES_PADRAO := {"head": 94, "body": 95, "legs": 0, "feet": 0}

signal concluido(resultado: Dictionary)
var escolhido := -1
var genero := ""
var nome: LineEdit
var cartoes := {}
var cartoes_genero := {}
var erro: Label
var botao: Button
var _outfits = null
var _anim: Array = []   # [TextureRect, quadros[AtlasTexture]]
var _t := 0.0
var _conteudo: Control
const ESCALA_REFERENCIA := 1880.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_outfits = Outfits.padrao()
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.material = _gradiente()
	add_child(fundo)
	var arte := TextureRect.new()
	arte.texture = load("res://assets/original/images/splash-art-login.png")
	arte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arte.modulate = Color(0.72, 0.78, 0.88, 0.09)   # C: opacity .07 e saturate(.6) sobre o gradiente (0,09 iguala o vídeo)
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arte)
	# As medidas são as do CSS do original (px de uma tela de 1880 de largura, a área do navegador nos vídeos); o conteúdo é
	# escalado para a largura real da janela (ESCALA_REFERENCIA).
	var col := VBoxContainer.new()
	col.name = "Conteudo"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	_conteudo = col
	resized.connect(_posicionar)
	col.add_child(_titulo(T.t("createCharacter.title"), 26))
	_espaco(col, 8)
	col.add_child(_texto(T.t("createCharacter.subtitle"), 14, Color("9fb0c2")))
	_espaco(col, 30)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	col.add_child(cards)
	var dados = preload("res://ponte_cidade.gd").dados()
	for id in NovoJogo.INICIAIS:
		var c := _cartao_inicial(int(id), dados.especie(int(id)))
		cards.add_child(c)
		cartoes[int(id)] = c
	_espaco(col, 28)
	col.add_child(_titulo(T.t("createCharacter.trainerTitle"), 22))
	_espaco(col, 14)
	var gens := HBoxContainer.new()
	gens.alignment = BoxContainer.ALIGNMENT_CENTER
	gens.add_theme_constant_override("separation", 16)
	col.add_child(gens)
	for par in GENEROS:
		var g := _cartao_genero(String(par[0]), int(par[1]))
		gens.add_child(g)
		cartoes_genero[String(par[0])] = g
	_espaco(col, 30)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 360
	form.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	form.add_theme_constant_override("separation", 8)
	col.add_child(form)
	form.add_child(_texto(T.t("createCharacter.nameLabel").to_upper(), 12, Color("8a93a0")))
	nome = LineEdit.new()
	nome.name = "Nome"
	nome.placeholder_text = T.t("createCharacter.namePlaceholder")
	nome.max_length = 16
	nome.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.custom_minimum_size = Vector2(360, 48)
	nome.add_theme_font_override("font", BARLOW)
	nome.add_theme_font_size_override("font_size", 15)
	nome.add_theme_color_override("font_color", Color("e9e2d0"))
	nome.add_theme_stylebox_override("normal", _caixa(Color(0, 0, 0, 0.34), Color("8ca5be29"), 8))
	nome.add_theme_stylebox_override("focus", _caixa(Color(0, 0, 0, 0.34), OURO, 8))
	nome.text_changed.connect(func(_t2: String) -> void: _atualizar())
	form.add_child(nome)
	_espaco(form, 8)
	botao = Button.new()
	botao.name = "Comecar"
	botao.text = T.t("createCharacter.startJourney")
	botao.custom_minimum_size = Vector2(360, 50)
	botao.add_theme_font_override("font", CINZEL_B)
	botao.add_theme_font_size_override("font_size", 15)
	botao.add_theme_color_override("font_color", Color("f6e8c4"))
	botao.add_theme_color_override("font_disabled_color", Color("f6e8c480"))
	botao.add_theme_stylebox_override("normal", _caixa(Color("8a6d3b"), Color("c9a86a"), 6))
	botao.add_theme_stylebox_override("hover", _caixa(Color("a5834a"), Color("e2c983"), 6))
	botao.add_theme_stylebox_override("pressed", _caixa(Color("6b5226"), Color("c9a86a"), 6))
	botao.add_theme_stylebox_override("disabled", _caixa(Color("5a4828b0"), Color("c9a86a60"), 6))
	botao.pressed.connect(_comecar)
	form.add_child(botao)
	erro = _texto("", 12.5, Color("ff8a7a"))
	form.add_child(erro)
	var versao := _texto(T.t("createCharacter.version"), 11, Color("8a93a080"))
	versao.anchor_left = 1.0; versao.anchor_right = 1.0; versao.anchor_top = 1.0; versao.anchor_bottom = 1.0
	versao.offset_left = -300; versao.offset_right = -16; versao.offset_top = -28; versao.offset_bottom = -10
	versao.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(versao)
	_atualizar()
	_posicionar.call_deferred()


func _posicionar() -> void:
	if _conteudo == null:
		return
	var f := size.x / ESCALA_REFERENCIA
	_conteudo.reset_size()
	_conteudo.scale = Vector2(f, f)
	_conteudo.position = (size - _conteudo.size * f) * 0.5


func _gradiente() -> ShaderMaterial:
	## C: radial-gradient(120% 100% at 50% 0, #16243a 0%, #0a1018 55%, #05080d 100%)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.0)) / vec2(1.2, 1.0);
	float d = clamp(length(p), 0.0, 1.0);
	vec3 a = vec3(0.086, 0.141, 0.227); vec3 b = vec3(0.039, 0.063, 0.094); vec3 c = vec3(0.020, 0.031, 0.051);
	COLOR = vec4(d < 0.55 ? mix(a, b, d / 0.55) : mix(b, c, (d - 0.55) / 0.45), 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _fonte_espacada(f: Font, espaco: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = f
	v.spacing_glyph = espaco
	return v


func _titulo(t: String, tam: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _fonte_espacada(CINZEL, int(round(tam * 0.16))))   # C: letter-spacing .16em
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", OURO)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _texto(t: String, tam: float, cor: Color, fonte: Font = BARLOW) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", int(round(tam)))
	l.add_theme_color_override("font_color", cor)
	return l


func _espaco(pai: Control, h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	pai.add_child(c)


func _caixa(fundo: Color, borda: Color, raio: int, largura: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(raio)
	return s


func _sprite(looktype: int, cores: Dictionary, escala: float, andar: bool) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var o: Dictionary = _outfits.obter(looktype, cores)
	var qs: Array = []
	for i in (3 if andar else 1):
		var q: Dictionary = _outfits.quadro(o, 2 if andar else 3, i)   # treinador andando para a direita (vídeo); inicial de frente
		if q.is_empty():
			continue
		var at := AtlasTexture.new()
		at.atlas = q["tex"]
		at.region = q["rect"]
		qs.append(at)
	if not qs.is_empty():
		tr.texture = qs[0]
		tr.custom_minimum_size = (qs[0] as AtlasTexture).region.size * escala
	if andar and qs.size() > 1:
		_anim.append([tr, qs])
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _cartao_inicial(id: int, e: Dictionary) -> PanelContainer:
	var tipos: Array = e.get("tipos", [])
	var cor: Color = TIPO_COR.get(String(tipos[0]) if not tipos.is_empty() else "", OURO)
	var c := PanelContainer.new()
	c.name = "Inicial_%d" % id
	c.custom_minimum_size = Vector2(208, 0)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(col)
	var caixa := Control.new()   # .cc-spritebox: 150 px, halo atrás
	caixa.custom_minimum_size = Vector2(178, 150)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caixa)
	var halo := ColorRect.new()
	halo.size = Vector2(130, 130)
	halo.position = Vector2((178 - 130) * 0.5, 10)
	halo.material = _halo(cor)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(halo)
	var sp := _sprite(int(e.get("looktype", 0)), {}, 1.6, false)
	sp.size = sp.custom_minimum_size
	sp.position = Vector2((178 - sp.size.x) * 0.5, 150 - sp.size.y - 6)
	caixa.add_child(sp)
	var n := _texto(String(e.get("nome", "")), 17, Color.WHITE, CINZEL_B)   # Cinzel: minúsculas viram versalete
	n.add_theme_font_override("font", _fonte_espacada(CINZEL_B, 1))
	col.add_child(n)
	var tags: Array = []
	for t in tipos:
		tags.append(TIPO_NOME.get(String(t), String(t).capitalize()))
	col.add_child(_texto(" / ".join(PackedStringArray(tags)), 12.5, cor))
	var pick := _texto(T.t("createCharacter.chosen"), 12, OURO)
	pick.name = "Escolhido"
	col.add_child(pick)
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			escolher_inicial(id))
	return c


func _halo(cor: Color) -> ShaderMaterial:
	## C: .cc-halo radial-gradient(circle, var(--accent) 0%, transparent 68%); opacity .32
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 cor : source_color;
void fragment() { float d = length(UV - vec2(0.5)) * 2.0; COLOR = vec4(cor.rgb, cor.a * clamp(1.0 - d / 0.68, 0.0, 1.0)); }"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("cor", Color(cor.r, cor.g, cor.b, 0.42))   # C: .32 com blur(2px); 0,42 iguala o vídeo
	return m


func _cartao_genero(g: String, looktype: int) -> PanelContainer:
	var c := PanelContainer.new()
	c.name = "Genero_" + g
	c.custom_minimum_size = Vector2(132, 0)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(col)
	var caixa := CenterContainer.new()
	caixa.custom_minimum_size = Vector2(110, 96)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caixa)
	caixa.add_child(_sprite(looktype, CORES_PADRAO, 1.4, true))
	col.add_child(_texto(T.t("createCharacter.genderMale" if g == "male" else "createCharacter.genderFemale"), 14, Color.WHITE, CINZEL_B))
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			escolher_genero(g))
	return c


func escolher_inicial(id: int) -> void:
	escolhido = id
	_atualizar()


func escolher_genero(g: String) -> void:
	genero = g
	_atualizar()


func _atualizar() -> void:
	for id in cartoes:
		var c: PanelContainer = cartoes[id]
		var sel := int(id) == escolhido
		var s := _caixa(Color("0a101ab8"), OURO if sel else Color("8ca5be29"), 14, 2 if sel else 1)
		s.set_content_margin_all(14)
		if sel:
			s.shadow_color = Color(0, 0, 0, 0.5)
			s.shadow_size = 14
		c.add_theme_stylebox_override("panel", s)
		(c.find_child("Escolhido", true, false) as Label).modulate.a = 1.0 if sel else 0.0
	for g in cartoes_genero:
		var c: PanelContainer = cartoes_genero[g]
		var sel: bool = g == genero
		var s := _caixa(Color("0a101ab8"), OURO if sel else Color("8ca5be29"), 12, 2 if sel else 1)
		s.set_content_margin_all(10)
		c.add_theme_stylebox_override("panel", s)
	var n := nome.text.strip_edges() if nome != null else ""
	if botao != null:
		botao.disabled = escolhido < 0 or genero == "" or n.length() < 3


func escolher(id: int, nome_treinador: String = "", g: String = "male") -> Dictionary:
	## Atalho para testes e a verificação do build: escolhe tudo e começa.
	escolhido = id
	genero = g
	if nome_treinador != "":
		nome.text = nome_treinador
	elif nome.text.strip_edges().length() < 3:
		nome.text = "Treinador"
	return _comecar()


func _comecar() -> Dictionary:
	var n := nome.text.strip_edges()
	if escolhido < 0 or genero == "" or n.length() < 3:
		erro.text = T.t("createCharacter.namePlaceholder")
		return {"erro": "incompleto"}
	var ej: Node = get_node("/root/EstadoJogo")
	var r: Dictionary = ej.novo_jogo(escolhido, n)
	if r.has("erro"):
		erro.text = String(r["erro"])
		return r
	ej.visual = {"looktype": 159 if genero == "male" else 160, "genero": genero, "cores": CORES_PADRAO.duplicate()}
	ej.solicitar_salvamento()
	botao.text = T.t("createCharacter.creating")
	botao.disabled = true
	# C: depois de criar, "Carregando…" e o jogo abre na cidade com o tutorial
	var carr := ColorRect.new()
	carr.name = "Carregando"
	carr.color = Color("0a0f17")
	carr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(carr)
	var lc := _texto(T.t("createCharacter.loading"), 14, Color("8a93a0"))
	lc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	carr.add_child(lc)
	concluido.emit(r)
	if is_inside_tree() and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://cidade.tscn":
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if is_inside_tree():
				get_tree().reload_current_scene())
	return r


func _process(d: float) -> void:
	_t += d
	if _t < 0.15:   # a animação de andar troca de quadro a ~150 ms
		return
	_t = 0.0
	for a in _anim:
		var tr: TextureRect = a[0]
		var qs: Array = a[1]
		var i := qs.find(tr.texture)
		tr.texture = qs[(i + 1) % qs.size()]
