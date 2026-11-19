extends RefCounted
## Liga os ícones do dock (menu_superior_original.gd, sinal janela_solicitada) às janelas do ciclo 2, na cidade e na
## hunt: Perfil, Gerenciamento de Captura (Bolas usadas), Log de Capturas, Hunt Analyser (só na hunt), Streak/Talentos,
## Diário/Quests e Pokédex. Cada janela é criada uma vez por cena, sob `pai`.

static func instalar(pai: Node, menu: Control, controlador_hunt: Node = null, abrir_pokedex: Callable = Callable()) -> Dictionary:
	var j := {}
	j["perfil"] = _criar(pai, "res://painel_perfil.gd", "PainelPerfil")
	j["bolas"] = _criar(pai, "res://painel_bolas_usadas.gd", "PainelBolasUsadas")
	j["log"] = _criar(pai, "res://painel_log_capturas.gd", "PainelLogCapturas")
	j["pokedex"] = _criar(pai, "res://painel_pokedex.gd", "PainelPokedex")
	j["shinys"] = _criar(pai, "res://painel_todos_shinys.gd", "PainelTodosShinys")
	j["inventario"] = _criar(pai, "res://painel_inventario.gd", "PainelInventario")
	j["ginasios"] = _criar(pai, "res://painel_ginasios.gd", "PainelGinasios")
	j["bosses"] = _criar(pai, "res://painel_bosses.gd", "PainelBosses")
	j["bosses"].na_hunt = controlador_hunt != null   # C: Auto Boss só fora de hunt
	j["itens_uso"] = pai.get_node_or_null("PainelItensUso")
	if j["itens_uso"] == null:
		j["itens_uso"] = _criar(pai, "res://painel_itens_uso.gd", "PainelItensUso")
	j["inventario"].usar_solicitado.connect(func() -> void: j["itens_uso"].abrir())
	j["pokedex"].todos_shinys_solicitado.connect(func() -> void: j["shinys"].abrir())
	j["streak"] = pai.get_node_or_null("PainelStreak")
	if j["streak"] == null:
		j["streak"] = _criar(pai, "res://painel_streak.gd", "PainelStreak")
	j["diarias"] = pai.get_node_or_null("PainelDiarias")
	if j["diarias"] == null:
		j["diarias"] = _criar(pai, "res://painel_diarias.gd", "PainelDiarias")
	j["visual"] = _criar(pai, "res://painel_visual.gd", "PainelVisual")
	j["perfil"].visual_solicitado.connect(func() -> void:
		j["perfil"].hide()
		j["visual"].abrir())
	j["visual"].salvo.connect(func(v: Dictionary) -> void:
		var cena := pai.get_tree().current_scene
		if cena != null and "personagem" in cena and cena.personagem != null and cena.personagem.has_method("trocar_visual"):
			cena.personagem.trocar_visual(v))
	j["perfil"].log_capturas_solicitado.connect(func() -> void:
		j["perfil"].hide()
		j["log"].abrir())
	if controlador_hunt != null:
		j["analyzer"] = _criar(pai, "res://painel_analyzer.gd", "PainelAnalyzer")
		j["analyzer"].controlador = controlador_hunt
		j["analyzer"].log_capturas_solicitado.connect(func() -> void:
			j["analyzer"].hide()
			j["log"].abrir())
	elif menu.botoes.has("analyzer"):
		menu.botoes["analyzer"].disabled = true
		menu.botoes["analyzer"].tooltip_text = "Hunt Analyser — abre dentro da hunt"
	j["_pokedex"] = abrir_pokedex
	menu.janela_solicitada.connect(_abrir.bind(j))
	return j


static func _abrir(chave: String, j: Dictionary) -> void:
	if chave == "profile":
		j["perfil"].abrir()
	elif chave == "usedballs":
		j["bolas"].abrir()
	elif chave == "analyzer" and j.has("analyzer"):
		j["analyzer"].abrir()
	elif chave == "streak":
		j["streak"].abrir()
	elif chave == "bosses":
		j["bosses"].abrir()
	elif chave == "gyms":
		j["ginasios"].abrir()
	elif chave == "inventory":
		j["inventario"].abrir()
	elif chave in ["daily", "quest"]:
		j["diarias"].abrir()
	elif chave == "pokedex":
		j["pokedex"].abrir()   # a Pokédex do original; a Pokepedia (calculadora de golpes) segue no ícone dela


static func _criar(pai: Node, script: String, nome: String) -> Control:
	var c: Control = load(script).new()
	c.name = nome
	pai.add_child(c)
	return c
