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
	j["inventario"].controlador = controlador_hunt
	j["ginasios"] = _criar(pai, "res://painel_ginasios.gd", "PainelGinasios")
	j["bosses"] = _criar(pai, "res://painel_bosses.gd", "PainelBosses")
	j["album"] = _criar(pai, "res://painel_album.gd", "PainelAlbum")
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
	j["_menu"] = menu
	j["_hunt"] = controlador_hunt
	j["original"] = _criar(pai, "res://janela_original.gd", "JanelaOriginal")
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
	elif chave == "pokecards":
		j["album"].abrir()
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
	else:
		_abrir_original(chave, j)


static func _abrir_original(chave: String, j: Dictionary) -> void:
	## Ciclo 4: os itens do dock sem janela própria abrem a janela com a identidade do original. Offline: Soneca (na hunt),
	## Configurações (na cidade), Sair e Novidades fazem algo; os recursos do servidor (ranking, clãs, guilda, troca, PvP,
	## passe, VIP/amigos, correio, diamantes, indicação, lives, PiP, profissões, breeding) dizem que são do jogo online (E).
	var T := preload("res://textos.gd")
	var menu: Control = j["_menu"]
	var tex: Texture2D = (menu.botoes[chave] as Button).icon if menu.botoes.has(chave) else null
	var nome: String = T.t("hud.world.menu." + chave, {}, chave)
	var w: Control = j["original"]
	var ej: Node = w.get_node("/root/EstadoJogo")
	var hunt: Node = j.get("_hunt")
	match chave:
		"sleep":
			if hunt != null and hunt.has_method("soneca"):
				w.abrir(chave, nome, tex, "A hunt continua por [b]5 min[/b] e, ao voltar, você coleta [b]50% da taxa de XP[/b] pelo tempo fora (até 24 h). O jogo fecha.",
					"💤 Dormir agora", func() -> void:
						if String(hunt.soneca()).is_empty():
							ej.salvar_agora()
							w.get_tree().quit())
			else:
				w.abrir(chave, nome, tex, "O Modo Soneca começa [b]dentro de uma hunt[/b]: a caçada segue por 5 min e, ao voltar, você coleta 50% da taxa de XP pelo tempo fora.")
		"config":
			var cena := w.get_tree().current_scene
			if cena != null and "painel_config" in cena and cena.painel_config != null:
				cena.painel_config.visible = not cena.painel_config.visible
				return
			w.abrir(chave, nome, tex, "As configurações (VIP, zoom, Streak, tutorial) ficam na cidade, no [b]⚙[/b] do canto inferior direito.")
		"logout":
			w.abrir(chave, nome, tex, "Salvar e fechar o jogo? O progresso fica no save e a hunt aberta continua até 15 min, como no original.",
				T.t("hud.world.menu.logout", {}, "Sair"), func() -> void:
					ej.salvar_agora()
					w.get_tree().quit())
		"home":
			w.abrir(chave, nome, tex, "Você já está em Cerulean.")
		"patchnotes":
			w.abrir(chave, nome, tex, "Versão offline do Poke Idle World. As novidades do servidor original não chegam aqui; as desta versão ficam no registro do projeto.")
		_:
			w.abrir(chave, nome, tex, "[b]%s[/b] depende do servidor do jogo online (outros jogadores, loja ou eventos ao vivo) e não existe nesta versão offline." % nome)


static func _criar(pai: Node, script: String, nome: String) -> Control:
	var c: Control = load(script).new()
	c.name = nome
	pai.add_child(c)
	return c
