extends Control

signal fechado
const UI: Script = preload("res://estilo_ui_fiel.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const VISUAL: Script = preload("res://visual_pokemon.gd")
const FICHA_POKEMON: Script = preload("res://ficha_pokemon_depot.gd")
var familia: OptionButton
var filtros_pendentes: Array[Button] = []
const DOURADO: Color = Color("c8aa6e")
const TEXTO: Color = Color("f0e6d2")
const GRADES: Array[String] = ["Fraca", "Comum", "Incomum", "Rara", "Épica", "Lendária", "Mítica", "Anciã", "Divina"]
const CORES: Array[String] = ["9aa6b3", "63d873", "7fd4ff", "b06cff", "f0c040", "ff8c3c", "6a0dad", "b8860b", "dbefff"]
var janela: PanelContainer
var conteudo: VBoxContainer
var corpo: VBoxContainer
var busca: LineEdit
var categoria: OptionButton
var ordem: OptionButton
var faixas: Array[LineEdit] = []
var colunas: Array[VBoxContainer] = []
var contador: Label
var mensagem: Label
var guardar_todos: Button
var abas: Array[Button] = []
var ocultas: Dictionary = {}
var aba: int = 0
var modo: String = "convite"
var animacao: Tween
var tamanho_base: Vector2 = Vector2(600, 760)
var icones_pokemon: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tema: Theme = Theme.new()
	tema.default_font_size = 12
	tema.default_font = UI.FORTE
	for classe in ["Label", "Button", "OptionButton", "LineEdit"]:
		tema.set_color("font_color", classe, TEXTO)
		tema.set_color("font_hover_color", classe, Color.WHITE)
		tema.set_color("font_disabled_color", classe, Color("687787"))
		for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
			if classe == "Label":
				continue
			tema.set_stylebox(estado, classe, estilo("0c1721" if estado != "hover" else "203544", "384552", 6, 8))
	tema.set_stylebox("panel","TooltipPanel",StyleBoxEmpty.new())
	theme = tema
	var sombra: ColorRect = ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			fechar()
	)
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", estilo("101f29", "b79a57", 10, 12))
	add_child(janela)
	conteudo = VBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 10)
	janela.add_child(conteudo)
	resized.connect(_ajustar)
	hide()

func estilo(fundo: String, borda: String, raio: int, margem: int) -> StyleBoxFlat:
	var e: StyleBoxFlat = StyleBoxFlat.new()
	e.bg_color = Color(fundo)
	e.border_color = Color(borda)
	e.set_border_width_all(1)
	e.set_corner_radius_all(raio)
	e.content_margin_left = margem
	e.content_margin_right = margem
	e.content_margin_top = margem
	e.content_margin_bottom = margem
	return e

func rotulo(texto: String, tamanho: int = 13, cor: Color = TEXTO) -> Label:
	var label: Label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", cor)
	return label

func botao(texto: String, acao: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texto
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 32
	b.pressed.connect(acao)
	return b

func _limpar(container: Node) -> void:
	for filho in container.get_children():
		container.remove_child(filho)
		filho.queue_free()

func _cabecalho() -> void:
	var placa: PanelContainer = PanelContainer.new()
	var estilo_cabecalho: StyleBoxTexture = StyleBoxTexture.new()
	estilo_cabecalho.texture = load("res://assets/interface/depot/cabecalho.svg")
	estilo_cabecalho.texture_margin_left = 20
	estilo_cabecalho.texture_margin_right = 20
	estilo_cabecalho.texture_margin_top = 8
	estilo_cabecalho.texture_margin_bottom = 8
	estilo_cabecalho.content_margin_left = 22
	estilo_cabecalho.content_margin_right = 16
	placa.add_theme_stylebox_override("panel", estilo_cabecalho)
	placa.custom_minimum_size.y = 44
	conteudo.add_child(placa)
	var linha: HBoxContainer = HBoxContainer.new()
	placa.add_child(linha)
	var titulo: Label = rotulo("📁 Depot", 17, DOURADO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ResourceLoader.exists("res://assets/interface/depot/cinzel.ttf"):
		titulo.add_theme_font_override("font", UI.TITULO)
	linha.add_child(titulo)
	linha.add_child(botao("×", fechar))
	var divisor: HSeparator = HSeparator.new()
	conteudo.add_child(divisor)

func abrir_convite() -> void:
	EstadoJogo.iniciar_depot()
	modo = "convite"
	_limpar(conteudo)
	_cabecalho()
	conteudo.add_child(rotulo("Guarda seus itens no depósito.", 13, Color("a5b0bd")))
	var abrir: Button = botao("Open Depot", abrir_depot)
	abrir.add_theme_stylebox_override("normal", estilo("b99b52", "f1d88d", 5, 8))
	abrir.add_theme_color_override("font_color", Color("171818"))
	conteudo.add_child(abrir)
	tamanho_base = Vector2(330, 175)
	_exibir()

func abrir_depot() -> void:
	modo = "depot"
	aba = 0
	ocultas.clear()
	_limpar(conteudo)
	_cabecalho()
	var linha: HBoxContainer = HBoxContainer.new()
	linha.add_theme_constant_override("separation", 5)
	conteudo.add_child(linha)
	abas.clear()
	var nomes: Array[String] = ["🎒 Items", "⚔ Pokémon", "🥚 Breeding Box", "👨‍👩‍👧 Família: Itens", "👨‍👩‍👧 Família: Pokémon"]
	for i in range(nomes.size()):
		var b: Button = botao(nomes[i], _mudar_aba.bind(i))
		b.add_theme_font_size_override("font_size", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 40
		if i >= 2:
			b.disabled = true
			b.tooltip_text = "Reprodução e família ainda não estão disponíveis nesta versão offline."
		linha.add_child(b)
		abas.append(b)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	conteudo.add_child(corpo)
	tamanho_base = Vector2(600, 784)
	_construir_corpo()
	_exibir()

func _exibir() -> void:
	show()
	_ajustar()
	if animacao != null:
		animacao.kill()
	janela.modulate.a = 0.0
	animacao = create_tween()
	animacao.tween_property(janela, "modulate:a", 1.0, 0.12)

func _ajustar() -> void:
	if janela == null:
		return
	var fator: float = minf(1.0, minf((size.x - 24.0) / tamanho_base.x, (size.y - 24.0) / tamanho_base.y))
	fator = maxf(0.1, fator)
	janela.size = Vector2.ZERO
	var tam := Vector2(tamanho_base.x, janela.get_combined_minimum_size().y)
	janela.size = tam
	janela.scale = Vector2.ONE * fator
	janela.position = ((size - tam * fator) * 0.5).round()

func fechar() -> void:
	if animacao != null:
		animacao.kill()
	hide()
	fechado.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		fechar()
		get_viewport().set_input_as_handled()

func _mudar_aba(indice: int) -> void:
	if indice > 1:
		return
	aba = indice
	ocultas.clear()
	_construir_corpo()

func _construir_corpo() -> void:
	_limpar(corpo)
	faixas.clear()
	filtros_pendentes.clear()
	colunas.clear()
	for i in range(abas.size()):
		abas[i].add_theme_stylebox_override("normal", estilo("282a23" if i == aba else "14242f", "c8aa6e" if i == aba else "384552", 0, 6))
	var filtros: VBoxContainer = VBoxContainer.new()
	corpo.add_child(filtros)
	var linha: HBoxContainer = HBoxContainer.new()
	filtros.add_child(linha)
	busca = LineEdit.new()
	busca.placeholder_text = "Search item..." if aba == 0 else "Search Pokémon..."
	busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	busca.custom_minimum_size = Vector2(150,32)
	linha.add_child(busca)
	busca.text_changed.connect(func(_s: String) -> void: atualizar_listas())
	if aba == 1:
		familia = OptionButton.new()
		familia.fit_to_longest_item = false
		familia.clip_text = true
		familia.add_item("All families")
		familia.custom_minimum_size.x = 102
		familia.disabled = true
		familia.tooltip_text = "Família —. Prioridade P1: confirmar a definição desse filtro no cliente original."
		linha.add_child(familia)
	categoria = OptionButton.new()
	categoria.fit_to_longest_item = false
	categoria.clip_text = true
	categoria.custom_minimum_size.x = 122
	categoria.add_item("All categories" if aba == 0 else "All types")
	if aba == 0:
		for valor in ["Potions","Materials"]: categoria.add_item(valor)
	else:
		for chave in TIPOS.CORES:
			categoria.add_item(str(chave).capitalize())
			categoria.set_item_metadata(categoria.item_count-1,chave)
	linha.add_child(categoria)
	if aba == 1:
		for dados in [["✨","Shiny —"],["◉","Vínculo/estado especial —"],["▣","Held —"]]:
			var pendente: Button = Button.new()
			pendente.text = dados[0]
			pendente.custom_minimum_size = Vector2(28,30)
			pendente.disabled = true
			pendente.tooltip_text = str(dados[1])+". Campo ainda não modelado/confirmado; ver PRIORIDADES_DEPOT.md."
			linha.add_child(pendente)
			filtros_pendentes.append(pendente)
	categoria.item_selected.connect(func(_i: int) -> void: atualizar_listas())
	ordem = OptionButton.new()
	for valor in ["Default order", "Name A–Z", "Name Z–A", "Quantity ↓" if aba == 0 else "Level ↓", "Quantity ↑" if aba == 0 else "IV ↓"]:
		ordem.add_item(valor)
	if aba == 1:
		ordem.add_item("Power ↓")
		ordem.add_item("Quality ↓")
	if aba == 0:
		linha.add_child(ordem)
	else:
		var limites: HBoxContainer = HBoxContainer.new()
		filtros.add_child(limites)
		for nome in ["Lv", "IV", "Q"]:
			limites.add_child(rotulo(nome, 11, Color("9fb0c8")))
			for placeholder in ["from", "to"]:
				var entrada: LineEdit = LineEdit.new()
				entrada.placeholder_text = placeholder
				entrada.custom_minimum_size = Vector2(52, 30)
				entrada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				limites.add_child(entrada)
				faixas.append(entrada)
				entrada.text_changed.connect(func(_s: String) -> void: atualizar_listas())
		filtros.add_child(ordem)
		var grades: HBoxContainer = HBoxContainer.new()
		grades.add_theme_constant_override("separation", 3)
		filtros.add_child(grades)
		for i in range(GRADES.size()):
			var b: Button = Button.new()
			b.text = GRADES[i]
			b.toggle_mode = true
			b.button_pressed = true
			b.add_theme_font_size_override("font_size", 10)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_color_override("font_color", Color(CORES[i]))
			b.add_theme_color_override("font_pressed_color", Color(CORES[i]))
			b.add_theme_stylebox_override("pressed", estilo("0d1923", CORES[i], 5, 4))
			b.toggled.connect(_alternar_grade.bind(i, b))
			grades.add_child(b)
	ordem.item_selected.connect(func(_i: int) -> void: atualizar_listas())
	var listas: HBoxContainer = HBoxContainer.new()
	listas.add_theme_constant_override("separation", 10)
	corpo.add_child(listas)
	for titulo in (["BAG", "DEPOT"] if aba == 0 else ["TEAM", "BOX"]):
		var lado: VBoxContainer = VBoxContainer.new()
		lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		listas.add_child(lado)
		var cabecalho_lista: Label = rotulo(("⚔ " if titulo=="TEAM" else "▣ ")+titulo, 12, DOURADO)
		cabecalho_lista.add_theme_font_override("font",UI.TITULO)
		lado.add_child(cabecalho_lista)
		lado.add_child(HSeparator.new())
		var painel: PanelContainer = PanelContainer.new()
		painel.add_theme_stylebox_override("panel", estilo("09151d", "34414b", 6, 6))
		lado.add_child(painel)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		painel.add_child(scroll)
		var lista: VBoxContainer = VBoxContainer.new()
		lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lista.add_theme_constant_override("separation", 6)
		scroll.add_child(lista)
		colunas.append(lista)
	var rodape: HBoxContainer = HBoxContainer.new()
	corpo.add_child(rodape)
	var chip := PanelContainer.new()   # A (v1_00131): "📦 1/200 SLOTS" numa pílula escura com borda dourada
	chip.add_theme_stylebox_override("panel", estilo("1b2128", "6a5223", 7, 7))
	rodape.add_child(chip)
	contador = rotulo("", 12, DOURADO)
	contador.add_theme_font_override("font", UI.TITULO)
	chip.add_child(contador)
	var espaco: Control = Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(espaco)
	guardar_todos = botao("Store all", _guardar_todos)
	guardar_todos.visible = aba == 0
	var sg := estilo("c9a85a", "6a5223", 8, 10)   # A (v1_00131): botão dourado grande
	sg.content_margin_left = 24; sg.content_margin_right = 24
	guardar_todos.add_theme_stylebox_override("normal", sg)
	guardar_todos.add_theme_font_size_override("font_size", 14)
	guardar_todos.custom_minimum_size.y = 40
	guardar_todos.add_theme_color_override("font_color", Color("171818"))
	rodape.add_child(guardar_todos)
	mensagem = rotulo("", 12, Color("9fb0c8"))
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corpo.add_child(mensagem)
	atualizar_listas()

func _alternar_grade(ativo: bool, indice: int, b: Button) -> void:
	if ativo:
		ocultas.erase(indice)
	else:
		ocultas[indice] = true
	b.modulate.a = 1.0 if ativo else 0.45
	atualizar_listas()

func _grade(p: DadosPokemon) -> int:
	var nomes: Array[String] = ["Weak", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Ancient", "Divine"]
	return maxi(0, nomes.find(p.obter_classificacao()))

func corresponde_pokemon(p: DadosPokemon) -> bool:
	if p == null or p.especie == null:
		return false
	if not busca.text.strip_edges().is_empty() and not p.especie.nome.to_lower().contains(busca.text.strip_edges().to_lower()):
		return false
	if ocultas.has(_grade(p)):
		return false
	if categoria.selected > 0:
		var tipo: String = str(categoria.get_item_metadata(categoria.selected))
		var base: Dictionary = preload("res://regras_pokemon.gd").obter_base(p.especie.nome)
		if tipo!=str(base.get("type1","")) and tipo!=str(base.get("type2","")):
			return false
	var valores: Array[float] = [float(p.nivel), float(p.obter_total_ivs()), p.qualidade]
	for i in range(faixas.size()):
		var texto: String = faixas[i].text.strip_edges().replace(",", ".")
		if texto.is_empty():
			continue
		if not texto.is_valid_float():
			return false
		var valor: float = valores[i / 2]
		if (i % 2 == 0 and valor < texto.to_float()) or (i % 2 == 1 and valor > texto.to_float()):
			return false
	return true

func atualizar_listas() -> void:
	if colunas.size() != 2:
		return
	for coluna in colunas:
		_limpar(coluna)
	if aba == 0:
		var itens: Array[Dictionary] = EstadoJogo.catalogo_itens_depot()
		for lado in range(2):
			var visiveis: Array[Dictionary] = []
			for item in itens:
				var quantidade: int = EstadoJogo.quantidade_item_bag(int(item["id"])) if lado == 0 else int(EstadoJogo.itens_depot.get(int(item["id"]), 0))
				if quantidade <= 0 or (not busca.text.strip_edges().is_empty() and not str(item["nome"]).to_lower().contains(busca.text.strip_edges().to_lower())):
					continue
				if categoria.selected > 0 and str(item["categoria"]) != categoria.get_item_text(categoria.selected):
					continue
				var linha: Dictionary = item.duplicate()
				linha["quantidade"] = quantidade
				visiveis.append(linha)
			visiveis.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if ordem.selected == 2: return str(a["nome"]) > str(b["nome"])
				if ordem.selected == 3: return int(a["quantidade"]) > int(b["quantidade"])
				if ordem.selected == 4: return int(a["quantidade"]) < int(b["quantidade"])
				return str(a["nome"]) < str(b["nome"])
			)
			for item in visiveis:
				var icone: Texture2D = preload("res://regras_loot.gd").textura(str(item["icone"]))   # res:// ou ícone do snapshot
				var b: Button = _cartao(colunas[lado], item["nome"], str(item["quantidade"]) + "×", icone, lado == 0, _mover_item.bind(int(item["id"]), lado == 0))
				b.tooltip_text = "Item vinculado: permanece na BAG." if item["vinculado"] else "Transferir a pilha inteira."
				b.disabled = bool(item["vinculado"])
		contador.text = "📦 %d/%d SLOTS" % [EstadoJogo.itens_depot.size(), EstadoJogo.CAPACIDADE_DEPOT]
	else:
		for lado in range(2):
			var origem: Array = EstadoJogo.time_pokemon if lado == 0 else EstadoJogo.pokemons_capturados
			var visiveis: Array = origem.filter(corresponde_pokemon)
			if ordem.selected != 0:
				visiveis.sort_custom(func(a: DadosPokemon, b: DadosPokemon) -> bool:
					if ordem.selected == 2: return a.especie.nome > b.especie.nome
					if ordem.selected == 3: return a.nivel > b.nivel
					if ordem.selected == 4: return a.obter_total_ivs() > b.obter_total_ivs()
					if ordem.selected == 5: return a.obter_power() > b.obter_power()
					if ordem.selected == 6: return a.qualidade > b.qualidade
					return a.especie.nome < b.especie.nome
				)
			for p: DadosPokemon in visiveis:
				var b: CartaoPokemonDepot = CartaoPokemonDepot.new()
				colunas[lado].add_child(b)
				b.configurar(p,lado==0,p==EstadoJogo.obter_lider(),p==EstadoJogo.pokemon_inicial)
				b.pressed.connect(_mover_pokemon.bind(p,lado==0))
		contador.text = "%d/%d TEAM" % [EstadoJogo.time_pokemon.size(), EstadoJogo.LIMITE_TIME]
		mensagem.text = "Store in the Box or send to the team (max. 6)."
	for coluna in colunas:
		if coluna.get_child_count() == 0:
			var vazio: Label = rotulo("Nenhum resultado.", 12, Color("81909f"))
			vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			coluna.add_child(vazio)
	_ajustar_altura()


func _ajustar_altura() -> void:
	## A (vídeo, quadro v1_00131): a janela do Depot tem a altura do conteúdo — as listas crescem com as linhas (até
	## 7 linhas visíveis, depois rolam), em vez de uma caixa fixa de 784 px.
	var alto := 0.0
	for coluna in colunas:
		alto = maxf(alto, coluna.get_combined_minimum_size().y)
	for coluna in colunas:
		var sc := coluna.get_parent() as ScrollContainer
		if sc != null:
			sc.custom_minimum_size.y = clampf(alto, 54.0, 7.0 * 60.0)
	_ajustar()

func _cartao(lista: VBoxContainer, nome: String, info: String, icone: Texture2D, guardar: bool, acao: Callable, cor: Color = Color("a6b4c6")) -> Button:
	var b: Button = botao("", acao)
	b.custom_minimum_size.y = 54
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_child(b)
	var linha: HBoxContainer = HBoxContainer.new()
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 8
	linha.offset_top = 5
	linha.offset_right = -8
	linha.offset_bottom = -5
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(linha)
	var imagem: TextureRect = TextureRect.new()
	imagem.custom_minimum_size = Vector2(32, 32)
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.texture = icone
	imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(imagem)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(textos)
	var titulo: Label = rotulo(nome, 13)
	titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(titulo)
	var legenda: Label = rotulo(info, 10, cor)
	legenda.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(legenda)
	var seta: Label = rotulo("→" if guardar else "←", 17, DOURADO)
	seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(seta)
	return b

func _mover_item(id: int, guardar: bool) -> void:
	var erro: String = EstadoJogo.mover_item_depot(id, guardar)
	atualizar_listas()
	mensagem.text = erro if not erro.is_empty() else "Item transferido."

func _mover_pokemon(p: DadosPokemon, guardar: bool) -> void:
	var erro: String = EstadoJogo.mover_pokemon_depot(p, guardar)
	atualizar_listas()
	mensagem.text = erro if not erro.is_empty() else "Pokémon transferido."

func _guardar_todos() -> void:
	var resultado: String = EstadoJogo.guardar_todos_itens_depot()
	atualizar_listas()
	mensagem.text = resultado

func _icone_pokemon(p: DadosPokemon) -> Texture2D:
	var retrato: Texture2D = VISUAL.retrato_frente(p.especie.nome)
	return retrato if retrato!=null else p.especie.textura
